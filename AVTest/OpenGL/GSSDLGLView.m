/*
 * GSSDLGLView.m
 *
 * Copyright (c) 2013 Bilibili
 * Copyright (c) 2013 Zhang Rui <bbcallen@gmail.com>
 *
 * based on https://github.com/kolyvan/kxmovie
 *
 * This file is part of ijkPlayer.
 *
 * ijkPlayer is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * ijkPlayer is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with ijkPlayer; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#import "GSSDLGLView.h"
#import "GSVTBRender.h"
#import "GSYUVRenderI420.h"
#import "GSYUVRenderNV12.h"
#import "glcommon.h"
#import "GSRGBRender.h"

typedef NS_ENUM(NSInteger, GSSDLGLViewApplicationState) {
    GSSDLGLViewApplicationUnknownState = 0,
    GSSDLGLViewApplicationForegroundState = 1,
    GSSDLGLViewApplicationBackgroundState = 2
};

@interface GSSDLGLView()
@property(atomic,strong) NSRecursiveLock *glActiveLock;
@property(atomic) BOOL glActivePaused;
@end

@implementation GSSDLGLView {
    EAGLContext     *_context;
    GLuint          _framebuffer;
    GLuint          _renderbuffer;
    GLint           _backingWidth;
    GLint           _backingHeight;
    
    int             _frameCount;
    
    int64_t         _lastFrameTime;
    
    int             _rendererGravity;
    
    BOOL            _isRenderBufferInvalidated;
    
    int             _tryLockErrorCount;
    BOOL            _didSetupGL;
    BOOL            _didStopGL;
    BOOL            _didLockedDueToMovedToWindow;
    BOOL            _shouldLockWhileBeingMovedToWindow;
    NSMutableArray *_registeredNotifications;
    
    GSSDLGLViewApplicationState _applicationState;
    
    id <GSGLRenderProtocol> _renderer;
}

@synthesize isThirdGLView              = _isThirdGLView;
@synthesize scaleFactor                = _scaleFactor;
@synthesize fps                        = _fps;

+ (Class) layerClass
{
    return [CAEAGLLayer class];
}

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _tryLockErrorCount = 0;
        _shouldLockWhileBeingMovedToWindow = YES;
        self.glActiveLock = [[NSRecursiveLock alloc] init];
        _registeredNotifications = [[NSMutableArray alloc] init];
        [self registerApplicationObservers];
        _rendererGravity = 1;
        _didSetupGL = NO;
        if ([self isApplicationActive] == YES)
            [self setupGLOnce];
    }
    
    return self;
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
#if DEBUG
    NSLog(@"sdlview willMoveToWindow : %@",newWindow);
#endif
    if (!_shouldLockWhileBeingMovedToWindow) {
        [super willMoveToWindow:newWindow];
        return;
    }
    if (newWindow && !_didLockedDueToMovedToWindow) {
        [self lockGLActive];
        _didLockedDueToMovedToWindow = YES;
    }
    [super willMoveToWindow:newWindow];
}

- (void)didMoveToWindow
{
#if DEBUG
    NSLog(@"sdlview didMoveToWindow");
#endif
    [super didMoveToWindow];
    if (self.window && _didLockedDueToMovedToWindow) {
        [self unlockGLActive];
        _didLockedDueToMovedToWindow = NO;
    }
}

- (BOOL)setupEAGLContext:(EAGLContext *)context
{
    glGenFramebuffers(1, &_framebuffer);
    glGenRenderbuffers(1, &_renderbuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object %x\n", status);
        return NO;
    }
    
    GLenum glError = glGetError();
    if (GL_NO_ERROR != glError) {
        NSLog(@"failed to setup GL %x\n", glError);
        return NO;
    }
    
    return YES;
}

- (CAEAGLLayer *)eaglLayer
{
    return (CAEAGLLayer*) self.layer;
}

- (BOOL)setupGL
{
    if (_didSetupGL)
        return YES;
    
    CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking,
                                    kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                    nil];
    
    _scaleFactor = [[UIScreen mainScreen] scale];
    if (_scaleFactor < 0.1f)
        _scaleFactor = 1.0f;
    
    [eaglLayer setContentsScale:_scaleFactor];
    
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (_context == nil) {
        NSLog(@"failed to setup EAGLContext\n");
        return NO;
    }
    
    EAGLContext *prevContext = [EAGLContext currentContext];
    [EAGLContext setCurrentContext:_context];
    
    _didSetupGL = NO;
    if ([self setupEAGLContext:_context]) {
        NSLog(@"OK setup GL\n");
        _didSetupGL = YES;
    }
    
    [EAGLContext setCurrentContext:prevContext];
    return _didSetupGL;
}

- (BOOL)setupGLOnce
{
    if (_didSetupGL)
        return YES;
    
    if (![self tryLockGLActive])
        return NO;
    
    BOOL didSetupGL = [self setupGL];
    [self unlockGLActive];
    return didSetupGL;
}

- (BOOL)isApplicationActive
{
    switch (_applicationState) {
        case GSSDLGLViewApplicationForegroundState:
            return YES;
        case GSSDLGLViewApplicationBackgroundState:
            return NO;
        default: {
            UIApplicationState appState = [UIApplication sharedApplication].applicationState;
            switch (appState) {
                case UIApplicationStateActive:
                    return YES;
                case UIApplicationStateInactive:
                case UIApplicationStateBackground:
                default:
                    return NO;
            }
        }
    }
}

- (void)dealloc
{
    [self lockGLActive];
    
    _didStopGL = YES;
    
    EAGLContext *prevContext = [EAGLContext currentContext];
    [EAGLContext setCurrentContext:_context];
    
    if (_renderer) {
        [_renderer reset];
        _renderer = nil;
    }
//    GS_GLES2_Renderer_reset(_renderer);
//    GS_GLES2_Renderer_freeP(&_renderer);
    
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    
    if (_renderbuffer) {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }
    
    glFinish();
    
    [EAGLContext setCurrentContext:prevContext];
    
    _context = nil;
    
    [self unregisterApplicationObservers];
    
    [self unlockGLActive];
}

- (void)setScaleFactor:(CGFloat)scaleFactor
{
    _scaleFactor = scaleFactor;
    [self invalidateRenderBuffer];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (self.window.screen != nil) {
        _scaleFactor = self.window.screen.scale;
    }
    [self invalidateRenderBuffer];
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
    [super setContentMode:contentMode];
    
    switch (contentMode) {
        case UIViewContentModeScaleToFill:
            _rendererGravity = GS_GLES2_GRAVITY_RESIZE;
            break;
        case UIViewContentModeScaleAspectFit:
            _rendererGravity = GS_GLES2_GRAVITY_RESIZE_ASPECT;
            break;
        case UIViewContentModeScaleAspectFill:
            _rendererGravity = GS_GLES2_GRAVITY_RESIZE_ASPECT_FILL;
            break;
        default:
            _rendererGravity = GS_GLES2_GRAVITY_RESIZE_ASPECT;
            break;
    }
    [self invalidateRenderBuffer];
}

- (BOOL)setupRenderer: (GSGLBuffer *) overlay
{
    if (overlay == nil)
        return _renderer != nil;
    
  
    if (![_renderer isvalidate] ||
        ![_renderer isFormat:overlay->format]) {
        if (_renderer) [_renderer reset];
        _renderer = nil;
        
        _renderer = [self createRenderWithBuffer:overlay];
        if (![_renderer isvalidate])
            return NO;
        
        if (![_renderer useShader])
            return NO;
        
        [_renderer setGravity:_rendererGravity width:_backingWidth height:_backingHeight];
        
    }
    
    return YES;
}


- (GSGLRender*)createRenderWithBuffer:(GSGLBuffer*)buffer {
    GS_GLES2_printString("Version", GL_VERSION);
    GS_GLES2_printString("Vendor", GL_VENDOR);
    GS_GLES2_printString("Renderer", GL_RENDERER);
    GS_GLES2_printString("Extensions", GL_EXTENSIONS);
    
    GSGLRender* renderer = nil;
    switch (buffer->format) {
        case SDL_FCC__VTB:{
            GSVTBRender *vtbRender = [[GSVTBRender alloc] init];
            renderer = vtbRender;
        }
            break;
        case SDL_FCC_I420:{
            GSYUVRenderI420 *i420Render = [[GSYUVRenderI420 alloc] init];
            renderer = i420Render;
        }
            break;
        case SDL_FCC_NV12:{
            GSYUVRenderNV12 *nv12Render = [[GSYUVRenderNV12 alloc] init];
            renderer = nv12Render;
        }
            break;
        case SDL_FCC_RV16:
        case SDL_FCC_RV24:
        case SDL_FCC_RV32:{
            GSRGBRender *rgbRender = [[GSRGBRender alloc] init];
            renderer = rgbRender;
        }
            break;
        default:{
            ReLog(@"error : can't fit a GLRender");
        }
            break;
    }
    
    renderer->format = buffer->format;
    return renderer;
}

- (void)invalidateRenderBuffer
{
    NSLog(@"invalidateRenderBuffer\n");
    [self lockGLActive];
    
    _isRenderBufferInvalidated = YES;
    
//    if ([[NSThread currentThread] isMainThread]) {
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
//            if (_isRenderBufferInvalidated)
//                [self display:nil];
//        });
//    } else {
        [self display:nil];
//    }
    
    [self unlockGLActive];
}


- (void) display: (GSGLBuffer *) buffer;
{
    if (_didSetupGL == NO)
        return;
    
    if ([self isApplicationActive] == NO)
        return;
    
    if (![self tryLockGLActive]) {
        if (0 == (_tryLockErrorCount % 100)) {
            NSLog(@"GSSDLGLView:display: unable to tryLock GL active: %d\n", _tryLockErrorCount);
        }
        _tryLockErrorCount++;
        return;
    }
    
    _tryLockErrorCount = 0;
    if (_context && !_didStopGL) {
        EAGLContext *prevContext = [EAGLContext currentContext];
        [EAGLContext setCurrentContext:_context];
        [self displayInternal:buffer];
        [EAGLContext setCurrentContext:prevContext];
    }
    
    [buffer cleanCVBuffer];
    [self unlockGLActive];
}

// NOTE: overlay could be NULl
- (void)displayInternal: (GSGLBuffer *) overlay
{
    if (![self setupRenderer:overlay]) {
        if (!overlay && !_renderer) {
            NSLog(@"GSSDLGLView: setupDisplay not ready\n");
        } else {
            NSLog(@"GSSDLGLView: setupDisplay failed\n");
        }
        return;
    }
    
    [[self eaglLayer] setContentsScale:_scaleFactor];
    
    if (_isRenderBufferInvalidated) {
        NSLog(@"GSSDLGLView: renderbufferStorage fromDrawable\n");
        _isRenderBufferInvalidated = NO;
        
        glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
        [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
        [_renderer setGravity:_rendererGravity width:_backingWidth height:_backingHeight];
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, _backingWidth, _backingHeight);
    
    if (![_renderer renderBuffer:overlay])
        NSLog(@"[EGL] GS_GLES2_render failed\n");
    
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    
    int64_t current = (int64_t)CACurrentMediaTime();
    int64_t delta   = (current > _lastFrameTime) ? current - _lastFrameTime : 0;
    if (delta <= 0) {
        _lastFrameTime = current;
    } else if (delta >= 1000) {
        _fps = ((CGFloat)_frameCount) * 1000 / delta;
        _frameCount = 0;
        _lastFrameTime = current;
    } else {
        _frameCount++;
    }
}

- (void)flushWithColor:(float)red green:(float)green blue:(float)blue alpha:(float)alpha; {
    if (red > 1 && red < 0) {
        NSLog(@"[EGL] flush red invalidate");
        return;
    }
    if (green > 1 && green < 0) {
        NSLog(@"[EGL] flush green invalidate");
        return;
    }
    if (alpha > 1 && alpha < 0) {
        NSLog(@"[EGL] flush alpha invalidate");
        return;
    }
    if (!_renderer || !_context) {
        NSLog(@"[EGL] flush failed");
        return;
    }
    [_renderer cleanTexture];
    
    [EAGLContext setCurrentContext:_context];
    glViewport(0, 0, _backingWidth, _backingHeight);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
    glClearColor(red, green, blue, alpha);
    
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)flush {
    [self flushWithColor:0 green:0 blue:0 alpha:1];
}

#pragma mark AppDelegate

- (void) lockGLActive
{
    [self.glActiveLock lock];
}

- (void) unlockGLActive
{
    [self.glActiveLock unlock];
}

- (BOOL) tryLockGLActive
{
    if (![self.glActiveLock tryLock])
        return NO;
    
    /*-
     if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive &&
     [UIApplication sharedApplication].applicationState != UIApplicationStateInactive) {
     [self.appLock unlock];
     return NO;
     }
     */
    
    if (self.glActivePaused) {
        [self.glActiveLock unlock];
        return NO;
    }
    
    return YES;
}

