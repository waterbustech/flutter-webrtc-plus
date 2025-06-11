//
//  RTCBeautyFilter.h
//  flutter_webrtc
//
//  Created by lambiengcode on 19/03/2024.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

@interface RTCBeautyFilter : NSObject

@property (nonatomic, assign) CGFloat beautyValue;
@property (nonatomic, assign) CGFloat whithValue;
@property (nonatomic, assign) CGFloat saturationValue;
@property (nonatomic, assign) CGFloat thinFaceValue;
@property (nonatomic, assign) CGFloat eyeValue;
@property (nonatomic, assign) CGFloat lipstickValue;
@property (nonatomic, assign) CGFloat blusherValue;

- (instancetype)init;
- (void)releaseInstance;
- (CVPixelBufferRef)processVideoFrame:(CVPixelBufferRef)imageBuffer;

@end
