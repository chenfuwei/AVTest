//
//  GSYUVRenderNV12.m
//  GSCommonKit
//
//  Created by gensee on 2019/1/15.
//  Copyright © 2019年 gensee. All rights reserved.
//

#import "GSYUVRenderNV12.h"
#import "glcommon.h"
@implementation GSYUVRenderNV12

- (instancetype)init {
    if (self = [super init]) {
        //must before prepareShader - handle in super class 
        self->us2_sampler[0] = glGetUniformLocation(self->program, "us2_SamplerX"); GS_GLES2_checkError_TRACE("glGetUniformLocation(us2_SamplerX)");
        self->us2_sampler[1] = glGetUniformLocation(self->program, "us2_SamplerY"); GS_GLES2_checkError_TRACE("glGetUniformLocation(us2_SamplerY)");
        
        self->um3_color_conversion = glGetUniformLocation(self->program, "um3_ColorConversion"); GS_GLES2_checkError_TRACE("glGetUniformLocation(um3_ColorConversionMatrix)");
    }
    return self;
}

- (BOOL)useShader {
    ALOGI("use render nv12\n");
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    glUseProgram(self->program);            GS_GLES2_checkError_TRACE("glUseProgram");
    
    if (0 == self->plane_textures[0])
        glGenTextures(2, self->plane_textures);
    
    for (int i = 0; i < 2; ++i) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, self->plane_textures[i]);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glUniform1i(self->us2_sampler[i], i);
    }
    
    glUniformMatrix3fv(self->um3_color_conversion, 1, GL_FALSE, [GSGLRenderColors GLES2_getColorMatrix_bt709]);
    
    return [super useShader] ? YES : NO; // must use super method useShader
}

- (BOOL)uploadTexture:(GSGLBuffer *)overlay {
    if (!overlay)
        return GL_FALSE;
    
    const GLsizei widths[2]    = { overlay->pitches[0], overlay->pitches[1] / 2 };
    const GLsizei heights[2]   = { overlay->h,          overlay->h / 2 };
    const GLubyte *pixels[2]   = { overlay->pixels[0],  overlay->pixels[1] };
    
    switch (overlay->format) {
        case SDL_FCC__VTB:
            break;
        default:
            ALOGE("[yuv420sp] unexpected format %x\n", overlay->format);
            return GL_FALSE;
    }
    
    glBindTexture(GL_TEXTURE_2D, self->plane_textures[0]);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RED_EXT,
                 widths[0],
                 heights[0],
                 0,
                 GL_RED_EXT,
                 GL_UNSIGNED_BYTE,
                 pixels[0]);
    
    glBindTexture(GL_TEXTURE_2D, self->plane_textures[1]);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RG_EXT,
                 widths[1],
                 heights[1],
                 0,
                 GL_RG_EXT,
                 GL_UNSIGNED_BYTE,
                 pixels[1]);
    
    return GL_TRUE;
}



@end
