//
//  H264HardDecoderImpl.h
//  AVTest
//
//  Created by net263 on 2019/8/1.
//  Copyright © 2019 net263. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@protocol H264HardDecoderImplDelegate <NSObject>

-(void)gotDecoderFrame:(CVImageBufferRef)imageBuffer;

@end

@interface H264HardDecoderImpl : NSObject

-(BOOL)initH264Decoder;

-(void)decodeNalu:(uint8_t*)frame size:(uint32_t)frameSize;

-(void)end;

@property(weak, nonatomic) id<H264HardDecoderImplDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
