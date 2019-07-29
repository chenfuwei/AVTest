//
//  AVFoundationViewController.m
//  AVTest
//
//  Created by net263 on 2019/7/26.
//  Copyright © 2019 net263. All rights reserved.
//

#import "AVFoundationViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "GSSDLGLView.h"
#import "GSGLBuffer.h"

@interface AVFoundationViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@end

@implementation AVFoundationViewController
{
    AVCaptureSession* _session;
    AVCaptureDevice* _videoDevice;
    AVCaptureDeviceInput* _videoInput;
    AVCaptureVideoDataOutput* _videoDataOutput;
    
    UIImageView* _imageView;
    UIView* _previewView;
    AVCaptureDevicePosition _devicePosition;
    BOOL _enableTorch;
    int _outPutFormateType;
    GSSDLGLView* _sdlGlView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIButton* video = [[UIButton alloc] initWithFrame:CGRectMake(50, MARGIN_TOP, 100, 30)];
    video.backgroundColor = [UIColor blueColor];
    [video setTitle:@"开始预览" forState:UIControlStateNormal];
    [video addTarget:self action:@selector(startCapture:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:video];
    
    UIButton* video1 = [[UIButton alloc] initWithFrame:CGRectMake( 50 + 100 + 10, MARGIN_TOP, 100, 30)];
    video1.backgroundColor = [UIColor blueColor];
    [video1 setTitle:@"停止预览" forState:UIControlStateNormal];
    [video1 addTarget:self action:@selector(stopCapture:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:video1];
    
    UIButton* video2 = [[UIButton alloc] initWithFrame:CGRectMake( 50 + 100 + 10 + 100 + 10, MARGIN_TOP, 100, 30)];
    video2.backgroundColor = [UIColor blueColor];
    [video2 setTitle:@"切换摄像头" forState:UIControlStateNormal];
    [video2 addTarget:self action:@selector(switchCamera:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:video2];
    
    UIButton* video3 = [[UIButton alloc] initWithFrame:CGRectMake(50, MARGIN_TOP + 10 + 30, 100, 30)];
    video3.backgroundColor = [UIColor blueColor];
    [video3 setTitle:@"闪光灯" forState:UIControlStateNormal];
    [video3 addTarget:self action:@selector(switchFlash:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:video3];
    
    UIButton* video4 = [[UIButton alloc] initWithFrame:CGRectMake( 50 + 100 + 10, MARGIN_TOP + 10 + 30, 100, 30)];
    video4.backgroundColor = [UIColor blueColor];
    [video4 setTitle:@"聚焦" forState:UIControlStateNormal];
    [video4 addTarget:self action:@selector(switchFocus:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:video4];
    
    _previewView = [[UIView alloc] initWithFrame:CGRectMake(0, MARGIN_TOP+100, SCREEN_WIDTH, SCREEN_WIDTH)];
    [self.view addSubview:_previewView];
    UITapGestureRecognizer* tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapFocus:)];
    [_previewView addGestureRecognizer:tapGestureRecognizer];
    
    _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT-100, 100, 100)];
    [self.view addSubview:_imageView];
    
    _sdlGlView = [[GSSDLGLView  alloc] initWithFrame:CGRectMake(100 + 10, SCREEN_HEIGHT-100, 100, 100)];
    [self.view addSubview:_sdlGlView];
    
    _devicePosition = AVCaptureDevicePositionBack;
    _outPutFormateType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    //kCVPixelFormatType_32BGRA;;//kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;//kCVPixelFormatType_32BGRA;
    //kCVPixelFormatType_420YpCbCr8BiPlanarFullRange与kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange，只是颜色精度不一样s
}

-(void)stopCapture:(UIButton*)sender
{
    if(_session.isRunning)
    {
        [_session stopRunning];
    }
}

-(void)startCapture:(UIButton*)sender
{
    [self initAVCaptureSession];
    [_session startRunning];
}

-(void)switchFocus:(UIButton*)sender
{
    
}

-(void)switchFlash:(UIButton*)sender
{
    _enableTorch = !_enableTorch;
    AVCaptureDevice* device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if([device hasFlash] && [device hasTorch])
    {
        [device lockForConfiguration:nil];
        if(_enableTorch)
        {
            [device setTorchMode:AVCaptureTorchModeOn];
        }else{
            [device setTorchMode:AVCaptureTorchModeOff];
        }
        [device unlockForConfiguration];
    }
}

-(void)switchCamera:(UIButton*)sender
{
    [self stopCapture:nil];
    [self removeVideoInput];
    if(_devicePosition == AVCaptureDevicePositionBack)
    {
        _devicePosition = AVCaptureDevicePositionFront;
        [self videoInput];
    }else{
        _devicePosition = AVCaptureDevicePositionBack;
        [self videoInput];
    }
    [self startCapture:nil];
}

-(void)tapFocus:(id)sender
{
    if([sender isKindOfClass:[UITapGestureRecognizer class]])
    {
        UITapGestureRecognizer* recognizer = (UITapGestureRecognizer*)sender;
        if(recognizer.state == UIGestureRecognizerStateRecognized)
        {
            CGPoint location = [sender locationInView:_previewView];
            [self focusAtPoint:location completionHandler:^{
                
            }];
        }
    }
}

-(void)initAVCaptureSession
{
    _session = [[AVCaptureSession alloc] init];
    BOOL bSupport = [_session canSetSessionPreset:AVCaptureSessionPreset640x480];
    if(bSupport)
    {
        _session.sessionPreset = AVCaptureSessionPreset640x480;
    }else{
        _session.sessionPreset = AVCaptureSessionPresetMedium;
    }
    [_session beginConfiguration];
    [self videoInput];
    [self videoOutput];
    [_session commitConfiguration];
    
    [self addAVCaptureVideoPreviewLayer];
}

-(void)addAVCaptureVideoPreviewLayer
{
    AVCaptureVideoPreviewLayer* previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    previewLayer.frame = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_WIDTH);
    [previewLayer setVideoGravity: AVLayerVideoGravityResizeAspectFill];
    [_previewView.layer addSublayer:previewLayer];
}

