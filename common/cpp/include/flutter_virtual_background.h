#ifndef FLUTTER_WEBRTC_VIRTUAL_BACKGROUND_HXX
#define FLUTTER_WEBRTC_VIRTUAL_BACKGROUND_HXX

#include "flutter_common.h"
#include "flutter_webrtc_base.h"

#include "rtc_video_frame.h"
#include "rtc_video_renderer.h"

#include <mutex>


namespace flutter_webrtc_plus_plugin {

using namespace libwebrtc;

class FlutterVirtualBackground : public RTCVideoRenderer<scoped_refptr<RTCVideoFrame>> {
 public:
  explicit FlutterVirtualBackground(RTCVideoTrack* track);

  virtual void OnFrame(scoped_refptr<RTCVideoFrame> frame) override;

  void SetThinFaceValue(const double value);
  
  void SetWhiteValue(const double value);
  
  void SetBigEyeValue(const double value);
  
  void SetSmoothValue(const double value);
  
  void SetLipstickValue(const double value);
  
  void SetBlusherValue(const double value);

 private:
  RTCVideoTrack* track_;

  void InitGPUPixel();
};

}  // namespace flutter_webrtc_plus_plugin

#endif