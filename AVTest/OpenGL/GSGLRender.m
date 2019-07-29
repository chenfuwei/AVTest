//
//  GSGLRender.m
//  PlayerSDK
//
//  Created by gensee on 2019/1/10.
//  Copyright © 2019年 Geensee. All rights reserved.
//

#import "GSGLRender.h"
#import "GSGLBuffer.h"
#import "GSGLRenderColors.h"
#import "glcommon.h"




@implementation GSGLRender



static const char g_shader[] = GS_GLES_STRING(
     precision highp float;
     varying   highp vec2 vv2_Texcoord;
     attribute highp vec4 av4_Position;
     attribute highp vec2 av2_Texcoord;
     uniform         mat4 um4_ModelViewProjection;
 
     void main()
     {
         gl_Position  = um4_ModelViewProjection * av4_Position;
         vv2_Texcoord = av2_Texcoord.xy;
     }
 );

const char *GS_GLES2_getVertexShader_default()
{
    return g_shader;
}


- (instancetype)init {
    if (self = [super init]) {
        [self prepareShader];
        
        //do your render custom param gain
    }
    return self;
}

- (BOOL)setGravity:(int)gravity width:(CGFloat)layer_width height:(CGFloat)layer_height {

    if (self->gravity != gravity && gravity >= 0 && gravity <= 2)
        self->vertices_changed = 1;
    else if (self->layer_width != layer_width)
        self->vertices_changed = 1;
    else if (self->layer_height != layer_height)
        self->vertices_changed = 1;
    else
        return GL_TRUE;
    
    self->gravity      = gravity;
    self->layer_width  = layer_width;
    self->layer_height = layer_height;
    return GL_TRUE;
}

- (BOOL)prepareShader {
    vertex_shader = GS_GLES2_loadShader(GL_VERTEX_SHADER, GS_GLES2_getVertexShader_default());
    if (!vertex_shader)
        return NO;
    
    fragment_shader = GS_GLES2_loadShader(GL_FRAGMENT_SHADER, [self fragmentShaderSource]);
    if (!fragment_shader)
        return NO;
    
    program = glCreateProgram();                          GS_GLES2_checkError("glCreateProgram");
    if (!program)
        return NO;
    
    glAttachShader(self->program, self->vertex_shader);     GS_GLES2_checkError("glAttachShader(vertex)");
    glAttachShader(self->program, self->fragment_shader);   GS_GLES2_checkError("glAttachShader(fragment)");
    
//    glBindAttribLocation(self->program, 0,"av4_Position");
//    glBindAttribLocation(self->program, 1, "av2_Texcoord");
    
    glLinkProgram(self->program);                               GS_GLES2_checkError("glLinkProgram");
    GLint link_status = GL_FALSE;
    glGetProgramiv(self->program, GL_LINK_STATUS, &link_status);
    if (!link_status)
        return NO;
    
    GLint status;
    
    glValidateProgram(self->program);
    glGetProgramiv(self->program, GL_VALIDATE_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"Failed to validate program %d", self->program);
        return NO;
    }
    
    self->av4_position = glGetAttribLocation(self->program, "av4_Position");                GS_GLES2_checkError_TRACE("glGetAttribLocation(av4_Position)");
    self->av2_texcoord = glGetAttribLocation(self->program, "av2_Texcoord");                GS_GLES2_checkError_TRACE("glGetAttribLocation(av2_Texcoord)");
    self->um4_mvp      = glGetUniformLocation(self->program, "um4_ModelViewProjection");    GS_GLES2_checkError_TRACE("glGetUniformLocation(um4_ModelViewProjection)");
    return YES;
}

- (BOOL)useShader {
    
    //before this line do your custom
    
    GS_GLES_Matrix modelViewProj;
    GS_GLES2_loadOrtho(&modelViewProj, -1.0f, 1.0f, -1.0f, 1.0f, -1.0f, 1.0f);
    glUniformMatrix4fv(self->um4_mvp, 1, GL_FALSE, modelViewProj.m);                    GS_GLES2_checkError_TRACE("glUniformMatrix4fv(um4_mvp)");
    
    //坐标
    [self texCoordsReset];
    
    [self texCoordsReload];
    
    
    [self verticesReset];
    
    [self verticesReloadVertex];
    
    return YES;
}

