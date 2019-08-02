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
#import "H264HardEncoderImpl.h"
#import "H264HardDecoderImpl.h"

@interface AVFoundationViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, H264HardEncoderImplDelegate, H264HardDecoderImplDelegate>
@property(nonatomic, strong)H264HardDecoderImpl* h264Decoder;
@end

@implementation AVFoundationViewController
{
    AVCaptureSession* _session;
    AVCaptureDevice* _videoDevice;
    AVCaptureDevice* _audioDevice;
    AVCaptureDeviceInput* _videoInput;
    AVCaptureDeviceInput* _audioInput;
    AVCaptureVideoDataOutput* _videoDataOutput;
    AVCaptureAudioDataOutput* _audioDataOutput;
    
    UIImageView* _imageView;
    UIView* _previewView;
    AVCaptureDevicePosition _devicePosition;
    BOOL _enableTorch;
    int _outPutFormateType;
    GSSDLGLView* _sdlGlView;
    
    
    H264HardEncoderImpl* h264Encoder;
    NSString* h264File;
    int fd;
    NSFileHandle* fileHandle;
    BOOL startCalled;
    
    NSString* pcmFile;
    NSFileHandle* pcmFileHandle;
    
}

-(void)configH264Decoder
{
    if(!self.h264Decoder)
    {
        self.h264Decoder = [[H264HardDecoderImpl alloc] init];
        self.h264Decoder.delegate = self;
    }
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
    
    UIButton* encodeVideo = [[UIButton alloc] initWithFrame:CGRectMake( 50 + 100 + 10 + 100 + 10, MARGIN_TOP + 10 + 30, 100, 30)];
    encodeVideo.backgroundColor = [UIColor blueColor];
    [encodeVideo setTitle:@"编码" forState:UIControlStateNormal];
    [encodeVideo addTarget:self action:@selector(encodeVideo:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:encodeVideo];
    
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
    
    h264Encoder = [[H264HardEncoderImpl alloc] init];
    startCalled = true;
    
    [self configH264Decoder];
}

-(void)encodeVideo:(UIButton*)sender
{
    if(startCalled)
    {
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString* documentDirectory = [paths objectAtIndex:0];
        
        h264File = [documentDirectory stringByAppendingPathComponent:@"test.h264"];
        [fileManager removeItemAtPath:h264File error:nil];
        [fileManager createFileAtPath:h264File contents:nil attributes:nil];
        
        fileHandle = [NSFileHandle fileHandleForWritingAtPath:h264File];
        [h264Encoder initEncode:640 height:480];
        h264Encoder.delegate = self;
        startCalled = false;
    }else{
        startCalled = true;
        [fileHandle closeFile];
        fileHandle = NULL;
        [h264Encoder end];
        
        [self.h264Decoder end];
    }
}

-(void)stopCapture:(UIButton*)sender
{
    if(pcmFileHandle)
    {
        [pcmFileHandle closeFile];
        pcmFileHandle = nil;
    }
    if(_session.isRunning)
    {
        [_session stopRunning];
    }
}

-(void)startCapture:(UIButton*)sender
{
    [self initAVCaptureSession];
    [_session startRunning];
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentDirectory = [paths objectAtIndex:0];
    pcmFile = [documentDirectory stringByAppendingPathComponent:@"audio.pcm"];
    [fileManager removeItemAtPath:pcmFile error:nil];
    [fileManager createFileAtPath:pcmFile contents:nil attributes:nil];
    pcmFileHandle = [NSFileHandle fileHandleForWritingAtPath:pcmFile];
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
    //无法设置音频采集的参数
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
    [self audioInput];
    [self audioOutput];
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
        ReLog(@"avcapturedeviceinput video alloc error");
        return;
    }
    
    if([_session canAddInput:_videoInput])
    {
        [_session addInput:_videoInput];
    }
}

