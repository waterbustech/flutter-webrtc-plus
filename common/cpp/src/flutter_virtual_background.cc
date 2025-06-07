#include "flutter_virtual_background.h"
#include <cstring>
#include <iostream>

#if defined(_WIN32)
// #include "gpupixel/gpupixel.h"
#else
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include "gpupixel.h"

using namespace gpupixel;
#endif

#if !defined(_WIN32)
std::shared_ptr<SourceRawDataInput> gpuPixelRawInput;
std::shared_ptr<BeautyFaceFilter> beauty_face_filter_;
std::shared_ptr<FaceReshapeFilter> face_reshape_filter_;
std::shared_ptr<gpupixel::LipstickFilter> lipstick_filter_;
std::shared_ptr<gpupixel::BlusherFilter> blusher_filter_;
std::shared_ptr<TargetRawDataOutput> targetRawOutput_;
#endif

namespace flutter_webrtc_plus_plugin {

FlutterVirtualBackground::FlutterVirtualBackground(RTCVideoTrack* track)
    : track_(track) {
  if (track == nullptr) {
    std::cerr
        << "Error: Received null track in FlutterVirtualBackground constructor."
        << std::endl;
    throw std::invalid_argument(
        "Received null track in FlutterVirtualBackground constructor");
  }

  auto track_id_ = track_->id();

  InitGPUPixel();
}

void FlutterVirtualBackground::InitGPUPixel() {
  #if !defined(_WIN32)
  // Initialize GLFW
  if (!glfwInit()) {
      std::cerr << "Failed to initialize GLFW" << std::endl;
      return;
  }
    
  GLFWwindow* window = GPUPixelContext::getInstance()->GetGLContext();

  if (window == NULL) {
    std::cout << "Failed to create GLFW window" << std::endl;
    return;
  }

  glfwMakeContextCurrent(window);

  if (!gladLoadGL()) {
      std::cerr << "Failed to initialize GLAD" << std::endl;
      return;
  }

  gpuPixelRawInput = SourceRawDataInput::create();

  lipstick_filter_ = LipstickFilter::create();
  blusher_filter_ = BlusherFilter::create();
  face_reshape_filter_ = FaceReshapeFilter::create();

  gpuPixelRawInput->RegLandmarkCallback([=](std::vector<float> landmarks) {
    lipstick_filter_->SetFaceLandmarks(landmarks);
    blusher_filter_->SetFaceLandmarks(landmarks);
    face_reshape_filter_->SetFaceLandmarks(landmarks);
  });

  targetRawOutput_ = TargetRawDataOutput::create();
  beauty_face_filter_ = BeautyFaceFilter::create();

  gpuPixelRawInput->addTarget(lipstick_filter_)
      ->addTarget(blusher_filter_)
      ->addTarget(face_reshape_filter_)
      ->addTarget(beauty_face_filter_)
      ->addTarget(targetRawOutput_);
  #endif
}

void FlutterVirtualBackground::OnFrame(scoped_refptr<RTCVideoFrame> frame) {
#if !defined(_WIN32)
  if (!frame) {
    std::cerr << "Received null frame in OnFrame." << std::endl;
    return;
  }

  int width = frame->width();
  int height = frame->height();

  auto modifiedFrame = frame->Copy();

  uint8_t* data_y = const_cast<uint8_t*>(modifiedFrame->DataY());
  uint8_t* data_u = const_cast<uint8_t*>(modifiedFrame->DataU());
  uint8_t* data_v = const_cast<uint8_t*>(modifiedFrame->DataV());

  int stride_y = modifiedFrame->StrideY();
  int stride_u = modifiedFrame->StrideU();
  int stride_v = modifiedFrame->StrideV();

  targetRawOutput_->setI420Callbck(
      [=](const uint8_t* data, int width, int height, int64_t ts) {
        // std::cout << "Received processed frame callback in I420 format." <<
        // std::endl;

        size_t y_size = stride_y * height;
        size_t u_size = stride_u * (height / 2);
        size_t v_size = stride_v * (height / 2);

        std::memcpy(data_y, data, y_size);
        std::memcpy(data_u, data + y_size, u_size);
        std::memcpy(data_v, data + y_size + u_size, v_size);
      });

  // Upload frame data to GPUPixel
  gpuPixelRawInput->uploadBytes(width, height, data_y, stride_y, data_u,
                                stride_u, data_v, stride_v);
#endif
}

void FlutterVirtualBackground::SetThinFaceValue(const double value) {
  #if !defined(_WIN32)
  face_reshape_filter_->setFaceSlimLevel(static_cast<float>(value));
  #endif
}

void FlutterVirtualBackground::SetWhiteValue(const double value) {
  #if !defined(_WIN32)
  beauty_face_filter_->setWhite(static_cast<float>(value));
  #endif
}

void FlutterVirtualBackground::SetBigEyeValue(const double value) {
  #if !defined(_WIN32)
  face_reshape_filter_->setEyeZoomLevel(static_cast<float>(value));
  #endif
}

void FlutterVirtualBackground::SetSmoothValue(const double value) {
  #if !defined(_WIN32)
  beauty_face_filter_->setBlurAlpha(static_cast<float>(value));
  #endif
}

void FlutterVirtualBackground::SetLipstickValue(const double value) {
  #if !defined(_WIN32)
  lipstick_filter_->setBlendLevel(static_cast<float>(value));
  #endif
}

void FlutterVirtualBackground::SetBlusherValue(const double value) {
  #if !defined(_WIN32)
  blusher_filter_->setBlendLevel(static_cast<float>(value));
  #endif
}

}  // namespace flutter_webrtc_plus_plugin