- (void)toggleGLPaused:(BOOL)paused
{
    [self lockGLActive];
    if (!self.glActivePaused && paused) {
        if (_context != nil) {
            EAGLContext *prevContext = [EAGLContext currentContext];
            [EAGLContext setCurrentContext:_context];
            glFinish();
            [EAGLContext setCurrentContext:prevContext];
        }
    }
    self.glActivePaused = paused;
    [self unlockGLActive];
}

- (void)registerApplicationObservers
{
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [_registeredNotifications addObject:UIApplicationWillEnterForegroundNotification];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [_registeredNotifications addObject:UIApplicationDidBecomeActiveNotification];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [_registeredNotifications addObject:UIApplicationWillResignActiveNotification];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [_registeredNotifications addObject:UIApplicationDidEnterBackgroundNotification];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillTerminate)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    [_registeredNotifications addObject:UIApplicationWillTerminateNotification];
}

- (void)unregisterApplicationObservers
{
    for (NSString *name in _registeredNotifications) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:name
                                                      object:nil];
    }
}

- (void)applicationWillEnterForeground
{
    NSLog(@"GSSDLGLView:applicationWillEnterForeground: %d", (int)[UIApplication sharedApplication].applicationState);
    [self setupGLOnce];
    _applicationState = GSSDLGLViewApplicationForegroundState;
    [self toggleGLPaused:NO];
}

