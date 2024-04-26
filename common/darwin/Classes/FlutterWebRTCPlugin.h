#if TARGET_OS_IPHONE
#import <Flutter/Flutter.h>
#elif TARGET_OS_OSX
#import <FlutterMacOS/FlutterMacOS.h>
#endif

#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>

@class FlutterRTCVideoRenderer;
@class FlutterRTCFrameCapturer;

void postEvent(FlutterEventSink _Nonnull sink, id _Nullable event);

typedef void (^CompletionHandler)(void);

typedef void (^CapturerStopHandler)(CompletionHandler _Nonnull handler);

@interface FlutterWebRTCPlugin : NSObject <FlutterPlugin,
                                           RTCPeerConnectionDelegate,
                                           FlutterStreamHandler
#if TARGET_OS_OSX
                                           ,
                                           RTCDesktopMediaListDelegate,
                                           RTCDesktopCapturerDelegate
#endif
                                           >

@property(nonatomic, strong) RTCPeerConnectionFactory* _Nullable peerConnectionFactory;
@property(nonatomic, strong) NSMutableDictionary<NSString*, RTCPeerConnection*>* _Nullable peerConnections;
@property(nonatomic, strong) NSMutableDictionary<NSString*, RTCMediaStream*>* _Nullable localStreams;
@property(nonatomic, strong) NSMutableDictionary<NSString*, RTCMediaStreamTrack*>* _Nullable localTracks;
@property(nonatomic, strong) NSMutableDictionary<NSNumber*, FlutterRTCVideoRenderer*>* _Nullable renders;
@property(nonatomic, strong)
    NSMutableDictionary<NSString*, CapturerStopHandler>* _Nullable videoCapturerStopHandlers;

@property(nonatomic, strong) NSMutableDictionary<NSString*, RTCFrameCryptor*>* _Nullable frameCryptors;
@property(nonatomic, strong) NSMutableDictionary<NSString*, RTCFrameCryptorKeyProvider*>* _Nullable keyProviders;

#if TARGET_OS_IPHONE
@property(nonatomic, retain) UIViewController* viewController; /*for broadcast or ReplayKit */
#endif

@property(nonatomic, strong) FlutterEventSink _Nullable eventSink;
@property(nonatomic, strong) NSObject<FlutterBinaryMessenger>* _Nonnull messenger;
@property(nonatomic, strong) RTCCameraVideoCapturer* _Nullable videoCapturer;
@property(nonatomic, strong) FlutterRTCFrameCapturer* _Nullable frameCapturer;
@property(nonatomic, strong) AVAudioSessionPort _Nullable preferredInput;
@property(nonatomic) BOOL _usingFrontCamera;
@property(nonatomic) NSInteger _lastTargetWidth;
@property(nonatomic) NSInteger _lastTargetHeight;
@property(nonatomic) NSInteger _lastTargetFps;

@property (nonatomic, strong, nullable) CIImage *backgroundImage;

- (RTCMediaStream*)streamForId:(NSString*)streamId peerConnectionId:(NSString*)peerConnectionId;
- (RTCRtpTransceiver*)getRtpTransceiverById:(RTCPeerConnection*)peerConnection Id:(NSString*)Id;
- (NSDictionary*)mediaStreamToMap:(RTCMediaStream*)stream ownerTag:(NSString*)ownerTag;
- (NSDictionary*)mediaTrackToMap:(RTCMediaStreamTrack*)track;
- (NSDictionary*)receiverToMap:(RTCRtpReceiver*)receiver;
- (NSDictionary*)transceiverToMap:(RTCRtpTransceiver*)transceiver;

- (BOOL)hasLocalAudioTrack;
- (void)ensureAudioSession;
- (void)deactiveRtcAudioSession;

+ (FlutterWebRTCPlugin *)sharedSingleton;
+ (NSString *)sharedPeerConnectionId;
- (RTCRtpReceiver*)getRtpReceiverById:(RTCPeerConnection*)peerConnection Id:(NSString*)Id;
- (RTCRtpSender*)getRtpSenderById:(RTCPeerConnection*)peerConnection Id:(NSString*)Id;

@end
