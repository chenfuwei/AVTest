//
//  GSGLRenderColors.m
//  PlayerSDK
//
//  Created by gensee on 2019/1/11.
//  Copyright © 2019年 Geensee. All rights reserved.
//

#import "GSGLRenderColors.h"

// BT.709, which is the standard for HDTV.
static const GLfloat gs_color_bt709[] = {
    1.164,  1.164,  1.164,
    0.0,   -0.213,  2.112,
    1.793, -0.533,  0.0,
};


static const GLfloat gs_color_bt601[] = {
    1.164,  1.164, 1.164,
    0.0,   -0.392, 2.017,
    1.596, -0.813, 0.0,
};


@implementation GSGLRenderColors

+ (const GLfloat *)GLES2_getColorMatrix_bt709 {
    return gs_color_bt709;
}

+ (const GLfloat *)GLES2_getColorMatrix_bt601 {
    return gs_color_bt601;
}

@end
