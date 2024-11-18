#ifndef FLUTTER_WEBRTC_RTC_GET_USERMEDIA_HXX
#define FLUTTER_WEBRTC_RTC_GET_USERMEDIA_HXX

#include "flutter_common.h"
#include "flutter_webrtc_base.h"

#if !defined(_WIN32)
#include "flutter_virtual_background.h" 
#endif

namespace flutter_webrtc_plus_plugin {

class FlutterMediaStream {
 public:
  FlutterMediaStream(FlutterWebRTCBase* base);

  void GetUserMedia(const EncodableMap& constraints,
                    std::unique_ptr<MethodResultProxy> result);

  void GetUserAudio(const EncodableMap& constraints,
                    scoped_refptr<RTCMediaStream> stream,
                    EncodableMap& params);

  void GetUserVideo(const EncodableMap& constraints,
                    scoped_refptr<RTCMediaStream> stream,
                    EncodableMap& params);

  void GetSources(std::unique_ptr<MethodResultProxy> result);

  void SelectAudioOutput(const std::string& device_id,
                         std::unique_ptr<MethodResultProxy> result);

  void SelectAudioInput(const std::string& device_id,
                        std::unique_ptr<MethodResultProxy> result);

  void MediaStreamGetTracks(const std::string& stream_id,
                            std::unique_ptr<MethodResultProxy> result);

  void MediaStreamDispose(const std::string& stream_id,
                          std::unique_ptr<MethodResultProxy> result);

  void MediaStreamTrackSetEnable(const std::string& track_id,
                                 std::unique_ptr<MethodResultProxy> result);

  void MediaStreamTrackSwitchCamera(const std::string& track_id,
                                    std::unique_ptr<MethodResultProxy> result);

  void MediaStreamTrackDispose(const std::string& track_id,
                               std::unique_ptr<MethodResultProxy> result);

  void CreateLocalMediaStream(std::unique_ptr<MethodResultProxy> result);

  void OnDeviceChange();

  #if !defined(_WIN32)

  // MARK: GPUPixel Adjusting face value
  void SetThinFaceValue(const double value);

  void SetWhiteValue(const double value);

  void SetBigEyeValue(const double value);

  void SetSmoothValue(const double value);

  void SetLipstickValue(const double value);

  void SetBlusherValue(const double value);

  #endif

 private:
  FlutterWebRTCBase* base_;

  #if !defined(_WIN32)
  std::shared_ptr<FlutterVirtualBackground> virtualBackgroundProcessor_;
  #endif
};

}  // namespace flutter_webrtc_plus_plugin

#endif  // !FLUTTER_WEBRTC_RTC_GET_USERMEDIA_HXX
