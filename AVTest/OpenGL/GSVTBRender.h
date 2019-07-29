//
//  GSVTBRender.h
//  PlayerSDK
//
//  Created by gensee on 2019/1/10.
//  Copyright © 2019年 Geensee. All rights reserved.
//

#import "GSGLRender.h"
#import <CoreVideo/CoreVideo.h>

// videoToolBox CVPixelBufferRef -> texture
// buffer must have CVPixelBufferRef
// CVPixelBufferRef must need kCVPixelBufferOpenGLESCompatibilityKey is YES

@interface GSVTBRender : GSGLRender
{
    @public
    CVPixelBufferRef pixel_buffer;
    CVOpenGLESTextureCacheRef cv_texture_cache;
    CVOpenGLESTextureRef      cv_texture[2];
    CFTypeRef m_color_attachments;
    
}



@end

