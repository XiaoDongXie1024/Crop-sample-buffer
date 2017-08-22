## iOS开发中截取相机部分画面，切割sampleBuffer（Crop sample buffer）


### 本例需求：在类似直播的功能界面,二维码扫描，人脸识别或其他需求中的功能界面或其他需求中需要从相机捕获的画面中单独截取出一部分区域。
### 原理：由于需要截取相机捕获整个画面其中一部分，所以也就必须拿到那一部分画面的数据，又因为相机AVCaptureVideoDataOutputSampleBufferDelegate中的sampleBuffer为系统私有的数据结构不可直接操作，所以需要将其转换成可以切割的数据结构再进行切割，网上有种思路说将sampleBuffer间接转换为UIImage再对图片切割，这种思路繁琐且性能低，本例将sampleBuffer转换为CoreImage中的CIImage,性能相对较高且降低代码繁琐度。

### 最终效果如下， 绿色框中即为截图的画面，长按可以移动。
![C4B33930D868D682D1424D346D5B596B.jpg](http://upload-images.jianshu.io/upload_images/5086522-544d651b2a8871c0.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

### 源代码地址:[Crop sample buffer](https://github.com/ChengyangLi/Crop-sample-buffer)
### 博客地址:[Crop sample buffer](https://chengyangli.github.io/2017/07/12/cropSampleBuffer/)
### 简书地址:[Crop sample buffer](http://www.jianshu.com/p/ac79a80f1af2)

## 注意：使用ARC与MRC下代码有所区别，已经在项目中标注好，主要为管理全局的CIContext对象，它在初始化的方法中编译器没有对其进行retain,所以，调用会报错。
![cicontextError](http://upload-images.jianshu.io/upload_images/5086522-5f510e448af32d4d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

## 基本配置
1.配置相机基本环境(初始化AVCaptureSession，设置代理，开启)，在示例代码中有，这里不再重复。

2.通过AVCaptureVideoDataOutputSampleBufferDelegate代理中拿到原始画面数据(CMSampleBufferRef)进行处理

## 实现途径
### 1.利用CPU软件截取(CPU进行计算并切割，消耗性能较大)
- (CMSampleBufferRef)cropSampleBufferBySoftware:(CMSampleBufferRef)sampleBuffer；


### 2.利用 硬件截取(利用Apple官方公开的方法利用硬件进行切割，性能较好)
- (CMSampleBufferRef)cropSampleBufferByHardware:(CMSampleBufferRef)buffer；
- 
### 解析
```  
// AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {

	// 以下两种方法任选一种即可
	// 1.利用CPU截取
	cropSampleBuffer = [self cropSampleBufferBySoftware:sampleBuffer];
	// 2.利用GPU截取
	cropSampleBuffer = [self cropSampleBufferByHardware:sampleBuffer];
	
    // note : don't forget to release cropSampleBuffer so that avoid memory error !!!  一定要对cropSampleBuffer进行release避免内存泄露过多而发生闪退
    CFRelease(cropSampleBuffer);
}

```
- 以上方法为每产生一帧视频帧时调用一次的相机代理，其中sampleBuffer为每帧画面的原始数据，需要对原始数据进行切割处理方可达到本例需求。注意最后一定要对cropSampleBuffer进行release避免内存溢出而发生闪退。


## 利用CPU截取

```
- (CMSampleBufferRef)cropSampleBufferBySoftware:(CMSampleBufferRef)sampleBuffer {
    OSStatus status;
    // Get a CMSampleBuffer's Core Video image buffer for the media data
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
    // 网上关于一下字典的写法很多，亲测如果不按以下写法画面有问题。
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             [NSNumber numberWithInt:g_width_size], kCVPixelBufferWidthKey,
                             [NSNumber numberWithInt:g_height_size], kCVPixelBufferHeightKey,
                             nil];

    int cropX = (int)(currentResolutionW / kScreenWidth   *  self.cropView.frame.origin.x);
    int cropY = (int)(currentResolutionH / kScreenHeight  *  self.cropView.frame.origin.y);
    
    // 根据YUV原理，解析中有介绍，总之就是x必须为偶数，否则渲染会失败
    if (cropX % 2 != 0) cropX += 1;
    // 通过此行代码确认开始位置，通过计算每行有多少byte可以得到Y的位置，通过计算bytesPerPixel可以得到X的位置
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


```
- 以上方法为切割sampleBuffer的对象方法，首先从CMSampleBufferRef中提取出CVImageBufferRef数据结构，然后对CVImageBufferRef进行加锁处理，如果要进行页面渲染，需要一个和OpenGL缓冲兼容的图像。用相机API创建的图像已经兼容，您可以马上映射他们进行输入。假设你从已有画面中截取一个新的画面，用作其他处理，你必须创建一种特殊的属性用来创建图像。对于图像的属性必须有kCVPixelBufferIOSurfacePropertiesKey 作为字典的Key.因此创建字典的关键几步不可省略。
- 利用CPU切割中使用的方法为YUV分隔法，具体切割方式请参考[YUV介绍](http://www.jianshu.com/p/a91502c00fb0)
注意：
- 1.对X,Y坐标进行校正，因为CVPixelBufferCreateWithBytes是按照像素进行切割，所以需要将点转成像素，再按照比例算出当前位置。即为上述代码的int cropX = (int)(currentResolutionW / kScreenWidth   *  self.cropView.frame.origin.x); currentResolutionW为当前分辨率的宽度，kScreenWidth为屏幕实际宽度。

```
// hardware crop
- (CMSampleBufferRef)cropSampleBufferByHardware:(CMSampleBufferRef)buffer {
    // a CMSampleBuffer's CVImageBuffer of media data.
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(buffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t width  = CVPixelBufferGetWidth(imageBuffer);
    // log4cplus_debug("AVCaptureVideoDataOutputSampleBufferDelegate", "CMSampleBufferRef origin pix width: %zu - height : %zu",width, height);
    
    CGFloat cropViewX  = currentResolutionW / kScreenWidth  * self.cropView.frame.origin.x;
    // CIImage base point is locate left-bottom so need to convert
    CGFloat cropViewY  = currentResolutionH / kScreenHeight * (kScreenHeight - self.cropView.frame.origin.y -  self.cropView.frame.size.height);
    
    CGRect cropRect = CGRectMake(cropViewX, cropViewY, g_width_size, g_height_size);
    // log4cplus_debug("AVCaptureVideoDataOutputSampleBufferDelegate", "dropRect x: %f - y : %f - width : %zu - height : %zu", cropViewX, cropViewY, width, height);

    
    /*
     First, to render to a texture, you need an image that is compatible with the OpenGL texture cache. Images that were created with the camera API are already compatible and you can immediately map them for inputs. Suppose you want to create an image to render on and later read out for some other processing though. You have to have create the image with a special property. The attributes for the image must have kCVPixelBufferIOSurfacePropertiesKey as one of the keys to the dictionary.
        如果要进行页面渲染，需要一个和OpenGL缓冲兼容的图像。用相机API创建的图像已经兼容，您可以马上映射他们进行输入。假设你从已有画面中截取一个新的画面，用作其他处理，你必须创建一种特殊的属性用来创建图像。对于图像的属性必须有kCVPixelBufferIOSurfacePropertiesKey 作为字典的Key.因此以下步骤不可省略
     
     */
    OSStatus status;
    CVPixelBufferRef pixelBuffer;
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             //                             [NSNumber numberWithBool:YES],             kCVPixelBufferOpenGLCompatibilityKey,
                             //                             [NSNumber numberWithBool:YES],             kCVPixelBufferOpenGLESCompatibilityKey,
                             //                             [NSNumber numberWithBool:YES],             kCVPixelBufferCGImageCompatibilityKey,
                             //                             [NSNumber numberWithBool:YES],             kCVPixelBufferCGBitmapContextCompatibilityKey,
                             [NSNumber numberWithInt:g_width_size],     kCVPixelBufferWidthKey,
                             [NSNumber numberWithInt:g_height_size],    kCVPixelBufferHeightKey,
                             
                             nil];
    status = CVPixelBufferCreate(kCFAllocatorSystemDefault, g_width_size, g_height_size, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, (__bridge CFDictionaryRef)options, &pixelBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];
    //    ciImage          = [ciImage imageByCroppingToRect:cropRect];
    
    
    if (_ciContext == nil) {
        EAGLContext *eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        _ciContext = [CIContext contextWithEAGLContext:eaglContext options:@{kCIContextWorkingColorSpace : [NSNull null]}];
#warning if project is MRC, Must to do it,如果是MRC代码必须手动retain ciContext对象，因为初始化中并没有retain它，不然渲染将报错找不到ciContext对象的内存地址。
        // [eaglContext release];
        // [ciContext retain];
    }
    
    // In OS X 10.11.3 and iOS 9.3 and later
    //    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    //    [ciContext render:ciImage toCVPixelBuffer:pixelBuffer];
    // 两种渲染方式，博客里有介绍，亲测这种方案较好
    [_ciContext render:ciImage toCVPixelBuffer:pixelBuffer bounds:cropRect colorSpace:nil];
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CMSampleTimingInfo sampleTime = {
        .duration               = CMSampleBufferGetDuration(buffer),
        .presentationTimeStamp  = CMSampleBufferGetPresentationTimeStamp(buffer),
        .decodeTimeStamp        = CMSampleBufferGetDecodeTimeStamp(buffer)
    };
    
    CMVideoFormatDescriptionRef videoInfo = NULL;
    status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &videoInfo);
    if (status != 0){
//        log4cplus_debug("AVCaptureVideoDataOutputSampleBufferDelegate", "CMVideoFormatDescriptionCreateForImageBuffer error %d",(int)status);
    }
    
    CMSampleBufferRef cropBuffer;
    status = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, videoInfo, &sampleTime, &cropBuffer);
    if (status != 0) {
//        log4cplus_debug("AVCaptureVideoDataOutputSampleBufferDelegate", "CMSampleBufferCreateForImageBuffer error %d",(int)status);
    }
    
    CFRelease(videoInfo);
    CFRelease(pixelBuffer);
    
    return cropBuffer;

}

```
- 以上为硬件切割的方法，硬件切割利用GPU进行切割
- CoreImage and UIKit coordinates （CoreImage 与 UIKit坐标系问题）：我在开始做的时候跟正常一样用设定的位置对图像进行切割，但是发现，切出来的位置不对，通过上网查阅发现一个有趣的现象CoreImage 与 UIKit坐标系不相同
如下图：
正常UIKit坐标系是以左上角为原点：

![](https://cl.ly/0O070Z391Y3m/Snip20170802_2.png)

而CoreImage坐标系是以左下角为原点：（在CoreImage中，每个图像的坐标系是独立于设备的）

![](https://cl.ly/1B3X230y0l1m/Snip20170802_1.png)

所以切割的时候一定要注意转换Y，X的位置是正确的，Y是相反的。

- 如果要进行页面渲染，需要一个和OpenGL缓冲兼容的图像。用相机API创建的图像已经兼容，您可以马上映射他们进行输入。假设你从已有画面中截取一个新的画面，用作其他处理，你必须创建一种特殊的属性用来创建图像。对于图像的属性必须有kCVPixelBufferIOSurfacePropertiesKey 作为字典的Key.因此创建字典的关键几步不可省略。
- 对CoreImage进行切割有两种切割的方法均可用：
 1. ```ciImage = [ciImage imageByCroppingToRect:cropRect];``` 如果使用此行代码则渲染时用``` [ciContext render:ciImage toCVPixelBuffer:pixelBuffer]; ```
 2. 或者直接使用： ```  [ciContext render:ciImage toCVPixelBuffer:pixelBuffer bounds:cropRect colorSpace:rgbColorSpace]; ``` 
- 注意：CIContext 中包含图像大量上下文信息，不能在回调中多次调用，官方建议只初始化一次。但是注意ARC,MRC区别。


