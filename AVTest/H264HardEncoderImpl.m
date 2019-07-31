//
//  H264HardEncoderImpl.m
//  AVTest
//
//  Created by net263 on 2019/7/31.
//  Copyright © 2019 net263. All rights reserved.
//

#import "H264HardEncoderImpl.h"
#import <VideoToolbox/VideoToolbox.h>
#define YUV_FRAME_SIZE  2000
#define FRAME_WIDTH
#define NUMBEROFFRAMES 300
#define DURATION 12

@implementation H264HardEncoderImpl
{
    NSString* yuvFile;
    VTCompressionSessionRef encodingSession;
    dispatch_queue_t aQueue;
    CMFormatDescriptionRef format;
    CMSampleTimingInfo* timingInfo;
    BOOL initialized;
    int frameCount;
    NSData* sps;
    NSData* pps;
}

@synthesize error;
- (instancetype)init
{
    self = [super init];
    if (self) {
        [self initWithConfiguration];
    }
    return self;
}

- (void)initWithConfiguration
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentsDirectory = [paths objectAtIndex:0];
    
    encodingSession = nil;
    initialized = true;
    aQueue = dispatch_get_global_queue(0, 0);
    frameCount = 0;
    sps = NULL;
    pps = NULL;
}

void didCompressH264(void* outputCallbackRefCon, void* sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer)
{
    ReLog("status:%d infoFlags:%d", (int)status, (int)infoFlags);
    if(status != 0)
    {
        return;
    }
    
    if(!CMSampleBufferDataIsReady(sampleBuffer))
    {
        ReLog(@"data is not ready");
        return;
    }
    
    H264HardEncoderImpl* encoder = (__bridge H264HardEncoderImpl*)outputCallbackRefCon;
    
     bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    if(keyframe)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t* sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
        if(statusCode == noErr)
        {
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t* pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0);
            if(statusCode == noErr)
            {
                encoder->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                encoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                if(encoder->_delegate)
                {
                    [encoder->_delegate gotSpsPps:encoder->sps pps:encoder->pps];
                }
            }
        }
    }
    
    //CMBlockBuffer存储编码后的数据  
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char* dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if(statusCodeRet == noErr)
    {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLenght = 4;
        while (bufferOffset < totalLength - AVCCHeaderLenght) {
            uint32_t NALUnitLenght = 0;
            memcpy(&NALUnitLenght, dataPointer + bufferOffset, AVCCHeaderLenght);
            
            NALUnitLenght = CFSwapInt32BigToHost(NALUnitLenght);
            
            NSData* data = [[NSData alloc] initWithBytes:dataPointer + bufferOffset + AVCCHeaderLenght length:NALUnitLenght];
            if(encoder->_delegate)
            {
                [encoder->_delegate gotEncodedData:data isKeyFrame:keyframe];
            }
            bufferOffset += AVCCHeaderLenght + NALUnitLenght;
        }
    }
}

