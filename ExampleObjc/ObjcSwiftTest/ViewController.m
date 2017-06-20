//
//  ViewController.m
//  ObjcSwiftTest
//
//  Created by boska on 23/05/2017.
//  Copyright © 2017 boska. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>


@import ViscoveryADSDK;

@interface VideoView : UIView
  @end
@implementation VideoView
+ (Class) layerClass {
  return [AVPlayerLayer class];
}
  @end

@interface ViewController ()
@property(nonatomic,weak) IBOutlet VideoView *videoView;
@property(nonatomic,strong) AVPlayer *contentPlayer;
@property(nonatomic,strong) AdsManager *adsManager;
@end


@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  NSURL *url = [[NSURL alloc]initWithString:@"http://viscovery-vsp-dev.s3.amazonaws.com/sdkdemo/Videos/Mobile%20App_Demo%20Video%20(540p).mp4"];
  
  self.contentPlayer = [AVPlayer playerWithURL:url];
  ((AVPlayerLayer *)self.videoView.layer).player = self.contentPlayer;
  self.adsManager = [[AdsManager alloc] initWithPlayer:self.contentPlayer videoView:self.videoView outstreamContainerView:nil];
  [self.adsManager requestAdsWithVideoURL:nil];
  
  //[self.adsManager requestAdsWithVideoURL:nil];
}

@end
