//
//  gscommon.c
//  GSCommonKit
//
//  Created by gensee on 2019/1/15.
//  Copyright © 2019年 gensee. All rights reserved.
//

#include "glcommon.h"


void GS_GLES2_checkError(const char* op) {
    for (GLint error = glGetError(); error; error = glGetError()) {
        ALOGE("[Gensee][GLES2] after %s() glError (0x%x)\n", op, error);
    }
}

void GS_GLES2_printString(const char *name, GLenum s) {
    const char *v = (const char *) glGetString(s);
    ALOGI("[Gensee][GLES2] %s = %s\n", name, v);
}

static void GS_GLES2_printShaderInfo(GLuint shader)
{
    if (!shader)
        return;
    
    GLint info_len = 0;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &info_len);
    if (!info_len) {
        ALOGE("[Gensee][GLES2][Shader] empty info");
        return;
    }
    
    char    buf_stack[32];
    char   *buf_heap = NULL;
    char   *buf      = buf_stack;
    GLsizei buf_len  = sizeof(buf_stack) - 1;
    if (info_len > sizeof(buf_stack)) {
        buf_heap = (char*) malloc(info_len + 1);
        if (buf_heap) {
            buf     = buf_heap;
            buf_len = info_len;
        }
    }
    
    glGetShaderInfoLog(shader, buf_len, NULL, buf);
    ALOGE("[Gensee][GLES2][Shader] error %s", buf);
    
    if (buf_heap)
        free(buf_heap);
}

void GS_GLES2_loadOrtho(GS_GLES_Matrix *matrix, GLfloat left, GLfloat right, GLfloat bottom, GLfloat top, GLfloat near, GLfloat far)
{
    GLfloat r_l = right - left;
    GLfloat t_b = top - bottom;
    GLfloat f_n = far - near;
    GLfloat tx = - (right + left) / (right - left);
    GLfloat ty = - (top + bottom) / (top - bottom);
    GLfloat tz = - (far + near) / (far - near);
    
    matrix->m[0] = 2.0f / r_l;
    matrix->m[1] = 0.0f;
    matrix->m[2] = 0.0f;
    matrix->m[3] = 0.0f;
    
    matrix->m[4] = 0.0f;
    matrix->m[5] = 2.0f / t_b;
    matrix->m[6] = 0.0f;
    matrix->m[7] = 0.0f;
    
    matrix->m[8] = 0.0f;
    matrix->m[9] = 0.0f;
    matrix->m[10] = -2.0f / f_n;
    matrix->m[11] = 0.0f;
    
    matrix->m[12] = tx;
    matrix->m[13] = ty;
    matrix->m[14] = tz;
    matrix->m[15] = 1.0f;
}


GLuint GS_GLES2_loadShader(GLenum shader_type, const char *shader_source)
{
    assert(shader_source);
    
    GLuint shader = glCreateShader(shader_type);        GS_GLES2_checkError("glCreateShader");
    if (!shader)
        return 0;
    
    assert(shader_source);
    
    glShaderSource(shader, 1, &shader_source, NULL);    GS_GLES2_checkError_TRACE("glShaderSource");
    glCompileShader(shader);                            GS_GLES2_checkError_TRACE("glCompileShader");
    
    GLint compile_status = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compile_status);
    if (!compile_status)
        goto fail;
    
    return shader;
    
fail:
    
    if (shader) {
        GS_GLES2_printShaderInfo(shader);
        glDeleteShader(shader);
    }
    
    return 0;
}