-(void)start:(int)width height:(int)height
{
    int frameSize = (width * height * 1.5);
    if(!initialized)
    {
        ReLog("Not initialized");
        error = @"H264: Not initialized";
        return;
    }
    
    dispatch_sync(aQueue, ^{
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)self, &self->encodingSession);
        ReLog(@"H264:VTCompressionSessionCreate %d", (int)status);
        if(status != 0)
        {
            ReLog(@"unable to create a H264 session");
            self->error = @"H264: Unable to create a H264 session";
            return;
        }
        
        int maxFrameInterval = 240;
        VTSessionSetProperty(self->encodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(self->encodingSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
        VTSessionSetProperty(self->encodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, &maxFrameInterval);
        VTSessionSetProperty(self->encodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel);
        VTCompressionSessionPrepareToEncodeFrames(self->encodingSession);
        
        int fd = open([self->yuvFile UTF8String], O_RDONLY);
        if(fd == -1)
        {
            ReLog("H264: Unable to open the file");
            self->error = (@"H264: Unable to open the file");
            return;
        }
        
        NSMutableData* theData = [[NSMutableData alloc] initWithLength:frameSize];
        NSUInteger actualBytes = frameSize;
        while (actualBytes > 0) {
            void* buffer = [theData mutableBytes];
            NSUInteger bufferSize = [theData length];
            
            actualBytes = read(fd, buffer, bufferSize);
            if(actualBytes < frameSize)
            {
                [theData setLength:actualBytes];
            }
            self->frameCount ++;
            
            CMBlockBufferRef blockBuffer = NULL;
            OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL, buffer, actualBytes, kCFAllocatorNull, NULL, 0, actualBytes, kCMBlockBufferAlwaysCopyDataFlag, &blockBuffer);
            
            if(status != noErr)
            {
                ReLog(@"h264: CMBlockBufferCreateWithMemoryBlock failed with %d", (int)status);
                self->error = @"h264: CMBlockBufferCreateWithMemoryBlock failed";
                return;
            }
            
            CMSampleBufferRef sampleBuffer = NULL;
            CMFormatDescriptionRef formatDescription;
            CMFormatDescriptionCreate(kCFAllocatorDefault, kCMMediaType_Video, 'I420', NULL, &formatDescription);
            CMSampleTimingInfo sampleTimingInfo = {CMTimeMake(1, 300)};
            OSStatus statusCode = CMSampleBufferCreate(kCFAllocatorDefault, blockBuffer, YES, NULL, NULL, formatDescription, 1, 1, &sampleTimingInfo, 0, NULL, &sampleBuffer);
            if(statusCode != noErr)
            {
                ReLog(@"H264:CMSampleBufferCreate failed width %d", (int)statusCode);
                self->error = @"H264: CMSampleBufferCreate failed";
                return;
            }
            CFRelease(blockBuffer);
            blockBuffer = NULL;
            
            CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
            CMTime presentationTimeStamp = CMTimeMake(self->frameCount, 300);
            
            VTEncodeInfoFlags flags;
            statusCode = VTCompressionSessionEncodeFrame(self->encodingSession, imageBuffer, presentationTimeStamp, kCMTimeInvalid, NULL, NULL, &flags);
            if(statusCode != noErr)
            {
                ReLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
                self->error = @"H264: VTCompressionSessionEncodeFrame failed ";
                
                VTCompressionSessionInvalidate(self->encodingSession);
                CFRelease(self->encodingSession);
                self->encodingSession = NULL;
                self->error = NULL;
                return;
            }
            NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
        }
        VTCompressionSessionCompleteFrames(self->encodingSession, kCMTimeInvalid);
        VTCompressionSessionInvalidate(self->encodingSession);
        CFRelease(self->encodingSession);
        self->encodingSession = NULL;
        self->error = NULL;
        close(fd);
    });
    
}

- (void)initEncode:(int)width height:(int)height
{
    dispatch_sync(aQueue, ^{
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self), &self->encodingSession);
        ReLog(@"H264: VTCompressionSessionCreate %d", (int)status);
        
        if(status != 0)
        {
            ReLog(@"H264: Unable to create a H264 session");
            self->error = @"H264: Unable to create a H264 session";
            
            return ;
        }
        
        VTSessionSetProperty(self->encodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(self->encodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
        
        VTCompressionSessionPrepareToEncodeFrames(self->encodingSession);
    });
}


-(void)encode:(CMSampleBufferRef)sampleBuffer
{
    dispatch_sync(aQueue, ^{
        self->frameCount ++;
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        CMTime presentationTimeStamp = CMTimeMake(self->frameCount, 1000);
        VTEncodeInfoFlags flags;
        
        OSStatus statusCode = VTCompressionSessionEncodeFrame(self->encodingSession, imageBuffer, presentationTimeStamp, kCMTimeInvalid, NULL, NULL, &flags);
        
        if(statusCode != noErr)
        {
            ReLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
            self->error = @"H264: VTCompressionSessionEncodeFrame failed ";
            
            VTCompressionSessionInvalidate(self->encodingSession);
            CFRelease(self->encodingSession);
            self->encodingSession = NULL;
            self->error = NULL;
            return;
        }
        ReLog(@"H264: VTCompressionSessionEncodeFrame Success");
    });
}

- (void)changeResolution:(int)width height:(int)height
{
    
}

- (void)end
{
    VTCompressionSessionCompleteFrames(encodingSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(encodingSession);
    CFRelease(encodingSession);
    encodingSession = NULL;
    error = NULL;
}
@end
