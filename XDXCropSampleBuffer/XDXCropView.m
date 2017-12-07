//
//  XDXCropView.m
//  XDXCropSampleBuffer
//
//  Created by demon on 12/07/2017.
//  Copyright © 2017 demon. All rights reserved.
//

#import "XDXCropView.h"

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height

extern int g_width_size;
extern int g_height_size;

@interface XDXCropView()

@property (nonatomic, assign) int               cropX;
@property (nonatomic, assign) int               cropY;
@property (nonatomic, assign) CGFloat           screenWidth;
@property (nonatomic, assign) CGFloat           screenHeight;
@property (nonatomic, assign) CGFloat           cropViewWidth;
@property (nonatomic, assign) CGFloat           cropViewHeight;

@end

@implementation XDXCropView

#pragma mark - Init
- (void)drawRect:(CGRect)rect {
    CGContextRef context =UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, [UIColor greenColor].CGColor);
    // lengths的值｛10,10｝表示先绘制10个点，再跳过10个点，如此反复,如果把lengths值改为｛10, 20, 10｝，则表示先绘制10个点，跳过20个点，绘制10个点，跳过10个点，再绘制20个点
    const CGFloat lengths[] = {10,10};
    CGContextAddRect(context, CGRectMake(0, 0, self.frame.size.width, self.frame.size.height));
    CGContextSetFillColorWithColor(context, [UIColor redColor].CGColor);
    // lengths: 虚线是如何交替绘制   count:lengths数组的长度
    CGContextSetLineDash(context, 0, lengths, 2);
    //    CGContextSetFillColorWithColor(context, [UIColor greenColor].CGColor);
    CGContextStrokePath(context);
}

- (instancetype)initWithOpen4K:(BOOL)open4K OpenGpu:(BOOL)openGpu cropWidth:(CGFloat)cropWidth cropHeight:(CGFloat)cropHeight screenResolutionW:(int)screenResolutionW screenResolutionH:(int)screenResolutionH {
    if (self = [super init]) {
        self.backgroundColor = [UIColor clearColor];
        [self judgeDeviceScale];
        [self updateVideoRect];
        self.open4K  = open4K;
        self.openGpu = openGpu;
        self.currentResolutionW = screenResolutionW;
        self.currentResolutionH = screenResolutionH;
        
    }
    return self;
}

#pragma mark - Main function
- (void)isEnableCrop:(BOOL)enableCrop session:(AVCaptureSession *)session captureLayer:(AVCaptureVideoPreviewLayer *)captureVideoPreviewLayer mainView:(UIView *)mainView {
    // Start Encoder then start camera, 配置cropView相关部分最好事先停止相机，因为涉及到分辨率改变等因素，如果项目中存在encoder, 避免回调中数据变换产生问题。
    if (session.isRunning) [session stopRunning];
    
    if (enableCrop) {
        // The device screen is not 16 : 9, So we need to reset it.
        if (self.currentDeviceScale != XDXCurrentScaleEqual) {
            if (![captureVideoPreviewLayer.videoGravity isEqual:AVLayerVideoGravityResizeAspect]) {
                captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
                NSLog(@"Crop The device is not 16:9 so we need to resize aspect!");
            }
        }
        
        if (![self isDescendantOfView:mainView]) {
            [mainView addSubview:self];
            self.descendantOfMainView = YES;
        }

        [self updateCropViewWithParamOpen4KResolution:self.isOpen4K
                                            isOpenGpu:self.isOpenGPU];
        
    }else {
        if (self.currentDeviceScale != XDXCurrentScaleEqual) {
            if (![captureVideoPreviewLayer.videoGravity isEqual:AVLayerVideoGravityResizeAspectFill]) {
                captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
                NSLog(@"Crop The device is not fill screen so we need to fill screen!");
            }
        }

        if ([self isDescendantOfView:mainView]) {
            [self removeFromSuperview];
            self.descendantOfMainView = NO;
        }
    }
    
    [session startRunning];
}