-(void)audioInput
{
    _audioDevice = [self audioDeviceAfter10];
    NSError* error;
    _audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:_audioDevice error:&error];
    if(error)
    {
        ReLog(@"avcapturedeviceinput audio error");
        return;
    }
    if([_session canAddInput:_audioInput])
    {
        [_session addInput:_audioInput];
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

-(void)audioOutput
{
    _audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    dispatch_queue_t audioQueur = dispatch_get_global_queue(0, 0);
    [_audioDataOutput setSampleBufferDelegate:self queue:audioQueur];
    if([_session canAddOutput:_audioDataOutput])
    {
        [_session addOutput:_audioDataOutput];
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

-(AVCaptureDevice*)audioDeviceAfter10
{
    AVCaptureDeviceDiscoverySession* discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInMicrophone] mediaType:AVMediaTypeAudio position:AVCaptureDevicePositionUnspecified];
    NSArray* audioDeviceIOs = discoverySession.devices;
    ReLog(" audioDevices count:%zd", audioDeviceIOs.count);
    if(audioDeviceIOs.count > 0)
    {
        return audioDeviceIOs[0];
    }
    return nil;
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
    if(output == _videoDataOutput)
    {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if(_outPutFormateType == kCVPixelFormatType_32BGRA)
        {
            UIImage* image = [self imageFromSampleBuffer:imageBuffer];
            __weak typeof (self) weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                strongSelf->_imageView.image = image;
            });
        }else if(_outPutFormateType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        {
            //[self imageFromYUV420VideoRange:imageBuffer];
        }else if(_outPutFormateType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        {
           // [self imageFromYUV420VideoRange:imageBuffer];
        }
        
        if(!startCalled && h264Encoder)
        {
            [h264Encoder encode:sampleBuffer];
        }
    }else if(output == _audioDataOutput)
    {
        size_t size = CMSampleBufferGetTotalSampleSize(sampleBuffer);
        int8_t* audio_data = (int8_t*)malloc(size);
        memset(audio_data, 0, size);
        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        CMBlockBufferCopyDataBytes(blockBuffer, 0, size, audio_data);
        
        if(nil != pcmFileHandle)
        {
            NSData* data = [NSData dataWithBytes:audio_data length:size];
            [pcmFileHandle writeData:data];
        }
        free(audio_data);
    }
}

-(void)imageFromYUV420VideoRange:(CVImageBufferRef)imageBuffer
{

    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
 ReLog(@"decode width:%d height:%d", width, height);
    if(width <= 0 || height <= 0)
    {
        ReLog(@"decode error width:%d height:%d", width, height);
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        return;
    }
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

    free(buffer1);
    dispatch_async(dispatch_get_main_queue(), ^{
        [_sdlGlView display:buffer];
        free(y);
        free(u);
        free(v);
    });
    //下面直接通过imageBuffer渲染
   // CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
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

-(UIImage*)imageFromSampleBuffer:(CVImageBufferRef)imageBuffer
{
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

- (void)gotSpsPps:(NSData *)sps pps:(NSData *)pps
{
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof(bytes) -1);
    NSData* byteHeader = [NSData dataWithBytes:bytes length:length];
    [fileHandle writeData:byteHeader];
    [fileHandle writeData:sps];
    [fileHandle writeData:byteHeader];
    [fileHandle writeData:pps];
    
    uint8_t* spsData = malloc(length + sps.length);
    memcpy(spsData, bytes, length);
    memcpy(spsData + length, sps.bytes, sps.length);
    
    uint8_t* ppsData = malloc(length + pps.length);
    memcpy(ppsData, bytes, length);
    memcpy(ppsData + length, pps.bytes, pps.length);
    [self.h264Decoder decodeNalu:spsData  size:(uint32_t)(length + sps.length)];
    [self.h264Decoder decodeNalu:ppsData size:(uint32_t)(length + pps.length)];
    free(spsData);
    free(ppsData);
}

-(void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame;
{
    static int frameCount = 1;
    if(fileHandle != NULL)
    {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = sizeof(bytes) - 1;
        NSData* byteHeader = [NSData dataWithBytes:bytes length:length];
        [fileHandle writeData:byteHeader];
        [fileHandle writeData:data];
        
        uint8_t* h264data = malloc(length + data.length);
        memcpy(h264data, bytes, length);
        memcpy(h264data + length, data.bytes, data.length);
        [self.h264Decoder decodeNalu:h264data size:(uint32_t)(length + data.length)];
        free(h264data);
    }
}

- (void)gotDecoderFrame:(CVImageBufferRef)imageBuffer
{
    [self imageFromYUV420VideoRange:imageBuffer];
    //CFRelease(imageBuffer);
}

@end
