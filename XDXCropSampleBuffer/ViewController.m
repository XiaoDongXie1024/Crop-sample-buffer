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

// 本文具体解析请参考：  GitHub :
//                   博客    :
//                   简书    :

/*************************************************************************************************************************************/

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "XDXCropView.h"

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height

// 截取cropView的大小
int g_width_size  = 200;
int g_height_size = 200;

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession              *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer    *captureVideoPreviewLayer;
@property (nonatomic, strong) XDXCropView                   *cropView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initCapture];
    
    self.cropView                 = [[XDXCropView alloc] initWithFrame:CGRectMake(0, 0, g_width_size, g_height_size)];
    self.cropView.center          = self.view.center;
    self.cropView.backgroundColor = [UIColor clearColor];
    [self.view  addSubview:_cropView];
    [self.view  bringSubviewToFront:_cropView];
    
    UILongPressGestureRecognizer *pressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressed:)];
    [self.view addGestureRecognizer:pressGesture];
}

- (void)longPressed:(UITapGestureRecognizer *)recognizer {
    CGPoint currentPoint   = [recognizer locationInView:recognizer.view];
    CGFloat currentPointX  = currentPoint.x;
    CGFloat currentPointY  = currentPoint.y;
    
    CGFloat cropViewWidth  = g_width_size  / 2;
    CGFloat cropViewHeight = g_height_size / 2;
    
    if (currentPointX < cropViewWidth / 2) {
        currentPointX = cropViewWidth / 2;
    }else if(currentPointX > kScreenWidth - cropViewWidth / 2) {
        currentPointX = kScreenWidth - cropViewWidth / 2;
    }
    
    if (currentPointY < cropViewHeight / 2) {
        currentPointY = cropViewHeight / 2;
    }else if (currentPointY > kScreenHeight - cropViewHeight / 2) {
        currentPointY = kScreenHeight - cropViewHeight / 2;
    }
    
    self.cropView.center = CGPointMake(currentPointX, currentPointY);
}

- (void)initCapture
{
    AVCaptureDevice *inputDevice            = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *captureInput      = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:nil];
    if (!captureInput) return;

    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    [captureOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    NSString     *key           = (NSString *)kCVPixelBufferPixelFormatTypeKey;
    NSNumber     *value         = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    
    [captureOutput setVideoSettings:videoSettings];
    self.captureSession = [[AVCaptureSession alloc] init];
    NSString *preset    = 0;
    if (!preset) preset = AVCaptureSessionPresetMedium;
    
    self.captureSession.sessionPreset = preset;
    if ([self.captureSession canAddInput:captureInput]) {
        [self.captureSession addInput:captureInput];
    }
    if ([self.captureSession canAddOutput:captureOutput]) {
        [self.captureSession addOutput:captureOutput];
    }
    
    if (!self.captureVideoPreviewLayer) {
        self.captureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    }
    
    self.captureVideoPreviewLayer.frame         = self.view.bounds;
    self.captureVideoPreviewLayer.videoGravity  = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer     addSublayer:self.captureVideoPreviewLayer];
    [self.captureSession startRunning];
}

#pragma mark ------------------AVCaptureVideoDataOutputSampleBufferDelegate--------------------------------
// Called whenever an AVCaptureVideoDataOutput instance outputs a new video frame. 每产生一帧视频帧时调用一次
// software crop
- (CMSampleBufferRef)cropSampleBufferBySoftware:(CMSampleBufferRef)sampleBuffer {
    OSStatus status;
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the image buffer
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    // Get information about the image
    uint8_t *baseAddress    = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow      = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width            = CVPixelBufferGetWidth(imageBuffer);
    size_t height           = CVPixelBufferGetHeight(imageBuffer);
    NSInteger bytesPerPixel =  bytesPerRow/width;
    
    //    NSLog(@"demon pix first : %zu - %zu",width, height);
    
    CVPixelBufferRef pixbuffer;
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             [NSNumber numberWithInt:g_width_size], kCVPixelBufferWidthKey,
                             [NSNumber numberWithInt:g_height_size], kCVPixelBufferHeightKey,
                             nil];
    
    int cropX = (int)(currentResolutionW / kScreenWidth   *  self.cropView.frame.origin.x);
    int cropY = (int)(currentResolutionH / kScreenHeight  *  self.cropView.frame.origin.y);
    
    if (cropX % 2 != 0) cropX += 1;
    NSInteger baseAddressStart = cropY*bytesPerRow+bytesPerPixel*cropX;
    status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault, g_width_size, g_height_size, kCVPixelFormatType_32BGRA, &baseAddress[baseAddressStart], bytesPerRow, NULL, NULL, (CFDictionaryRef)options, &pixbuffer);
    if (status != 0) {
        log4cplus_debug("AVCaptureVideoDataOutputSampleBufferDelegate", "CVPixelBufferCreateWithBytes error %d",(int)status);
        return NULL;
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    CMSampleTimingInfo sampleTime = {
        .duration               = CMSampleBufferGetDuration(sampleBuffer),
        .presentationTimeStamp  = CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
        .decodeTimeStamp        = CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
    };
    //
    CMVideoFormatDescriptionRef videoInfo = NULL;
    status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixbuffer, &videoInfo);
    if (status != 0) log4cplus_debug("AVCaptureVideoDataOutputSampleBufferDelegate", "CMVideoFormatDescriptionCreateForImageBuffer error %d",(int)status);
    
    
    
    CMSampleBufferRef cropBuffer;
    status = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixbuffer, true, NULL, NULL, videoInfo, &sampleTime, &cropBuffer);
    if (status != 0) log4cplus_debug("AVCaptureVideoDataOutputSampleBufferDelegate", "CMSampleBufferCreateForImageBuffer error %d",(int)status);
    
    CFRelease(videoInfo);
    CVPixelBufferRelease(pixbuffer);
    
    return cropBuffer;
}


- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CGRect cropRect                     = CGRectMake(self.cropView.frame.origin.x, self.cropView.frame.origin.y, g_width_size, g_height_size);
    CMSampleBufferRef cropSampleBuffer  = [self cropSampleBuffer:sampleBuffer withCropRect:cropRect];
    // note : don't forget to release cropSampleBuffer so that avoid memory error !!!  一定要对cropSampleBuffer进行release避免内存泄露过多而发生闪退
    CFRelease(cropSampleBuffer);
}

// crop sample buffer，
- (CMSampleBufferRef)cropSampleBuffer:(CMSampleBufferRef)buffer withCropRect:(CGRect)cropRect {
    // a CMSampleBuffer's CVImageBuffer of media data.
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(buffer);
    // Locks the BaseAddress of the PixelBuffer to ensure that the memory is accessible. 对 imageBuffer 进行加锁处理保证内存可用。
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    
    /*
     First, to render to a texture, you need an image that is compatible with the OpenGL texture cache. Images that were created with the camera API are already compatible and you can immediately map them for inputs. Suppose you want to create an image to render on and later read out for some other processing though. You have to have create the image with a special property. The attributes for the image must have kCVPixelBufferIOSurfacePropertiesKey as one of the keys to the dictionary.
        如果要进行页面渲染，需要一个和OpenGL缓冲兼容的图像。用相机API创建的图像已经兼容，您可以马上映射他们进行输入。假设你从已有画面中截取一个新的画面，用作其他处理，你必须创建一种特殊的属性用来创建图像。对于图像的属性必须有kCVPixelBufferIOSurfacePropertiesKey 作为字典的Key.因此以下步骤不可省略
     
     */
    CFDictionaryRef         emptyDic; // empty value for attr value.
    CFMutableDictionaryRef  dicAttrs;
    emptyDic = CFDictionaryCreate(kCFAllocatorDefault, // our empty IOSurface properties dictionary
                               NULL,
                               NULL,
                               0,
                               &kCFTypeDictionaryKeyCallBacks,
                               &kCFTypeDictionaryValueCallBacks);
    
    dicAttrs = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                      1,
                                      &kCFTypeDictionaryKeyCallBacks,
                                      &kCFTypeDictionaryValueCallBacks);
    
    CFDictionarySetValue(dicAttrs,
                         kCVPixelBufferIOSurfacePropertiesKey,
                         emptyDic);
    
    OSStatus status;
    //options: [NSDictionary dictionaryWithObjectsAndKeys:[NSNull null], kCIImageColorSpace, nil]];
    
    // 采用CoreImage API中的方法进行切割，好处是比转换成UIImage进行切割性能高很多
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];
    ciImage          = [ciImage imageByCroppingToRect:cropRect];
    
    
    CVPixelBufferRef pixelBuffer;
    status = CVPixelBufferCreate(kCFAllocatorSystemDefault, cropRect.size.width, cropRect.size.height, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, dicAttrs, &pixelBuffer);
    
//    if (status != 0) log4cplus_debug("AVCaptureVideoDataOutputSampleBufferDelegate", "CVPixelBufferCreate error %d",(int)status);
    
    // ensures that the CVPixelBuffer is accessible in system memory. This should only be called if the base address is going to be used and the pixel data will be accessed by the CPU
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    CIContext * ciContext = [CIContext contextWithOptions: nil];
    // In OS X 10.11.3 and iOS 9.3 and later
    [ciContext render:ciImage toCVPixelBuffer:pixelBuffer bounds:cropRect colorSpace:nil];
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    CMSampleTimingInfo sampleTime = {
        .duration                 = CMSampleBufferGetDuration(buffer),
        .presentationTimeStamp    = CMSampleBufferGetPresentationTimeStamp(buffer),
        .decodeTimeStamp          = CMSampleBufferGetDecodeTimeStamp(buffer)
    };
    
    CMVideoFormatDescriptionRef videoInfo = NULL;
    status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &videoInfo);
//    if (status != 0) log4cplus_debug("AVCaptureVideoDataOutputSampleBufferDelegate", "CMVideoFormatDescriptionCreateForImageBuffer error %d",(int)status);
    
    CMSampleBufferRef cropBuffer;
    status = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, videoInfo, &sampleTime, &cropBuffer);
//    if (status != 0) log4cplus_debug("AVCaptureVideoDataOutputSampleBufferDelegate", "CMSampleBufferCreateForImageBuffer error %d",(int)status);
    
    CFRelease(dicAttrs);
    CFRelease(emptyDic);
    CFRelease(videoInfo);
    //    CFRelease(pixelBuffer);
    CVPixelBufferRelease(pixelBuffer);
    
    ciImage = nil;
    pixelBuffer = nil;
    
    return cropBuffer;
}

@end
