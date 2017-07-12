## iOS开发中截取相机部分画面，切割sampleBuffer（Crop sample buffer）


### 本例需求：在类似直播的功能界面或其他需求中需要从相机捕获的画面中单独截取出一部分区域。
### 原理：由于需要截取相机捕获整个画面其中一部分，所以也就必须拿到那一部分画面的数据，又因为相机AVCaptureVideoDataOutputSampleBufferDelegate中的sampleBuffer为系统私有的数据结构不可直接操作，所以需要将其转换成可以切割的数据结构再进行切割，网上有种思路说将sampleBuffer间接转换为UIImage再对图片切割，这种思路繁琐且性能低，本例将sampleBuffer转换为CoreImage中的CIImage,性能相对较高且降低代码繁琐度。

### 最终效果如下， 绿色框中即为截图的画面，长按可以移动。
![](https://d26dzxoao6i3hh.cloudfront.net/items/382V1S1q1B370V3t0G2L/C35987EE9EA0C8E00004B4848ACB9213.jpg)

### 源代码地址:[Crop sample buffer](https://github.com/ChengyangLi/Crop-sample-buffer)
### 博客地址:[Crop sample buffer](https://chengyangli.github.io/2017/07/12/cropSampleBuffer/)
### 简书地址:[Crop sample buffer](http://www.jianshu.com/p/ac79a80f1af2)

## 基本配置
1.配置相机基本环境(初始化AVCaptureSession，设置代理，开启)，在示例代码中有，这里不再重复。

2.通过AVCaptureVideoDataOutputSampleBufferDelegate代理中拿到原始画面数据(CMSampleBufferRef)进行处理

### 解析

```  
// AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
CGRect cropRect                     = CGRectMake(self.cropView.frame.origin.x, self.cropView.frame.origin.y, g_width_size, g_height_size);
CMSampleBufferRef cropSampleBuffer  = [self cropSampleBuffer:sampleBuffer withCropRect:cropRect];
// note : don't forget to release cropSampleBuffer so that avoid memory error !!!  一定要对cropSampleBuffer进行release避免内存泄露过多而发生闪退
CFRelease(cropSampleBuffer);
}

```
- 以上方法为每产生一帧视频帧时调用一次的相机代理，其中sampleBuffer为每帧画面的原始数据，需要对原始数据进行切割处理方可达到本例需求。注意最后一定要对cropSampleBuffer进行release避免内存泄露过多而发生闪退。

```
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

```
- 以上方法为切割sampleBuffer的对象方法，首先从CMSampleBufferRef中提取出CVImageBufferRef数据结构，然后对CVImageBufferRef进行加锁处理，如果要进行页面渲染，需要一个和OpenGL缓冲兼容的图像。用相机API创建的图像已经兼容，您可以马上映射他们进行输入。假设你从已有画面中截取一个新的画面，用作其他处理，你必须创建一种特殊的属性用来创建图像。对于图像的属性必须有kCVPixelBufferIOSurfacePropertiesKey 作为字典的Key.因此创建字典的关键几步不可省略。
- 此方法简单便捷，仅需传入CMSampleBufferRef的对象最后也会返回CMSampleBufferRef的对象。具体解释在代码中均有注释。


