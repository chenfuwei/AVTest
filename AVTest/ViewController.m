//
//  ViewController.m
//  AVTest
//
//  Created by net263 on 2019/7/26.
//  Copyright © 2019 net263. All rights reserved.
//

#import "ViewController.h"
#import "AVFoundationViewController.h"

@interface ViewController ()<UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@end

@implementation ViewController
{
    UIImageView* imageView;
    UIImageView* imageView1;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIButton* video = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_WIDTH / 2.0 - 50, MARGIN_TOP, 100, 30)];
    video.backgroundColor = [UIColor blueColor];
    [video setTitle:@"视频(AVFoundation)" forState:UIControlStateNormal];
    [video addTarget:self action:@selector(videoTest:) forControlEvents:UIControlEventTouchUpInside];
    
    
    UIButton* audio = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_WIDTH / 2.0 - 50, MARGIN_TOP + 30 + 30, 100, 30)];
    audio.backgroundColor = [UIColor blueColor];
    [audio setTitle:@"音频" forState:UIControlStateNormal];
    [audio addTarget:self action:@selector(audioTest:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:video];
    [self.view addSubview:audio];
    
    
    UIButton* takePhoto = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_WIDTH / 2.0 - 50, MARGIN_TOP + 30 + 30 + 30 + 30, 100, 30)];
    takePhoto.backgroundColor = [UIColor blueColor];
    [takePhoto setTitle:@"拍照" forState:UIControlStateNormal];
    [takePhoto addTarget:self action:@selector(takePhoto:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:takePhoto];
    
    UIButton* takePhoto1 = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_WIDTH / 2.0 - 50, MARGIN_TOP + 30 + 30 + 30 + 30 + 30 + 30, 100, 30)];
    takePhoto1.backgroundColor = [UIColor blueColor];
    [takePhoto1 setTitle:@"从相册中取" forState:UIControlStateNormal];
    [takePhoto1 addTarget:self action:@selector(fromAblum:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:takePhoto1];
    
    UIButton* takeVideo = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_WIDTH / 2.0 - 50, MARGIN_TOP + 30 + 30 + 30 + 30 + 30 + 30 + 30 + 30, 100, 30)];
    takeVideo.backgroundColor = [UIColor blueColor];
    [takeVideo setTitle:@"视频录制" forState:UIControlStateNormal];
    [takeVideo addTarget:self action:@selector(takeVideo:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:takeVideo];
    
    
    imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT - 150, 150, 150)];
    [self.view addSubview:imageView];
    
    imageView1 = [[UIImageView alloc] initWithFrame:CGRectMake(150 + 50, SCREEN_HEIGHT - 150, 150, 150)];
    [self.view addSubview:imageView1];
}

-(void)videoTest:(UIButton*)sender
{
    AVFoundationViewController* avController = [[AVFoundationViewController alloc] init];
    [self.navigationController pushViewController:avController animated:YES];
}

-(void)audioTest:(UIButton*)sender
{
    
}

-(void)takePhoto:(UIButton*)sender
{
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        UIImagePickerController* pickerController = [[UIImagePickerController alloc] init];
        pickerController.delegate = self;
        pickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
        pickerController.cameraDevice = UIImagePickerControllerCameraDeviceRear;
        pickerController.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
        pickerController.allowsEditing = YES;
        
        [self presentViewController:pickerController animated:YES completion:nil];
    }
}

-(void)fromAblum:(UIButton*)sender
{
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
    {
        UIImagePickerController* pickerController = [[UIImagePickerController alloc] init];
        pickerController.delegate = self;
        pickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        pickerController.allowsEditing = YES;
        [self presentViewController:pickerController animated:YES completion:nil];
    }
}

-(void)takeVideo:(UIButton*)sender
{
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        UIImagePickerController* pickerController = [[UIImagePickerController alloc] init];
        pickerController.delegate = self;
        pickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
        pickerController.cameraDevice = UIImagePickerControllerCameraDeviceRear;
        pickerController.mediaTypes =  [NSArray arrayWithObjects:@"public.movie", nil];//@”public.image",[UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
        pickerController.allowsEditing = YES;
        pickerController.cameraCaptureMode = UIImagePickerControllerCameraCaptureModeVideo;
        
        [self presentViewController:pickerController animated:YES completion:nil];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    ReLog("cancel");
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info
{
    ReLog(@"info = %@", info);
    [self dismissViewControllerAnimated:YES completion:nil];
    NSString* mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    if([mediaType isEqualToString:@"public.image"])
    {
        UIImage* image = [info objectForKey:UIImagePickerControllerOriginalImage];
        imageView.image = image;
        
        UIImage* editImage = [info objectForKey:UIImagePickerControllerEditedImage];
        imageView1.image = editImage;
    }
}

@end