- (BOOL)uploadTexture:(GSGLBuffer*)overlay {
    printf("[Gensee][GLES2] uploadTexture: must rewirte by subclass\n");
    return NO;
}

- (void)cleanTexture {
    printf("[Gensee][GLES2] cleanTexture must rewirte by subclass\n");
}



- (void)reset {
    
    if (self->vertex_shader)
        glDeleteShader(self->vertex_shader);
    if (self->fragment_shader)
        glDeleteShader(self->fragment_shader);
    if (self->program)
        glDeleteProgram(self->program);
    
    self->vertex_shader   = 0;
    self->fragment_shader = 0;
    self->program         = 0;
    
    for (int i = 0; i < 3; ++i) {
        if (self->plane_textures[i]) {
            glDeleteTextures(1, &self->plane_textures[i]);
            self->plane_textures[i] = 0;
        }
    }
}

#pragma mark - render

- (BOOL)renderBuffer:(GSGLBuffer*)overlay {
    
//    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);       GS_GLES2_checkError_TRACE("glClearColor");
//    glEnable(GL_CULL_FACE);                     GS_GLES2_checkError_TRACE("glEnable(GL_CULL_FACE)");
//    glCullFace(GL_BACK);                        GS_GLES2_checkError_TRACE("glCullFace");
//    glDisable(GL_DEPTH_TEST);
    
    glClear(GL_COLOR_BUFFER_BIT);               GS_GLES2_checkError_TRACE("glClear");
    
    GLsizei visible_width  = self->frame_width;
    GLsizei visible_height = self->frame_height;
    if (overlay) {
        visible_width  = overlay->w;
        visible_height = overlay->h;
        if (self->frame_width   != visible_width    ||
            self->frame_height  != visible_height   ||
            self->frame_sar_num != overlay->sar_num ||
            self->frame_sar_den != overlay->sar_den) {
            
            self->frame_width   = visible_width;
            self->frame_height  = visible_height;
            self->frame_sar_num = overlay->sar_num;
            self->frame_sar_den = overlay->sar_den;
            
            self->vertices_changed = 1;
        }
        
        self->last_buffer_width = [self bufferWidth:overlay];
        
        if (![self uploadTexture:overlay])
            return GL_FALSE;
    } else {
        // NULL overlay means force reload vertice
        self->vertices_changed = 1;
    }
    GLsizei buffer_width = self->last_buffer_width;
    if (self->vertices_changed ||
        (buffer_width > 0 &&
         buffer_width > visible_width &&
         buffer_width != self->buffer_width &&
         visible_width != self->visible_width)){
            
            self->vertices_changed = 0;
            
            [self verticesApply];
            [self verticesReloadVertex];
            
            self->buffer_width  = buffer_width;
            self->visible_width = visible_width;
            
            GLsizei padding_pixels     = buffer_width - visible_width;
            GLfloat padding_normalized = ((GLfloat)padding_pixels) / buffer_width;
            
            [self texCoordsReset];
            [self texCoordsCropRight:padding_normalized];
            [self texCoordsReload];
        }
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);      GS_GLES2_checkError_TRACE("glDrawArrays");
    
    return GL_TRUE;
}

#pragma mark - texCoords

- (void)texCoordsReset {
    self->texcoords[0] = 0.0f;
    self->texcoords[1] = 1.0f;
    self->texcoords[2] = 1.0f;
    self->texcoords[3] = 1.0f;
    self->texcoords[4] = 0.0f;
    self->texcoords[5] = 0.0f;
    self->texcoords[6] = 1.0f;
    self->texcoords[7] = 0.0f;
}