-(void)videoInput
{
    _videoDevice = [self cameraWithPositionAfter10:_devicePosition];
    NSError* error;
    _videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_videoDevice error:&error];
    if(error)
    {
        ReLog(@"avcapturedeviceinput alloc error");
        return;
    }
    
    if([_session canAddInput:_videoInput])
    {
        [_session addInput:_videoInput];
    }
}

-(void)removeVideoInput
{
    if(nil != _videoInput)
    {
        [_session removeInput:_videoInput];
        _videoInput = nil;
    }
}

-(void)videoOutput
{
    _videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    _videoDataOutput.alwaysDiscardsLateVideoFrames = NO;
    //NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]
    // On iOS, the only supported key is kCVPixelBufferPixelFormatTypeKey. Supported pixel formats are kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange and kCVPixelFormatType_32BGRA.
    NSDictionary* dictionary = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:_outPutFormateType], (id)kCVPixelBufferPixelFormatTypeKey,nil];
    [_videoDataOutput setVideoSettings:dictionary];
    dispatch_queue_t videoQueue = dispatch_get_global_queue(0, 0);
    [_videoDataOutput setSampleBufferDelegate:self queue:videoQueue];
    if([_session canAddOutput:_videoDataOutput])
    {
        [_session addOutput:_videoDataOutput];
    }
}

