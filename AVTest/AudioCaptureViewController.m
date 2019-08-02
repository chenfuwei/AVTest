//
//  AudioCaptureViewController.m
//  AVTest
//
//  Created by net263 on 2019/8/2.
//  Copyright © 2019 net263. All rights reserved.
//

#import "AudioCaptureViewController.h"
#import "VTAudioCapture.h"

@interface AudioCaptureViewController ()
@property(strong, nonatomic)VTAudioCapture* vtAudioCapture;

@end

@implementation AudioCaptureViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UIButton* video = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_WIDTH / 2.0 - 50, MARGIN_TOP, 100, 30)];
    video.backgroundColor = [UIColor blueColor];
    [video setTitle:@"AudioToolBox(开始)" forState:UIControlStateNormal];
    [video addTarget:self action:@selector(start:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:video];
    
    UIButton* stop = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_WIDTH / 2.0 - 50, MARGIN_TOP + 30 + 30, 100, 30)];
    stop.backgroundColor = [UIColor blueColor];
    [stop setTitle:@"AudioToolBox(结束)" forState:UIControlStateNormal];
    [stop addTarget:self action:@selector(stop:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:stop];
}

-(void)start:(UIButton*)sender
{
    self.vtAudioCapture = [[VTAudioCapture alloc] init];
    [self.vtAudioCapture start];
}

-(void)stop:(UIButton*)sender
{
    [self.vtAudioCapture stop];
}

@end
