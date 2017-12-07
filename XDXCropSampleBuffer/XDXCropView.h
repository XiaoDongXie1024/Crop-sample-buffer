//
//  XDXCropView.h
//  XDXCropSampleBuffer
//
//  Created by demon on 12/07/2017.
//  Copyright © 2017 demon. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>


/**
 区分当前设备屏幕比例
 - XDXCurrentScaleEqual:   当前屏幕比支持 16 : 9
 - XDXCurrentScaleBigger:  当前屏幕比大于 16 : 9
 - XDXCurrentScaleSmaller: 当前屏幕比小于 16 : 9
 */
typedef NS_ENUM(NSUInteger, XDXCurrentDeviceScale) {
    XDXCurrentScaleEqual,
    XDXCurrentScaleBigger,
    XDXCurrentScaleSmaller,
};

@interface XDXCropView : UIView

/**
 Two Condition: (Only backgroud resolution is 2k )
 1. when the device size is 16 : 9, the size is kScreenWidth,kScreenHeight
 2. when the device size is not 16 : 9, the origin.y and size.height need to change.
 */
@property (nonatomic, assign) CGRect                             videoRect;
@property (nonatomic, assign) XDXCurrentDeviceScale              currentDeviceScale;
@property (nonatomic, assign) int                                currentResolutionW;
@property (nonatomic, assign) int                                currentResolutionH;

@property (nonatomic, assign, getter=isDescendantOfMainView)BOOL descendantOfMainView;
@property (nonatomic, assign, getter=isOpen4K)              BOOL open4K;
@property (nonatomic, assign, getter=isOpenGPU)             BOOL openGpu;


/**
    使用CPU / GPU 进行切割
 */
- (CMSampleBufferRef)cropSampleBufferBySoftware:(CMSampleBufferRef)sampleBuffer;
- (CMSampleBufferRef)cropSampleBufferByHardware:(CMSampleBufferRef)buffer;


/**
 打开或关闭Crop功能

 @param enableCrop 打开或关闭选项
 @param session    视频session
 @param captureVideoPreviewLayer 视频preview层
 @param mainView   主控制器的view
 */
- (void)isEnableCrop:(BOOL)enableCrop session:(AVCaptureSession *)session captureLayer:(AVCaptureVideoPreviewLayer *)captureVideoPreviewLayer mainView:(UIView *)mainView;


/**
 初始化CropView的全能初始化方法

 @param open4K 是否打开4K
 @param openGpu 是否使用GPU，否则使用CPU
 @param cropWidth cropView的宽度
 @param cropHeight cropView的高度
 @param screenResolutionW 当前屏幕分辨率的宽
 @param screenResolutionH 当前屏幕分辨率的高
 */
- (instancetype)initWithOpen4K:(BOOL)open4K OpenGpu:(BOOL)openGpu cropWidth:(CGFloat)cropWidth cropHeight:(CGFloat)cropHeight screenResolutionW:(int)screenResolutionW screenResolutionH:(int)screenResolutionH;


/**
 长按屏幕触发的操作，即移动cropView的位置
 */
- (void)longPressedWithCurrentPoint:(CGPoint)currentPoint isOpenGpu:(BOOL)isOpenGpu ;

@end
