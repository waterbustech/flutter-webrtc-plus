#import <Foundation/Foundation.h>
#import "FlutterWebRTCPlugin.h"

@interface RTCMediaStreamTrack (Flutter)
@property(nonatomic, strong, nonnull) id settings;
@end

@interface FlutterWebRTCPlugin (RTCMediaStream)

- (void)getUserMedia:(nonnull NSDictionary*)constraints result:(nonnull FlutterResult)result;

- (void)createLocalMediaStream:(nonnull FlutterResult)result;

- (void)getSources:(nonnull FlutterResult)result;

- (void)mediaStreamTrackCaptureFrame:(nonnull RTCMediaStreamTrack*)track
                              toPath:(nonnull NSString*)path
                              result:(nonnull FlutterResult)result;

- (void)selectAudioInput:(nonnull NSString*)deviceId result:(nullable FlutterResult)result;

- (void)selectAudioOutput:(nonnull NSString*)deviceId result:(nullable FlutterResult)result;


- (void)setBackgroundImage:(CIImage *_Nullable)backgroundImage;

- (void)setThinValue:(CGFloat)value;
- (void)setSmoothValue:(CGFloat)value;
- (void)setWhiteValue:(CGFloat)value;
- (void)setLipstickValue:(CGFloat)value;
- (void)setBigEyeValue:(CGFloat)value;
- (void)setBlusherValue:(CGFloat)value;

@end
