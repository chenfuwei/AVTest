//
//  H264HardDecoderImpl.m
//  AVTest
//
//  Created by net263 on 2019/8/1.
//  Copyright © 2019 net263. All rights reserved.
//

#import "H264HardDecoderImpl.h"
@interface H264HardDecoderImpl(){
    VTDecompressionSessionRef _decoderSession;  //解码session
    
    CMVideoFormatDescriptionRef _decoderFormatDescription; //解码format 封装了sps和pps
    
    uint8_t* _sps;
    NSInteger _spsSize;
    uint8_t* _pps;
    NSInteger _ppsSize;

}
@end
@implementation H264HardDecoderImpl

-(BOOL)initH264Decoder
{
    if(_decoderSession)
    {
        return YES;
    }
    
    const uint8_t* const parameterSetPointers[2] = {_sps, _pps};
    const size_t parameterSetSizes[2] = {_spsSize, _ppsSize};
    
    //用sps和pps实例化_decoderFormatDescription
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, 4, &_decoderFormatDescription);
    ReLog(@"status:%d", status);
    if(status == noErr)
    {
        NSDictionary* destinationPixelBufferAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey:
                                                               [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
                                                           (id)kCVPixelBufferWidthKey :[NSNumber numberWithInt:1280],  //可以不设置，得到的就是原始数据的宽度
                                                           (id)kCVPixelBufferHeightKey :[NSNumber numberWithInt:960],  //可以不设置，得到的就是原始数据的高度
                                                           (id)kCVPixelBufferOpenGLCompatibilityKey :[NSNumber numberWithBool:YES]
                                                           };
        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = didDecompress;
        callBackRecord.decompressionOutputRefCon = (__bridge void*)self;
        status = VTDecompressionSessionCreate(kCFAllocatorDefault, _decoderFormatDescription, NULL, (__bridge CFDictionaryRef)destinationPixelBufferAttributes, &callBackRecord, &_decoderSession);
        VTSessionSetProperty(_decoderSession, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef)[NSNumber numberWithInt:1]);
        VTSessionSetProperty(_decoderSession, kVTDecompressionPropertyKey_RealTime,    kCFBooleanTrue);
    }else{
        return NO;
    }
    return YES;
}

static void didDecompress(void* decompressionOutputRefCon, void* sourceFrameRefCon, OSStatus status,
                          VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration){
    CVPixelBufferRef* outputPixelBuffer = (CVPixelBufferRef*)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
    H264HardDecoderImpl* decoder = (__bridge H264HardDecoderImpl*)decompressionOutputRefCon;
    if(status != noErr)
    {
        ReLog(@"status:%d", status);
    }
    if(decoder.delegate)
    {
        [decoder.delegate gotDecoderFrame:pixelBuffer];
    }
}

//解码nalu裸数据
-(void)decodeNalu:(uint8_t *)frame size:(uint32_t)frameSize
{
    int nalu_type = (frame[4] & 0x1F);
    CVPixelBufferRef pixelBuffer = NULL;
    
    //填充nalusize 去掉startCode 替换成nalu size
    uint32_t nalSize = (uint32_t)(frameSize - 4);
    uint8_t* pNalSize = (uint8_t*)(&nalSize);
    frame[0] = *(pNalSize + 3);
    frame[1] = *(pNalSize + 2);
    frame[2] = *(pNalSize + 1);
    frame[3] = *pNalSize;
    
    switch (nalu_type) {
        case 0x05:
            //关键帧
            if([self initH264Decoder])
           {
               pixelBuffer = [self decode:frame size:frameSize];
           }
            break;
        case 0x07:
            //sps
            _spsSize = frameSize - 4;
            _sps = malloc(_spsSize);
            memcpy(_sps, &frame[4], _spsSize);
            break;
        case 0x08:
            //pps
            _ppsSize = frameSize - 4;
            _pps = malloc(_ppsSize);
            memcpy(_pps, &frame[4], _ppsSize);
            break;
        default:
        {
            //B/P frame
            if(_decoderSession)
            {
                pixelBuffer = [self decode:frame size:frameSize];
            }
            break;
        }
    }
    
    if(pixelBuffer != NULL)
    {
        CFRelease(pixelBuffer);
        pixelBuffer = NULL;
    }
}

//解码数据
-(CVPixelBufferRef)decode:(uint8_t*)frame size:(uint32_t)frameSize
{
    CVPixelBufferRef outputPiexlBuffer = NULL;
    CMBlockBufferRef blockBuffer = NULL;
    
    //创建CMBlockBufferRef
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL, (void*)frame, frameSize, kCFAllocatorNull, NULL, 0, frameSize, false, &blockBuffer);
    
    if(status == kCMBlockBufferNoErr)
    {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {frameSize};
        
        //创建sampleBuffer
        status = CMSampleBufferCreateReady(kCFAllocatorDefault, blockBuffer, _decoderFormatDescription, 1, 0, NULL, 1, sampleSizeArray, &sampleBuffer);
        
        if(status == kCMBlockBufferNoErr && sampleBuffer)
        {
            VTDecodeFrameFlags flags = 0;
            VTDecodeInfoFlags flagOut = 0;
            
            OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_decoderSession, sampleBuffer, flags, &outputPiexlBuffer, &flagOut);
            if(decodeStatus == kVTInvalidSessionErr)
            {
                ReLog(@"IOSVT:Invalid sessoin, reset decoder session");
            }else if(decodeStatus == kVTVideoDecoderBadDataErr){
                ReLog(@"IOSVT: decode failed status=%d(Bad data)", decodeStatus);
            }else if(decodeStatus != noErr)
            {
                NSLog(@"IOSVT: decode failed status=%d", decodeStatus);
            }
            CFRelease(sampleBuffer);
            sampleBuffer = NULL;
        }
        CFRelease(blockBuffer);
        blockBuffer = NULL;
    }
    return outputPiexlBuffer;
}

- (void)end
{
    if(_decoderSession)
    {
        VTDecompressionSessionInvalidate(_decoderSession);
        CFRelease(_decoderSession);
        _decoderSession = NULL;
    }
    
    if(_decoderFormatDescription)
    {
        CFRelease(_decoderFormatDescription);
        _decoderFormatDescription = NULL;
    }
    
    if(_sps)
    {
        free(_sps);
    }
    
    if(_pps)
    {
        free(_pps);
    }
    
    _ppsSize = _spsSize = 0;
}
@end
