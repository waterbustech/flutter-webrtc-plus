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
  void ConvertYUV420ToRGBA(const uint8_t* y_plane, const uint8_t* u_plane, const uint8_t* v_plane,
    int y_stride, int u_stride, int v_stride,
    int width, int height, uint8_t* rgba_output);
  void ConvertRGBAToYUV420(const uint8_t* rgba_input, int width, int height,
      uint8_t* y_plane, uint8_t* u_plane, uint8_t* v_plane,
      int y_stride, int u_stride, int v_stride);
};

}  // namespace flutter_webrtc_plus_plugin

#endif