- (void)longPressedWithCurrentPoint:(CGPoint)currentPoint isOpenGpu:(BOOL)isOpenGpu {
    CGFloat currentPointX  = currentPoint.x;
    CGFloat currentPointY  = currentPoint.y;
    
    // Judge whether to exceed the boundary, 如果超出边界则进行校正
    if ((currentPointX - self.videoRect.origin.x) < _cropViewWidth / 2) {
        currentPointX = _cropViewWidth / 2 + self.videoRect.origin.x;
    }else if((currentPointX - self.videoRect.origin.x) > _screenWidth - _cropViewWidth / 2) {
        currentPointX = _screenWidth - _cropViewWidth / 2 + self.videoRect.origin.x;
    }
    
    if ((currentPointY - self.videoRect.origin.y) < _cropViewHeight / 2) {
        currentPointY = _cropViewHeight / 2 + self.videoRect.origin.y;
    }else if ((currentPointY - self.videoRect.origin.y) > _screenHeight - _cropViewHeight / 2) {
        currentPointY = self.videoRect.origin.y + _screenHeight - _cropViewHeight / 2;
    }
    
    self.center = CGPointMake(currentPointX, currentPointY);
    
    [self updateCropViewOriginOfResolutionWithOpenGpu:isOpenGpu];
}

- (void)updateCropViewWithParamOpen4KResolution:(BOOL)isOpen4KResolution isOpenGpu:(BOOL)isOpenGpu {

    _screenWidth    = self.videoRect.size.width;
    _screenHeight   = self.videoRect.size.height;
    _cropViewWidth  = _screenWidth  / self.currentResolutionW * g_width_size;
    _cropViewHeight = _screenHeight / self.currentResolutionH * g_height_size;
    
    CGFloat cropViewCenterX = (_screenWidth  - _cropViewWidth ) / 2 + self.videoRect.origin.x;
    CGFloat cropViewCenterY = (_screenHeight - _cropViewHeight) / 2 + self.videoRect.origin.y;
    self.frame = CGRectMake(cropViewCenterX, cropViewCenterY, _cropViewWidth, _cropViewHeight);
    
    [self updateCropViewOriginOfResolutionWithOpenGpu:isOpenGpu];
}

- (void)updateCropViewOriginOfResolutionWithOpenGpu:(BOOL)isOpenGpu {
    // 使用CPU/GPU 切割坐标系不同，所以需要转换，详细请看博客
    _cropX  = (int)(_currentResolutionW / _screenWidth  * (self.frame.origin.x - self.videoRect.origin.x));
    if (isOpenGpu) {
        _cropY  = (int)(_currentResolutionH / _screenHeight * (_screenHeight - (self.frame.origin.y - self.videoRect.origin.y) -  self.frame.size.height));
    }else {
        _cropY  = (int)(_currentResolutionH / _screenHeight * (self.frame.origin.y-self.videoRect.origin.y));
    }
    
    NSLog(@"Crop The Crop View's  x : %f, y : %f, width : %f, height : %f \n Crop Pix's X : %d, Y : %d, Width : %d, Height : %d",self.frame.origin.x, self.frame.origin.y, _cropViewWidth, _cropViewHeight, _cropX, _cropY, g_width_size, g_height_size);
}

- (void)judgeDeviceScale {
    CGFloat screenWidth   = kScreenWidth > kScreenHeight ? kScreenWidth  : kScreenHeight;
    CGFloat screenHeight  = kScreenWidth > kScreenHeight ? kScreenHeight : kScreenWidth;
    
    CGFloat standardScale = 16.0 / 9.0;
    CGFloat currentScale  = screenWidth / screenHeight;
    // 因为可能存在微小误差，例如iPhone 8P正好是16:9, 而iPhone 8 则有0.001以下的误差，但我们也认为它是16:9,所以这里不能完全按照16:9比较。
    CGFloat scaleError    = 0.1;
    
    if (currentScale - standardScale > scaleError) {
        self.currentDeviceScale = XDXCurrentScaleBigger;
    }else if (standardScale - currentScale > scaleError) {
        self.currentDeviceScale = XDXCurrentScaleSmaller;
    }else {
        self.currentDeviceScale = XDXCurrentScaleEqual;
    }
    
    NSLog(@"Crop The current device scale is %lu",(unsigned long)self.currentDeviceScale);
}

