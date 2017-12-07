//
//  ViewController.m
//  XDXCropSampleBuffer
//
//  Created by demon on 12/07/2017.
//  Copyright © 2017 demon. All rights reserved.
//

/*************************************************************************************************************************************/

// 注意 ： 本Demo中将界面只允许竖屏,长按即为捕捉画面，捕捉画面的数据在AVCaptureVideoDataOutputSampleBufferDelegate 中的 cropSampleBuffer 数据结构中,裁剪代码在方法- (CMSampleBufferRef)cropSampleBuffer:(CMSampleBufferRef)buffer withCropRect:(CGRect)cropRect 中，其余为初始化相机界面与长按点击事件的方法。

// 本文中注释为Log4cplus 代码，如果你的机器有可以打开注释，如果没有可以自行替换为NSLog获取一些信息

// 本文具体解析请参考：  GitHub : https://github.com/ChengyangLi/Crop-sample-buffer
//                   博客    : https://chengyangli.github.io/2017/07/12/cropSampleBuffer/
//                   简书    : http://www.jianshu.com/p/ac79a80f1af2

/*************************************************************************************************************************************/

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "XDXCropView.h"

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height

#define currentResolutionW 1920
#define currentResolutionH 1080
#define currentResolution AVCaptureSessionPreset1920x1080

// 截取cropView的大小
int g_width_size  = 1280;
int g_height_size = 720;

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    CIContext *_ciContext;
}
@property (nonatomic, strong) AVCaptureSession              *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer    *captureVideoPreviewLayer;
@property (nonatomic, strong) XDXCropView                   *cropView;
@property (nonatomic, assign) BOOL                          isOpenGPU;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 设置始终横屏
    [self setScreenCross];
    
    // 初始化相机Preview相关参数
    [self initCapture];
    
    // 初始化CropView的参数
    /*  初始化CropView的参数
        注意：本Demo中如果设置4K需要手机硬件设备的支持，即iPhone 6s以上才支持，使用GPU进行切割如果是4K画面切2K画面，目前尚存在问题，亲测只能维持5分钟开始严重掉帧，博客里有详细介绍原因，这里不过多说明。
     */
    self.isOpenGPU = NO;
    self.cropView = [[XDXCropView alloc] initWithOpen4K:NO OpenGpu:self.isOpenGPU cropWidth:g_width_size cropHeight:g_height_size screenResolutionW:currentResolutionW screenResolutionH:currentResolutionH];
    [self.cropView isEnableCrop:YES session:_captureSession captureLayer:_captureVideoPreviewLayer mainView:self.view];
//    self.cropView.center          = self.view.center;
    self.cropView.backgroundColor = [UIColor clearColor];
    [self.view  bringSubviewToFront:_cropView];
    
    UILongPressGestureRecognizer *pressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressed:)];
    [self.view addGestureRecognizer:pressGesture];
}


- (void)longPressed:(UITapGestureRecognizer *)recognizer {
    CGPoint currentPoint = [recognizer locationInView:recognizer.view];
    [self.cropView longPressedWithCurrentPoint:currentPoint
                                     isOpenGpu:self.isOpenGPU];
}

- (void)setScreenCross {
    if([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)]) {
        SEL selector = NSSelectorFromString(@"setOrientation:");
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[UIDevice instanceMethodSignatureForSelector:selector]];
        [invocation setSelector:selector];
        [invocation setTarget:[UIDevice currentDevice]];
        int val = UIInterfaceOrientationLandscapeLeft;//横屏
        [invocation setArgument:&val atIndex:2];
        [invocation invoke];
    }
}

- (void)initCapture
{
    // 获取后置摄像头设备
    AVCaptureDevice *inputDevice            = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    // 创建输入数据对象
    AVCaptureDeviceInput *captureInput      = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:nil];
    if (!captureInput) return;
    
    // 创建一个视频输出对象
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    [captureOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    NSString     *key           = (NSString *)kCVPixelBufferPixelFormatTypeKey;
    NSNumber     *value         = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    
    [captureOutput setVideoSettings:videoSettings];
    
    
    self.captureSession = [[AVCaptureSession alloc] init];
    NSString *preset;
    
#warning 注意，iPhone 6s以上设备可以设置为2K，若测试设备为6S以下则需要降低分辨率，但本APP中只支持16:9的分辨率
    if (!preset) preset = AVCaptureSessionPreset1920x1080;
    
    if ([_captureSession canSetSessionPreset:preset]) {
        self.captureSession.sessionPreset = preset;
    }else {
        self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    }
    
    if ([self.captureSession canAddInput:captureInput]) {
        [self.captureSession addInput:captureInput];
    }
    if ([self.captureSession canAddOutput:captureOutput]) {
        [self.captureSession addOutput:captureOutput];
    }
    
    // 创建视频预览图层
    if (!self.captureVideoPreviewLayer) {
        self.captureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    }
    
    self.captureVideoPreviewLayer.frame         = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
    self.captureVideoPreviewLayer.videoGravity  = AVLayerVideoGravityResizeAspectFill;
    if([[self.captureVideoPreviewLayer connection] isVideoOrientationSupported])
    {
        [self.captureVideoPreviewLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
    }

    [self.view.layer     addSublayer:self.captureVideoPreviewLayer];
    [self.captureSession startRunning];
}

#pragma mark ------------------AVCaptureVideoDataOutputSampleBufferDelegate--------------------------------
// Called whenever an AVCaptureVideoDataOutput instance outputs a new video frame. 每产生一帧视频帧时调用一次
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CMSampleBufferRef cropSampleBuffer;
    
#warning 两种切割方式任选其一，GPU切割性能较好，CPU切割取决于设备，一般时间长会掉帧。
    if (self.isOpenGPU) {
         cropSampleBuffer = [self.cropView cropSampleBufferByHardware:sampleBuffer];
    }else {
         cropSampleBuffer = [self.cropView cropSampleBufferBySoftware:sampleBuffer];
    }
    
    // 使用完后必须显式release，不在iOS自动回收范围
    CFRelease(cropSampleBuffer);
}

@end
