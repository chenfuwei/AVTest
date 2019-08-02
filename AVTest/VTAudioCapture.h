//
//  VTAudioCapture.h
//  AVTest
//
//  Created by net263 on 2019/8/2.
//  Copyright © 2019 net263. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define kNumberBuffers 3
#define kFrameSize 1920

NS_ASSUME_NONNULL_BEGIN

typedef struct AQCallbackStruct
{
    AudioStreamBasicDescription mDataFormat;
    AudioQueueRef queue;
    AudioQueueBufferRef mBuffers[kNumberBuffers];
    AudioFileID outputFile;
    
    unsigned int frameSize;
    long long recPtr;
    int run;
}AQCallbackStruct;

@interface VTAudioCapture : NSObject
@property(assign, nonatomic)AQCallbackStruct aqc;
-(void)start;
-(void)stop;
-(void)pause;
-(void)processAudioBuffer:(AudioQueueBufferRef)buffer withQueue:(AudioQueueRef)queue;
@end

NS_ASSUME_NONNULL_END
