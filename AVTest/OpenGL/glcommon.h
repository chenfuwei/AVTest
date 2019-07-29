//
//  gscommon.h
//  GSCommonKit
//
//  Created by gensee on 2019/1/15.
//  Copyright © 2019年 gensee. All rights reserved.
//

#ifndef glcommon_h
#define glcommon_h

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

typedef struct GS_GLES_Matrix
{
    GLfloat m[16];
} GS_GLES_Matrix;


#define FFMAX(a,b) ((a) > (b) ? (a) : (b))
#define FFMAX3(a,b,c) FFMAX(FFMAX(a,b),c)
#define FFMIN(a,b) ((a) > (b) ? (b) : (a))
#define FFMIN3(a,b,c) FFMIN(FFMIN(a,b),c)


#define GS_LOG_UNKNOWN     0
#define GS_LOG_DEFAULT     1

#define GS_LOG_VERBOSE     2
#define GS_LOG_DEBUG       3
#define GS_LOG_INFO        4
#define GS_LOG_WARN        5
#define GS_LOG_ERROR       6
#define GS_LOG_FATAL       7
#define GS_LOG_SILENT      8

#define VLOG(level, TAG, ...)    ((void)vprintf(__VA_ARGS__))
#define ALOG(level, TAG, ...)    ((void)printf(__VA_ARGS__))

#define VLOGV(...)  VLOG(GS_LOG_VERBOSE,   GS_LOG_TAG, __VA_ARGS__)
#define VLOGD(...)  VLOG(GS_LOG_DEBUG,     GS_LOG_TAG, __VA_ARGS__)
#define VLOGI(...)  VLOG(GS_LOG_INFO,      GS_LOG_TAG, __VA_ARGS__)
#define VLOGW(...)  VLOG(GS_LOG_WARN,      GS_LOG_TAG, __VA_ARGS__)
#define VLOGE(...)  VLOG(GS_LOG_ERROR,     GS_LOG_TAG, __VA_ARGS__)

#define ALOGV(...)  ALOG(GS_LOG_VERBOSE,   GS_LOG_TAG, __VA_ARGS__)
#define ALOGD(...)  ALOG(GS_LOG_DEBUG,     GS_LOG_TAG, __VA_ARGS__)
#define ALOGI(...)  ALOG(GS_LOG_INFO,      GS_LOG_TAG, __VA_ARGS__)
#define ALOGW(...)  ALOG(GS_LOG_WARN,      GS_LOG_TAG, __VA_ARGS__)
#define ALOGE(...)  ALOG(GS_LOG_ERROR,     GS_LOG_TAG, __VA_ARGS__)

#define GS_GLES2_GRAVITY_RESIZE                (0) // Stretch to fill view bounds.
#define GS_GLES2_GRAVITY_RESIZE_ASPECT         (1) // Preserve aspect ratio; fit within view bounds.
#define GS_GLES2_GRAVITY_RESIZE_ASPECT_FILL    (2) // Preserve aspect ratio; fill view bounds.

#ifdef DEBUG
#define GS_GLES2_checkError_TRACE(op)
#define GS_GLES2_checkError_DEBUG(op)
#else
#define GS_GLES2_checkError_TRACE(op) GS_GLES2_checkError(op)
#define GS_GLES2_checkError_DEBUG(op) GS_GLES2_checkError(op)
#endif

void GS_GLES2_printString(const char *name, GLenum s);
void GS_GLES2_checkError(const char *op);

GLuint GS_GLES2_loadShader(GLenum shader_type, const char *shader_source);
void GS_GLES2_loadOrtho(GS_GLES_Matrix *matrix, GLfloat left, GLfloat right, GLfloat bottom, GLfloat top, GLfloat near, GLfloat far);

#endif /* gscommon_h */