- (void)texCoordsCropRight:(GLfloat)cropRight {
    self->texcoords[0] = 0.0f;
    self->texcoords[1] = 1.0f;
    self->texcoords[2] = 1.0f - cropRight;
    self->texcoords[3] = 1.0f;
    self->texcoords[4] = 0.0f;
    self->texcoords[5] = 0.0f;
    self->texcoords[6] = 1.0f - cropRight;
    self->texcoords[7] = 0.0f;
}

- (void)texCoordsReload {
    glVertexAttribPointer(self->av2_texcoord, 2, GL_FLOAT, GL_FALSE, 0, self->texcoords);
    GS_GLES2_checkError_TRACE("glVertexAttribPointer(av2_texcoord)");
    glEnableVertexAttribArray(self->av2_texcoord);
    GS_GLES2_checkError_TRACE("glEnableVertexAttribArray(av2_texcoord)");
}

#pragma mark - vertices

- (void)verticesApply {
    switch (self->gravity) {
        case GS_GLES2_GRAVITY_RESIZE_ASPECT:
            break;
        case GS_GLES2_GRAVITY_RESIZE_ASPECT_FILL:
            break;
        case GS_GLES2_GRAVITY_RESIZE:
//            [self reset];
            return;
        default:
            printf("[Gensee][GLES2] unknown gravity %d\n", self->gravity);
            [self reset];
            return;
    }
    
    if (self->layer_width <= 0 ||
        self->layer_height <= 0 ||
        self->frame_width <= 0 ||
        self->frame_height <= 0)
    {
        printf("[Gensee][GLES2] invalid width/height for gravity aspect\n");
        [self reset];
        return;
    }
    
    float width     = self->frame_width;
    float height    = self->frame_height;
    
    if (self->frame_sar_num > 0 && self->frame_sar_den > 0) {
        width = width * self->frame_sar_num / self->frame_sar_den;
    }
    
    const float dW  = (float)self->layer_width    / width;
    const float dH  = (float)self->layer_height / height;
    float dd        = 1.0f;
    float nW        = 1.0f;
    float nH        = 1.0f;
    
    switch (self->gravity) {
        case GS_GLES2_GRAVITY_RESIZE_ASPECT_FILL:  dd = FFMAX(dW, dH); break;
        case GS_GLES2_GRAVITY_RESIZE_ASPECT:       dd = FFMIN(dW, dH); break;
    }
    
    nW = (width  * dd / (float)self->layer_width);
    nH = (height * dd / (float)self->layer_height);
    
    self->vertices[0] = - nW;
    self->vertices[1] = - nH;
    self->vertices[2] =   nW;
    self->vertices[3] = - nH;
    self->vertices[4] = - nW;
    self->vertices[5] =   nH;
    self->vertices[6] =   nW;
    self->vertices[7] =   nH;
}

- (void)verticesReset {
    //纹理
    self->vertices[0] = -1.0f;
    self->vertices[1] = -1.0f;
    self->vertices[2] =  1.0f;
    self->vertices[3] = -1.0f;
    self->vertices[4] = -1.0f;
    self->vertices[5] =  1.0f;
    self->vertices[6] =  1.0f;
    self->vertices[7] =  1.0f;
}

- (void)verticesReloadVertex {
    glVertexAttribPointer(self->av4_position, 2, GL_FLOAT, GL_FALSE, 0, self->vertices);
    GS_GLES2_checkError_TRACE("glVertexAttribPointer(av2_texcoord)");
    glEnableVertexAttribArray(self->av4_position);
    GS_GLES2_checkError_TRACE("glEnableVertexAttribArray(av2_texcoord)");
}

#pragma mark - state

- (BOOL)isvalidate {
    BOOL re = self->program ? YES : NO;
    return re;
}

- (BOOL)isFormat:(int)format {
    if (![self isvalidate]) {
        return NO;
    }
    return self->format == format ? YES : NO;
}

- (const char *)fragmentShaderSource {
    ALOGW("must rewrite this method to set your fragment shader string");
    const char g_shader[] = "";
    return g_shader;
}

- (GLsizei)bufferWidth:(GSGLBuffer *)overlay {
    return overlay->pitches[0] / 1;
}

@end