- (void)applicationDidBecomeActive
{
    NSLog(@"GSSDLGLView:applicationDidBecomeActive: %d", (int)[UIApplication sharedApplication].applicationState);
    [self setupGLOnce];
    [self toggleGLPaused:NO];
}

- (void)applicationWillResignActive
{
    NSLog(@"GSSDLGLView:applicationWillResignActive: %d", (int)[UIApplication sharedApplication].applicationState);
    [self toggleGLPaused:YES];
    glFinish();
}

- (void)applicationDidEnterBackground
{
    NSLog(@"GSSDLGLView:applicationDidEnterBackground: %d", (int)[UIApplication sharedApplication].applicationState);
    _applicationState = GSSDLGLViewApplicationBackgroundState;
    [self toggleGLPaused:YES];
    glFinish();
}

- (void)applicationWillTerminate
{
    NSLog(@"GSSDLGLView:applicationWillTerminate: %d", (int)[UIApplication sharedApplication].applicationState);
    [self toggleGLPaused:YES];
}

#pragma mark snapshot

- (UIImage*)snapshot
{
    [self lockGLActive];
    
    UIImage *image = [self snapshotInternal];
    
    [self unlockGLActive];
    
    return image;
}

- (UIImage*)snapshotInternal
{
    if (([[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending)) {
        return [self snapshotInternalOnIOS7AndLater];
    } else {
        return [self snapshotInternalOnIOS6AndBefore];
    }
}

- (UIImage*)snapshotInternalOnIOS7AndLater
{
    if (CGSizeEqualToSize(self.bounds.size, CGSizeZero)) {
        return nil;
    }
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0.0);
    // Render our snapshot into the image context
    [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:NO];
    
    // Grab the image from the context
    UIImage *complexViewImage = UIGraphicsGetImageFromCurrentImageContext();
    // Finish using the context
    UIGraphicsEndImageContext();
    
    return complexViewImage;
}

- (UIImage*)snapshotInternalOnIOS6AndBefore
{
    EAGLContext *prevContext = [EAGLContext currentContext];
    [EAGLContext setCurrentContext:_context];
    
    GLint backingWidth, backingHeight;
    
    // Bind the color renderbuffer used to render the OpenGL ES view
    // If your application only creates a single color renderbuffer which is already bound at this point,
    // this call is redundant, but it is needed if you're dealing with multiple renderbuffers.
    // Note, replace "viewRenderbuffer" with the actual name of the renderbuffer object defined in your class.
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    
    // Get the size of the backing CAEAGLLayer
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    NSInteger x = 0, y = 0, width = backingWidth, height = backingHeight;
    NSInteger dataLength = width * height * 4;
    GLubyte *data = (GLubyte*)malloc(dataLength * sizeof(GLubyte));
    
    // Read pixel data from the framebuffer
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels((int)x, (int)y, (int)width, (int)height, GL_RGBA, GL_UNSIGNED_BYTE, data);
    
    // Create a CGImage with the pixel data
    // If your OpenGL ES content is opaque, use kCGImageAlphaNoneSkipLast to ignore the alpha channel
    // otherwise, use kCGImageAlphaPremultipliedLast
    CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGImageRef iref = CGImageCreate(width, height, 8, 32, width * 4, colorspace, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
                                    ref, NULL, true, kCGRenderingIntentDefault);
    
    [EAGLContext setCurrentContext:prevContext];
    
    // OpenGL ES measures data in PIXELS
    // Create a graphics context with the target size measured in POINTS
    UIGraphicsBeginImageContext(CGSizeMake(width, height));
    
    CGContextRef cgcontext = UIGraphicsGetCurrentContext();
    // UIKit coordinate system is upside down to GL/Quartz coordinate system
    // Flip the CGImage by rendering it to the flipped bitmap context
    // The size of the destination area is measured in POINTS
    CGContextSetBlendMode(cgcontext, kCGBlendModeCopy);
    CGContextDrawImage(cgcontext, CGRectMake(0.0, 0.0, width, height), iref);
    
    // Retrieve the UIImage from the current context
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Clean up
    free(data);
    CFRelease(ref);
    CFRelease(colorspace);
    CGImageRelease(iref);
    
    return image;
}

- (void)setShouldLockWhileBeingMovedToWindow:(BOOL)shouldLockWhileBeingMovedToWindow
{
    _shouldLockWhileBeingMovedToWindow = shouldLockWhileBeingMovedToWindow;
}
@end