- (void)updateVideoRect {
    CGFloat screenWidth    = kScreenWidth > kScreenHeight ? kScreenWidth  : kScreenHeight;
    CGFloat screenHeight   = kScreenWidth > kScreenHeight ? kScreenHeight : kScreenWidth;
    CGFloat videoX         = 0;
    CGFloat videoY         = 0;
    CGFloat videoWidth     = screenWidth;
    CGFloat videoHeight    = screenHeight;
    
    switch (self.currentDeviceScale) {
        case XDXCurrentScaleEqual:
            break;
            
        case XDXCurrentScaleBigger:
            videoWidth   = screenHeight * 16 / 9;
            videoX       = (screenWidth - videoWidth) / 2;
            break;
            
        case XDXCurrentScaleSmaller:
            videoHeight  = screenWidth * 9 / 16;
            videoY       = (screenHeight - videoHeight) / 2;
            break;
            
        default:
            break;
    }
    
    self.videoRect = CGRectMake(videoX, videoY, videoWidth, videoHeight);
    NSLog(@"Crop The video rect is : %f - %f - %f - %f",self.videoRect.origin.x,self.videoRect.origin.y,self.videoRect.size.width,self.videoRect.size.height);
}

#pragma mark - Crop by CPU / GPU
// software crop
- (CMSampleBufferRef)cropSampleBufferBySoftware:(CMSampleBufferRef)sampleBuffer {
    OSStatus status;
    
    //    CVPixelBufferRef pixelBuffer = [self modifyImage:buffer];
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the image buffer
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    // Get information about the image
    uint8_t *baseAddress     = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t  bytesPerRow      = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t  width            = CVPixelBufferGetWidth(imageBuffer);
    // size_t  height           = CVPixelBufferGetHeight(imageBuffer);
    NSInteger bytesPerPixel  =  bytesPerRow/width;
    
    // YUV 420 Rule
    if (_cropX % 2 != 0) _cropX += 1;
    NSInteger baseAddressStart = _cropY*bytesPerRow+bytesPerPixel*_cropX;
    static NSInteger lastAddressStart = 0;
    lastAddressStart = baseAddressStart;
    
    // pixbuffer 与 videoInfo 只有位置变换或者切换分辨率或者相机重启时需要更新，其余情况不需要，Demo里只写了位置更新，其余情况自行添加
    // NSLog(@"demon pix first : %zu - %zu - %@ - %d - %d - %d -%d",width, height, self.currentResolution,_cropX,_cropY,self.currentResolutionW,self.currentResolutionH);
    static CVPixelBufferRef            pixbuffer = NULL;
    static CMVideoFormatDescriptionRef videoInfo = NULL;
    
    // x,y changed need to reset pixbuffer and videoinfo
    if (lastAddressStart != baseAddressStart) {
        if (pixbuffer != NULL) {
            CVPixelBufferRelease(pixbuffer);
            pixbuffer = NULL;
        }
        
        if (videoInfo != NULL) {
            CFRelease(videoInfo);
            videoInfo = NULL;
        }
    }
    
    if (pixbuffer == NULL) {
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithBool : YES],           kCVPixelBufferCGImageCompatibilityKey,
                                 [NSNumber numberWithBool : YES],           kCVPixelBufferCGBitmapContextCompatibilityKey,
                                 [NSNumber numberWithInt  : g_width_size],  kCVPixelBufferWidthKey,
                                 [NSNumber numberWithInt  : g_height_size], kCVPixelBufferHeightKey,
                                 nil];
        
        status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault, g_width_size, g_height_size, kCVPixelFormatType_32BGRA, &baseAddress[baseAddressStart], bytesPerRow, NULL, NULL, (__bridge CFDictionaryRef)options, &pixbuffer);
        if (status != 0) {
            NSLog(@"Crop CVPixelBufferCreateWithBytes error %d",(int)status);
            return NULL;
        }
    }
    
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    CMSampleTimingInfo sampleTime = {
        .duration               = CMSampleBufferGetDuration(sampleBuffer),
        .presentationTimeStamp  = CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
        .decodeTimeStamp        = CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
    };
    
    if (videoInfo == NULL) {
        status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixbuffer, &videoInfo);
        if (status != 0) NSLog(@"Crop CMVideoFormatDescriptionCreateForImageBuffer error %d",(int)status);
    }
    
    CMSampleBufferRef cropBuffer = NULL;
    status = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixbuffer, true, NULL, NULL, videoInfo, &sampleTime, &cropBuffer);
    if (status != 0) NSLog(@"Crop CMSampleBufferCreateForImageBuffer error %d",(int)status);
    
    lastAddressStart = baseAddressStart;
    
    return cropBuffer;
}

