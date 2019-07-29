//
//  GSRGBRender.m
//  GSCommonKit
//
//  Created by gensee on 2019/1/15.
//  Copyright © 2019年 gensee. All rights reserved.
//

#import "GSRGBRender.h"
#import "glcommon.h"

static const char g_shader[] = GS_GLES_STRING(
 precision highp float;
 varying   highp vec2 vv2_Texcoord;
 uniform   lowp  sampler2D us2_SamplerX;
 
 void main()
 {
     gl_FragColor = vec4(texture2D(us2_SamplerX, vv2_Texcoord).rgb, 1);
 }
 );

const char *GS_GLES2_getFragmentShader_rgb()
{
    return g_shader;
}

@implementation GSRGBRender


- (instancetype)init {
    if (self = [super init]) {
        self->us2_sampler[0] = glGetUniformLocation(self->program, "us2_SamplerX"); GS_GLES2_checkError_TRACE("glGetUniformLocation(us2_SamplerX)");
    }
    return self;
}

- (BOOL)useShader {
    ALOGI("use render rgb\n");
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    glUseProgram(self->program);            GS_GLES2_checkError_TRACE("glUseProgram");
    
    if (0 == self->plane_textures[0])
        glGenTextures(1, self->plane_textures);
    
    for (int i = 0; i < 1; ++i) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, self->plane_textures[i]);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glUniform1i(self->us2_sampler[i], i);
    }
    
    return [super useShader] ? YES : NO;  // must use super method useShader
}

- (BOOL)uploadTexture:(GSGLBuffer *)overlay {
    if (!overlay)
        return GL_FALSE;
    
    int m = 2;
    int type = GL_UNSIGNED_SHORT_5_6_5;
    int RGB = GL_RGB;
    switch (overlay->format) {
        case SDL_FCC_RV16: {
            m = 2;
            type = GL_UNSIGNED_SHORT_5_6_5;
        }
            break;
        case SDL_FCC_RV24:{
            m = 3;
            type = GL_UNSIGNED_BYTE;
        }
            break;
        case SDL_FCC_RV32:{
            m = 4;
            type = GL_UNSIGNED_BYTE;
            RGB = GL_RGBA;
        }
            break;
        default:
            ALOGE("[rgb] unexpected format %x\n", overlay->format);
            return GL_FALSE;
    }
    int     planes[1]    = { 0 };
    const GLsizei widths[1]    = { overlay->pitches[0] / m };
    const GLsizei heights[3]   = { overlay->h };
    const GLubyte *pixels[3]   = { overlay->pixels[0] };
    
    
    
    for (int i = 0; i < 1; ++i) {
        int plane = planes[i];
        
        glBindTexture(GL_TEXTURE_2D, self->plane_textures[i]);
        
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     RGB,
                     widths[plane],
                     heights[plane],
                     0,
                     RGB,
                     type,
                     pixels[plane]);
    }
    
    return GL_TRUE;
}

- (GLsizei)bufferWidth:(GSGLBuffer *)overlay {
    if (!overlay) {
        return 0;
    }
    if (overlay->format == SDL_FCC_RV16) {
        return overlay->pitches[0] / 2;
    }else if (overlay->format == SDL_FCC_RV24) {
        return overlay->pitches[0] / 3;
    }else if (overlay->format == SDL_FCC_RV32) {
        return overlay->pitches[0] / 4;
    }
    return overlay->pitches[0] / 2;
}

- (const char *)fragmentShaderSource {
    return GS_GLES2_getFragmentShader_rgb();
}



@end