-(void)focusAtPoint:(CGPoint)point completionHandler:(void(^)(void))completionHandler
{
    AVCaptureDevice* device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    CGPoint pointOfInterest = CGPointZero;
    CGSize frameSize = _previewView.bounds.size;
    pointOfInterest = CGPointMake(point.y / frameSize.height, 1.f - (point.x / frameSize.width));
    if([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus])
    {
        NSError* error;
        if([device lockForConfiguration:&error])
        {
            if([device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance])
            {
                [device setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
            }
            
            if([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
            {
                [device setFocusMode:AVCaptureFocusModeAutoFocus];
                [device setFocusPointOfInterest:pointOfInterest];
            }
            
            if([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
            {
                [device setExposurePointOfInterest:pointOfInterest];
                [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            }
            [device unlockForConfiguration];
            completionHandler();
        }
    }else{
        completionHandler();
    }
}

-(AVCaptureDevice*)cameraWithPositionBefore10:(AVCaptureDevicePosition)position
{
    NSArray* devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for(AVCaptureDevice* device in devices)
    {
        if(device.position == position)
        {
            return device;
        }
    }
    return nil;
}

-(AVCaptureDevice*)cameraWithPositionAfter10:(AVCaptureDevicePosition)position
{
    AVCaptureDeviceDiscoverySession* discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
    NSArray* deviceIOS = discoverySession.devices;
    for(AVCaptureDevice* device in deviceIOS)
    {
        if([device position] == position)
        {
            return device;
        }
    }
    return nil;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if(_outPutFormateType == kCVPixelFormatType_32BGRA)
    {
        UIImage* image = [self imageFromSampleBuffer:sampleBuffer];
        __weak typeof (self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            strongSelf->_imageView.image = image;
        });
    }else if(_outPutFormateType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
    {
        [self imageFromYUV420VideoRange:sampleBuffer];
    }else if(_outPutFormateType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
    {
        [self imageFromYUV420VideoRange:sampleBuffer];
    }
}

-(void)imageFromYUV420VideoRange:(CMSampleBufferRef)sampleBuffer
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);

    void* imageAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    Byte* buffer1 = malloc(width * height * 3 / 2);
    memcpy(buffer1, imageAddress, width* height);

    size_t a = width * height;
    size_t b = width * height * 5 / 4;
    for (NSInteger i = 0; i < width * height / 2; i ++) {
        memcpy(buffer1 + a, imageAddress + width * height + i, 1);
        a ++;
        i ++;
        memcpy(buffer1 + b, imageAddress + width * height + i, 1);
        b ++;
    }
    
    GSGLBuffer *buffer = [[GSGLBuffer alloc] init];
    buffer->w = width;
    buffer->h = height;
    buffer->format = SDL_FCC_I420;
    
    uint8_t* y = malloc(width * height);
    memcpy(y, buffer1, width * height);
    
    uint8_t* u = malloc(width * height / 4);
    memcpy(u, buffer1 + width * height, width * height / 4);
    
    uint8_t* v = malloc(width * height / 4);
    memcpy(v, buffer1 + width * height * 5 / 4, width * height / 4);
    
    buffer->pixels[0] = y;
    buffer->pitches[0] = buffer->w;
    buffer->pixels[1] = u;
    buffer->pitches[1] = buffer->w/2;
    buffer->pixels[2] = v;
    buffer->pitches[2] = buffer->w/2;
    
    buffer->planes = 3;
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_sdlGlView display:buffer];
    });
//    //下面直接通过imageBuffer渲染
//    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//    GSGLBuffer *buffer = [[GSGLBuffer alloc] init];
//    buffer->w = (int)640;
//    buffer->h = (int)480;
//    buffer->format = SDL_FCC__VTB;
//    buffer->pixel_buffer = CVBufferRetain(imageBuffer);
//    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
//    int size = (int)CVPixelBufferGetPlaneCount(imageBuffer);
//    for (int i = 0; i < size; i ++) {
//        buffer->pixels[i] = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, i);
//        buffer->pitches[i] = CVPixelBufferGetWidthOfPlane(imageBuffer, i);
//    }
//
//    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [_sdlGlView display:buffer];
//    });
//
//    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

-(UIImage*)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    void* baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    UIImage* image = [UIImage imageWithCGImage:quartzImage scale:1.0f orientation:UIImageOrientationRight];
    
    CGImageRelease(quartzImage);
    return image;
    
}
@end
