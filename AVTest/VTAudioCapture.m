//
//  VTAudioCapture.m
//  AVTest
//
//  Created by net263 on 2019/8/2.
//  Copyright © 2019 net263. All rights reserved.
//

#import "VTAudioCapture.h"
#import <AVFoundation/AVFoundation.h>
#import <pthread.h>

static void AQInputCallback(void * inUserData,
                            AudioQueueRef inAudioQueue,
                            AudioQueueBufferRef inBuffer,
                            const AudioTimeStamp* inStartTime,
                            UInt32 inNumPackets,
                            const AudioStreamPacketDescription* inPacketDesc)
{
    ReLog(@"inNumPackets:%d", inNumPackets);
    VTAudioCapture* audioCapture = (__bridge VTAudioCapture*)inUserData;
    if(inNumPackets > 0)
    {
        if(audioCapture)
        {
            [audioCapture processAudioBuffer:inBuffer withQueue:inAudioQueue];
        }
    }
    
    if(audioCapture.aqc.run)
    {
        AudioQueueEnqueueBuffer(audioCapture.aqc.queue, inBuffer, 0, NULL);
    }
}

@implementation VTAudioCapture
{
    pthread_mutex_t _lock;
    
    NSString* pcmPath;
    NSFileHandle* pcmFileHandler;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        pthread_mutex_init(&_lock, NULL);
    }
    return self;
}

-(void)createPcmContext
{
    NSArray* documentDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentPath = [documentDirectory objectAtIndex:0];
    pcmPath = [documentPath stringByAppendingPathComponent:@"vt_test.pcm"];
    NSFileManager* fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:pcmPath error:nil];
    [fileManager createFileAtPath:pcmPath contents:nil attributes:nil];
    pcmFileHandler = [NSFileHandle fileHandleForWritingAtPath:pcmPath];
}

-(void)start
{
    [self createPcmContext];
    _aqc.mDataFormat.mSampleRate = 16000.0;
    _aqc.mDataFormat.mBitsPerChannel = 16;
    _aqc.mDataFormat.mChannelsPerFrame = 1;
    _aqc.mDataFormat.mFormatID = kAudioFormatLinearPCM;
    _aqc.mDataFormat.mFramesPerPacket = 1;
    _aqc.mDataFormat.mBytesPerFrame = (_aqc.mDataFormat.mBitsPerChannel / 8) * _aqc.mDataFormat.mChannelsPerFrame;
    _aqc.mDataFormat.mBytesPerPacket = _aqc.mDataFormat.mBytesPerFrame * _aqc.mDataFormat.mFramesPerPacket;
    _aqc.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    _aqc.frameSize = kFrameSize;
    
    OSStatus status = AudioQueueNewInput(&_aqc.mDataFormat, AQInputCallback, (__bridge void *)self, NULL, kCFRunLoopCommonModes, 0, &_aqc.queue);
    ReLog(@"AudioQueueNewInput status:%d", status);
    for(int i = 0; i < kNumberBuffers; i++)
    {
        AudioQueueAllocateBuffer(_aqc.queue, _aqc.frameSize, &_aqc.mBuffers[i]);
        AudioQueueEnqueueBuffer(_aqc.queue, _aqc.mBuffers[i], 0, NULL);
    }
    
    _aqc.run = 1;
//    AVAudioSession * session = [AVAudioSession sharedInstance];
//    if (!session) printf("ERROR INITIALIZING AUDIO SESSION! \n");
//    else{
//
//        NSError *nsError = nil;
//        [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&nsError];
//
//        if (nsError) printf("couldn't set audio category!");
//        [session setActive:YES error:&nsError];
//        if (nsError) printf("AudioSession setActive = YES failed");
//    }
    
     status = AudioQueueStart(_aqc.queue, NULL);
    ReLog(@"AudioQueueStart status:%d", status);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionInterruption:) name:AVAudioSessionRouteChangeNotification object:nil];
    
}

-(void)pause
{
    AudioQueuePause(_aqc.queue);
}

-(void)stop
{
    [self cleanUp];
}

-(void)processAudioBuffer:(AudioQueueBufferRef)buffer withQueue:(AudioQueueRef)queue
{
    if(buffer)
    {
        char* psrc = (char*)buffer->mAudioData;
        int bufLenght = buffer->mAudioDataByteSize;
        
        NSData* data = [NSData dataWithBytes:psrc length:bufLenght];
        if(pcmFileHandler)
        {
            [pcmFileHandler writeData:data];
        }
    }
}

-(void)dealloc
{
    [self cleanUp];
    pthread_mutex_destroy(&_lock);
}

-(void)cleanUp
{
    if(_aqc.run != 0)
    {
        AudioQueueStop(_aqc.queue, true);
        _aqc.run = 0;
        AudioQueueDispose(_aqc.queue, true);
    }
    
    if(pcmFileHandler)
    {
        [pcmFileHandler closeFile];
        pcmFileHandler = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(BOOL)isHeadsetPluggedIn
{
    AVAudioSessionRouteDescription* route = [[AVAudioSession sharedInstance] currentRoute];
    for(AVAudioSessionPortDescription* desc in [route outputs])
    {
        if([[desc portType] isEqualToString:AVAudioSessionPortHeadphones])
        {
            return YES;
        }
    }
    return NO;
}

-(void)handleAudioSessionInterruption:(NSNotification*)notification
{
    NSNumber* interruptionType = [[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey];
    NSNumber* interruptionOption = [[notification userInfo] objectForKey:AVAudioSessionInterruptionOptionKey];
    
    switch (interruptionType.unsignedIntegerValue) {
        case AVAudioSessionInterruptionTypeBegan:
            ReLog(@"AVAudioSessionInterruptionTypeBegan");
            break;
        case AVAudioSessionInterruptionTypeEnded:
            ReLog(@"AVAudioSessionInterruptionTypeEnded");
            if(interruptionOption.unsignedIntegerValue == AVAudioSessionInterruptionOptionShouldResume)
            {
                NSError* error;
                [[AVAudioSession sharedInstance] setActive:YES withOptions:kAudioSessionSetActiveFlag_NotifyOthersOnDeactivation error:&error];
                if(error)
                {
                    ReLog(@"error:%@", error.description);
                }
                if(_aqc.run)
                {
                    [self stop];
                    [self start];
                }
                ReLog(@"AVAudioSessionInterruptionOptionsShouldResume");
            }
            break;
        default:
            break;
    }
}
@end