// hardware crop
- (CMSampleBufferRef)cropSampleBufferByHardware:(CMSampleBufferRef)buffer {
    // a CMSampleBuffer's CVImageBuffer of media data.
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(buffer);
    CGRect           cropRect    = CGRectMake(_cropX, _cropY, g_width_size, g_height_size);
    //        log4cplus_debug("Crop", "dropRect x: %f - y : %f - width : %zu - height : %zu", cropViewX, cropViewY, width, height);
    
    /*
     First, to render to a texture, you need an image that is compatible with the OpenGL texture cache. Images that were created with the camera API are already compatible and you can immediately map them for inputs. Suppose you want to create an image to render on and later read out for some other processing though. You have to have create the image with a special property. The attributes for the image must have kCVPixelBufferIOSurfacePropertiesKey as one of the keys to the dictionary.
      如果要进行页面渲染，需要一个和OpenGL缓冲兼容的图像。用相机API创建的图像已经兼容，您可以马上映射他们进行输入。假设你从已有画面中截取一个新的画面，用作其他处理，你必须创建一种特殊的属性用来创建图像。对于图像的属性必须有kCVPixelBufferIOSurfacePropertiesKey 作为字典的Key.因此以下步骤不可省略
     */
    
    OSStatus status;
    
    /* Only resolution has changed we need to reset pixBuffer and videoInfo so that reduce calculate count */
    static CVPixelBufferRef            pixbuffer = NULL;
    static CMVideoFormatDescriptionRef videoInfo = NULL;
    
    if (pixbuffer == NULL) {
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithInt:g_width_size],     kCVPixelBufferWidthKey,
                                 [NSNumber numberWithInt:g_height_size],    kCVPixelBufferHeightKey, nil];
        status = CVPixelBufferCreate(kCFAllocatorSystemDefault, g_width_size, g_height_size, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, (__bridge CFDictionaryRef)options, &pixbuffer);
        // ensures that the CVPixelBuffer is accessible in system memory. This should only be called if the base address is going to be used and the pixel data will be accessed by the CPU
        if (status != noErr) {
            NSLog(@"Crop CVPixelBufferCreate error %d",(int)status);
            return NULL;
        }
    }
    
    CIImage *ciImage = [CIImage imageWithCVImageBuffer:imageBuffer];
    ciImage = [ciImage imageByCroppingToRect:cropRect];
    // Ciimage get real image is not in the original point  after excute crop. So we need to pan.
    ciImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeTranslation(-_cropX, -_cropY)];
    
    static CIContext *ciContext = nil;
    if (ciContext == nil) {
        //        NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
        //        [options setObject:[NSNull null] forKey:kCIContextWorkingColorSpace];
        //        [options setObject:@0            forKey:kCIContextUseSoftwareRenderer];
        EAGLContext *eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
        ciContext = [CIContext contextWithEAGLContext:eaglContext options:nil];
    }
    [ciContext render:ciImage toCVPixelBuffer:pixbuffer];
    //    [ciContext render:ciImage toCVPixelBuffer:pixbuffer bounds:cropRect colorSpace:nil];
    
    CMSampleTimingInfo sampleTime = {
        .duration               = CMSampleBufferGetDuration(buffer),
        .presentationTimeStamp  = CMSampleBufferGetPresentationTimeStamp(buffer),
        .decodeTimeStamp        = CMSampleBufferGetDecodeTimeStamp(buffer)
    };
    
    if (videoInfo == NULL) {
        status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixbuffer, &videoInfo);
        if (status != 0) NSLog(@"Crop CMVideoFormatDescriptionCreateForImageBuffer error %d",(int)status);
    }
    
    CMSampleBufferRef cropBuffer;
    status = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixbuffer, true, NULL, NULL, videoInfo, &sampleTime, &cropBuffer);
    if (status != 0) NSLog(@"Crop CMSampleBufferCreateForImageBuffer error %d",(int)status);
    
    return cropBuffer;
}

@end
