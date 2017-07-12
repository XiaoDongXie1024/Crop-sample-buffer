//
//  XDXCropView.m
//  XDXCropSampleBuffer
//
//  Created by demon on 12/07/2017.
//  Copyright © 2017 demon. All rights reserved.
//

#import "XDXCropView.h"

@implementation XDXCropView

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

@end
