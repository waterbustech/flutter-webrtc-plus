//
//  RTCBeautyFilter.h
//  flutter_webrtc
//
//  Created by lambiengcode on 19/03/2024.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

@protocol RTCBeautyFilterDelegate <NSObject>
- (void)didReceivePixelBuffer:(CVPixelBufferRef)pixelBuffer
                        width:(int)width
                       height:(int)height
                     timestamp:(int64_t)timestamp;
@end

@interface RTCBeautyFilter : NSObject

@property (nonatomic, weak) id<RTCBeautyFilterDelegate> delegate;
@property (nonatomic, assign) CGFloat beautyValue;
@property (nonatomic, assign) CGFloat whithValue;
@property (nonatomic, assign) CGFloat saturationValue;
@property (nonatomic, assign) CGFloat thinFaceValue;
@property (nonatomic, assign) CGFloat eyeValue;
@property (nonatomic, assign) CGFloat lipstickValue;
@property (nonatomic, assign) CGFloat blusherValue;

- (instancetype)initWithDelegate:(id<RTCBeautyFilterDelegate>)delegate;
- (void)releaseInstance;
- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer;

@end
