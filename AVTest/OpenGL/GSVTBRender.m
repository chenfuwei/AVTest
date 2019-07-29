//
//  GSVTBRender.m
//  PlayerSDK
//
//  Created by gensee on 2019/1/10.
//  Copyright © 2019年 Geensee. All rights reserved.
//

#import "GSVTBRender.h"
#import <OpenGLES/EAGL.h>
#import "GSGLRenderColors.h"
#import "glcommon.h"
@implementation GSVTBRender

static const char g_shader[] = GS_GLES_STRING(
     precision highp float;
     varying   highp vec2 vv2_Texcoord;
     uniform         mat3 um3_ColorConversion;
     uniform   lowp  sampler2D us2_SamplerX;
     uniform   lowp  sampler2D us2_SamplerY;
     
     void main()
     {
         mediump vec3 yuv;
         lowp    vec3 rgb;
         
         yuv.x  = (texture2D(us2_SamplerX,  vv2_Texcoord).r  - (16.0 / 255.0));
         yuv.yz = (texture2D(us2_SamplerY,  vv2_Texcoord).rg - vec2(0.5, 0.5));
         rgb = um3_ColorConversion * yuv;
         gl_FragColor = vec4(rgb, 1);
     }
 );

const char *GS_GLES2_getFragmentShader_yuv420sp()
{
    return g_shader;
}



- (instancetype)init {
    if (self = [super init]) {
        //must before prepareShader - handle in super class
        
        self->us2_sampler[0] = glGetUniformLocation(self->program, "us2_SamplerX"); GS_GLES2_checkError_TRACE("glGetUniformLocation(us2_SamplerX)");
        self->us2_sampler[1] = glGetUniformLocation(self->program, "us2_SamplerY"); GS_GLES2_checkError_TRACE("glGetUniformLocation(us2_SamplerY)");
        
        self->um3_color_conversion = glGetUniformLocation(self->program, "um3_ColorConversion"); GS_GLES2_checkError_TRACE("glGetUniformLocation(um3_ColorConversionMatrix)");
        
        CVReturn err = 0;
        EAGLContext *context = [EAGLContext currentContext];
        err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, context, NULL, &self->cv_texture_cache);
        if (err || self->cv_texture_cache == nil) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
            return nil;
        }
        self->m_color_attachments = CFRetain(kCVImageBufferYCbCrMatrix_ITU_R_709_2);
        
    }
    return self;
}

- (BOOL)uploadTexture:(GSGLBuffer*)overlay {

    switch (overlay->format) {
        case SDL_FCC__VTB:
            break;
        default:
            NSLog(@"[yuv420sp_vtb] unexpected format %x\n", overlay->format);
            return GL_FALSE;
    }
    
    if (!cv_texture_cache) {
        NSLog(@"nil textureCache\n");
        return GL_FALSE;
    }
    
    CVPixelBufferRef pixel_buffer = overlay->pixel_buffer;
    if (!pixel_buffer) {
        NSLog(@"nil pixelBuffer in GSVTBRender");
    }
    
    CFTypeRef color_attachments = CVBufferGetAttachment(pixel_buffer, kCVImageBufferYCbCrMatrixKey, NULL);
    if (color_attachments != m_color_attachments) {
        if (color_attachments == nil) {
            glUniformMatrix3fv(um3_color_conversion, 1, GL_FALSE, [GSGLRenderColors GLES2_getColorMatrix_bt709]);
        } else if (m_color_attachments != nil &&
                   CFStringCompare(color_attachments, m_color_attachments, 0) == kCFCompareEqualTo) {
            // remain prvious color attachment
        } else if (CFStringCompare(color_attachments, kCVImageBufferYCbCrMatrix_ITU_R_709_2, 0) == kCFCompareEqualTo) {
            glUniformMatrix3fv(um3_color_conversion, 1, GL_FALSE, [GSGLRenderColors GLES2_getColorMatrix_bt709]);
        } else if (CFStringCompare(color_attachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo) {
            glUniformMatrix3fv(um3_color_conversion, 1, GL_FALSE, [GSGLRenderColors GLES2_getColorMatrix_bt601]);
        } else {
            glUniformMatrix3fv(um3_color_conversion, 1, GL_FALSE, [GSGLRenderColors GLES2_getColorMatrix_bt709]);
        }
        
        if (m_color_attachments != nil) {
            CFRelease(m_color_attachments);
            m_color_attachments = nil;
        }
        if (color_attachments != nil) {
            m_color_attachments = CFRetain(color_attachments);
        }
    }
    
    [self cleanTexture];
    
    GLsizei frame_width  = (GLsizei)CVPixelBufferGetWidth(pixel_buffer);
    GLsizei frame_height = (GLsizei)CVPixelBufferGetHeight(pixel_buffer);
    
    glActiveTexture(GL_TEXTURE0);
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                 cv_texture_cache,
                                                 pixel_buffer,
                                                 NULL,
                                                 GL_TEXTURE_2D,
                                                 GL_RED_EXT,
                                                 (GLsizei)frame_width,
                                                 (GLsizei)frame_height,
                                                 GL_RED_EXT,
                                                 GL_UNSIGNED_BYTE,
                                                 0,
                                                 &cv_texture[0]);
    glBindTexture(CVOpenGLESTextureGetTarget(cv_texture[0]), CVOpenGLESTextureGetName(cv_texture[0]));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    
    glActiveTexture(GL_TEXTURE1);
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                 cv_texture_cache,
                                                 pixel_buffer,
                                                 NULL,
                                                 GL_TEXTURE_2D,
                                                 GL_RG_EXT,
                                                 (GLsizei)frame_width / 2,
                                                 (GLsizei)frame_height / 2,
                                                 GL_RG_EXT,
                                                 GL_UNSIGNED_BYTE,
                                                 1,
                                                 &cv_texture[1]);
    glBindTexture(CVOpenGLESTextureGetTarget(cv_texture[1]), CVOpenGLESTextureGetName(cv_texture[1]));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    return YES;
}

- (void)cleanTexture {
    for (int i = 0; i < 2; ++i) {
        if (cv_texture[i]) {
            CFRelease(cv_texture[i]);
            cv_texture[i] = nil;
        }
    }
    
    // Periodic texture cache flush every frame
    if (cv_texture_cache)
        CVOpenGLESTextureCacheFlush(cv_texture_cache, 0);
    
    
}

- (BOOL)useShader {
    printf("[Gensee][GLES2] use render yuv420sp_vtb\n");
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    glUseProgram(self->program);            GS_GLES2_checkError_TRACE("glUseProgram");
    
    for (int i = 0; i < 2; ++i) {
        glUniform1i(self->us2_sampler[i], i);
    }
    
    glUniformMatrix3fv(self->um3_color_conversion, 1, GL_FALSE, [GSGLRenderColors GLES2_getColorMatrix_bt709]);
    
    return [super useShader] ? YES : NO;
}


- (const char *)fragmentShaderSource {
    return GS_GLES2_getFragmentShader_yuv420sp();
}

@end
