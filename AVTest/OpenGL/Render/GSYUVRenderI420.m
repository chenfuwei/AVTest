//
//  GSYUVRenderI420.m
//  GSCommonKit
//
//  Created by gensee on 2019/1/15.
//  Copyright © 2019年 gensee. All rights reserved.
//

#import "GSYUVRenderI420.h"
#import "glcommon.h"

static const char g_shader[] = GS_GLES_STRING(
 precision highp float;
 varying   highp vec2 vv2_Texcoord;
 uniform         mat3 um3_ColorConversion;
 uniform   lowp  sampler2D us2_SamplerX;
 uniform   lowp  sampler2D us2_SamplerY;
 uniform   lowp  sampler2D us2_SamplerZ;
 
 void main()
 {
     mediump vec3 yuv;
     lowp    vec3 rgb;
     
     yuv.x = (texture2D(us2_SamplerX, vv2_Texcoord).r - (16.0 / 255.0));
     yuv.y = (texture2D(us2_SamplerY, vv2_Texcoord).r - 0.5);
     yuv.z = (texture2D(us2_SamplerZ, vv2_Texcoord).r - 0.5);
     rgb = um3_ColorConversion * yuv;
     gl_FragColor = vec4(rgb, 1);
 }
 );

const char *GS_GLES2_getFragmentShader_yuv420p()
{
    return g_shader;
}

@implementation GSYUVRenderI420

- (instancetype)init {
    if (self = [super init]) {
        self->us2_sampler[0] = glGetUniformLocation(self->program, "us2_SamplerX"); GS_GLES2_checkError_TRACE("glGetUniformLocation(us2_SamplerX)");
        self->us2_sampler[1] = glGetUniformLocation(self->program, "us2_SamplerY"); GS_GLES2_checkError_TRACE("glGetUniformLocation(us2_SamplerY)");
        self->us2_sampler[2] = glGetUniformLocation(self->program, "us2_SamplerZ"); GS_GLES2_checkError_TRACE("glGetUniformLocation(us2_SamplerZ)");
        
        self->um3_color_conversion = glGetUniformLocation(self->program, "um3_ColorConversion"); GS_GLES2_checkError_TRACE("glGetUniformLocation(um3_ColorConversionMatrix)");
    }
    return self;
}

- (BOOL)uploadTexture:(GSGLBuffer*)overlay {
    if (!overlay)
        return GL_FALSE;
    
    int     planes[3]    = { 0, 1, 2 };
    const GLsizei widths[3]    = { overlay->pitches[0], overlay->pitches[1], overlay->pitches[2] };
    const GLsizei heights[3]   = { overlay->h,          overlay->h / 2,      overlay->h / 2 };
    const GLubyte *pixels[3]   = { overlay->pixels[0],  overlay->pixels[1],  overlay->pixels[2] };
    
    switch (overlay->format) {
        case SDL_FCC_I420:
            break;
        case SDL_FCC_YV12:
            planes[1] = 2;
            planes[2] = 1;
            break;
        default:
            ALOGE("[i420] unexpected format %x\n", overlay->format);
            return GL_FALSE;
    }
    
    for (int i = 0; i < 3; ++i) {
        int plane = planes[i];
        
        glBindTexture(GL_TEXTURE_2D, self->plane_textures[i]);
        
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     GL_LUMINANCE,
                     widths[plane],
                     heights[plane],
                     0,
                     GL_LUMINANCE,
                     GL_UNSIGNED_BYTE,
                     pixels[plane]);
    }
    
    return GL_TRUE;
}

- (BOOL)useShader {
    ALOGI("use render yuv420p/i420\n");
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    glUseProgram(self->program);            GS_GLES2_checkError_TRACE("glUseProgram");
    
    if (0 == self->plane_textures[0])
        glGenTextures(3, self->plane_textures);
    
    for (int i = 0; i < 3; ++i) {
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


- (const char *)fragmentShaderSource {
    return GS_GLES2_getFragmentShader_yuv420p();
}




@end
