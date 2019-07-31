//
//  H264HardEncoderImpl.h
//  AVTest
//
//  Created by net263 on 2019/7/31.
//  Copyright © 2019 net263. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol H264HardEncoderImplDelegate <NSObject>

-(void)gotSpsPps:(NSData*)sps pps:(NSData*)pps;
-(void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame;

@end

@interface H264HardEncoderImpl : NSObject
-(void)initWithConfiguration;
-(void)start:(int)width height:(int)height;
-(void)initEncode:(int)width height:(int)height;
-(void)changeResolution:(int)width height:(int)height;
-(void)encode:(CMSampleBufferRef)sampleBuffer;
-(void)end;

@property(weak, nonatomic)NSString* error;
@property(weak, nonatomic)id<H264HardEncoderImplDelegate> delegate;
@end

NS_ASSUME_NONNULL_END
