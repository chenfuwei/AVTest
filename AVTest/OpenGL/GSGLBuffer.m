//
//  GSGLBuffer.m
//  PlayerSDK
//
//  Created by gensee on 2019/1/11.
//  Copyright © 2019年 Geensee. All rights reserved.
//

#import "GSGLBuffer.h"
#import <pthread.h>

@implementation GSGLBuffer
{
    void *privateBytes;
    
}
- (instancetype)init {
    if (self = [super init]) {
        sar_den = 0;
        sar_num = 0;
    }
    return self;
}


- (instancetype)initWithBytes:(void*)bytes length:(NSUInteger)length{
    if (self = [super init]) {
        sar_den = 0;
        sar_num = 0;
        privateBytes = (void*)malloc(length);
        memcpy(privateBytes, bytes, length);
        self->pixels[0] = privateBytes;
    }
    return self;
}

- (void)cleanCVBuffer {
    
}

- (void)dealloc
{
    if (self->pixel_buffer) {
        CVBufferRelease(self->pixel_buffer);
        self->pixel_buffer = NULL;
    }
    if (privateBytes != NULL) {
        free(privateBytes);
        privateBytes = NULL;
    }
}


@end
