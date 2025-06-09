#include "flutter_virtual_background.h"
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <cstring>
#include <iostream>

#if defined(_WIN32)
#include "ghc/filesystem.hpp"

namespace fs {
using namespace ghc::filesystem;
using ifstream = ghc::filesystem::ifstream;
using ofstream = ghc::filesystem::ofstream;
using fstream = ghc::filesystem::fstream;
}  // namespace fs

#include <Shlwapi.h>
#include <delayimp.h>
#include <windows.h>
#pragma comment(lib, "Shlwapi.lib")

#include "gpupixel/gpupixel.h"
#include "libyuv.h"

#else
#include "gpupixel.h"
#endif

using namespace gpupixel;

#if defined(_WIN32)
std::shared_ptr<BeautyFaceFilter> beauty_filter_;
std::shared_ptr<FaceReshapeFilter> reshape_filter_;
std::shared_ptr<gpupixel::LipstickFilter> lipstick_filter_;
std::shared_ptr<gpupixel::BlusherFilter> blusher_filter_;
std::shared_ptr<SourceRawData> source_raw_data_;
std::shared_ptr<SinkRawData> sink_raw_data_;
std::shared_ptr<FaceDetector> face_detector_;

// GLFW window handle
GLFWwindow* main_window_ = nullptr;

#else
std::shared_ptr<SourceRawDataInput> gpuPixelRawInput;
std::shared_ptr<BeautyFaceFilter> beauty_face_filter_;
std::shared_ptr<FaceReshapeFilter> face_reshape_filter_;
std::shared_ptr<gpupixel::LipstickFilter> lipstick_filter_;
std::shared_ptr<gpupixel::BlusherFilter> blusher_filter_;
std::shared_ptr<TargetRawDataOutput> targetRawOutput_;
#endif

namespace flutter_webrtc_plus_plugin {

std::string GetExecutablePath() {
  std::string path;
#ifdef _WIN32
  // Windows 平台实现
  char buffer[MAX_PATH];
  GetModuleFileNameA(NULL, buffer, MAX_PATH);
  PathRemoveFileSpecA(buffer);
  path = buffer;
#elif defined(__APPLE__)
  // macOS 平台实现
  char buffer[PATH_MAX];
  uint32_t size = sizeof(buffer);
  if (_NSGetExecutablePath(buffer, &size) == 0) {
    char realPath[PATH_MAX];
    if (realpath(buffer, realPath)) {
      path = realPath;
      // 移除文件名部分，只保留目录
      size_t pos = path.find_last_of("/\\");
      if (pos != std::string::npos) {
        path = path.substr(0, pos);
      }
    }
  }
#elif defined(__linux__)
  // Linux 平台实现
  char buffer[PATH_MAX];
  ssize_t count = readlink("/proc/self/exe", buffer, PATH_MAX);
  if (count != -1) {
    buffer[count] = '\0';
    path = buffer;
    // 移除文件名部分，只保留目录
    size_t pos = path.find_last_of("/\\");
    if (pos != std::string::npos) {
      path = path.substr(0, pos);
    }
  }
#endif
  return path;
}

// GLFW framebuffer resize callback
void OnFramebufferResize(GLFWwindow* window, int width, int height) {
  glViewport(0, 0, width, height);
}

// GLFW error callback
void ErrorCallback(int error, const char* description) {
  std::cerr << "GLFW Error: " << description << std::endl;
}

// Initialize GLFW and create window
bool SetupOffscreenContext() {
#ifdef _WIN32
  // Set GLFW error callback
  glfwSetErrorCallback(ErrorCallback);

  // Initialize GLFW
  if (!glfwInit()) {
    std::cerr << "Failed to initialize GLFW" << std::endl;
    return false;
  }

  // Set OpenGL version
#ifdef __APPLE__
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
  glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
#else
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
#endif

  // Create INVISIBLE window for offscreen rendering
  glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);

  // Create minimal window for OpenGL context
  main_window_ = glfwCreateWindow(1, 1, "Offscreen", NULL, NULL);
  if (main_window_ == NULL) {
    std::cerr << "Failed to create GLFW offscreen context" << std::endl;
    glfwTerminate();
    return false;
  }

  // Make context current
  glfwMakeContextCurrent(main_window_);

  // Initialize GLAD
  if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
    std::cerr << "Failed to initialize GLAD" << std::endl;
    glfwDestroyWindow(main_window_);
    glfwTerminate();
    return false;
  }

  std::cout << "Offscreen OpenGL context created successfully" << std::endl;
  return true;
#else
  return false;
#endif
}

void SetupFilterPipeline() {
#ifdef _WIN32
  auto resource_path = fs::path(GetExecutablePath());
  std::cout << "[Debug] Current resource path: " << resource_path << std::endl;
  std::string pathStr = resource_path.string();
  std::cout << "[Debug] resource_path string: " << pathStr << std::endl;

  GPUPixel::SetResourcePath(resource_path.string());

  try {
    // Create filters
    lipstick_filter_ = LipstickFilter::Create();
    blusher_filter_ = BlusherFilter::Create();
    reshape_filter_ = FaceReshapeFilter::Create();
    beauty_filter_ = BeautyFaceFilter::Create();

    face_detector_ = FaceDetector::Create();

    source_raw_data_ = SourceRawData::Create();
    sink_raw_data_ = SinkRawData::Create();

    // Build pipeline
    source_raw_data_->AddSink(lipstick_filter_)
        ->AddSink(blusher_filter_)
        ->AddSink(reshape_filter_)
        ->AddSink(beauty_filter_)
        ->AddSink(sink_raw_data_);

  } catch (const std::exception& e) {
    std::cerr << "[Plugin] Failed to create filter pipeline: " << e.what()
              << std::endl;
    throw;
  }
#endif
}

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
#if defined(_WIN32)
  std::string exePath = GetExecutablePath();
  char dllDir[MAX_PATH];
  sprintf_s(dllDir, MAX_PATH, "%s\\..\\Debug", exePath.c_str());
  SetDllDirectoryA(dllDir);

  if (!SetupOffscreenContext()) {
    throw std::runtime_error("Failed to setup offscreen OpenGL context");
  }

  SetupFilterPipeline();
#else
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
#if defined(_WIN32)
  try {
    // Allocate RGBA buffer
    std::vector<uint8_t> rgba_buffer(width * height * 4);

    // Convert I420 to RGBA
    modifiedFrame->ConvertToARGB(RTCVideoFrame::Type::kABGR, rgba_buffer.data(),
                                 width * 4, width, height);

    uint8_t* rgba = rgba_buffer.data();

    std::vector<float> landmarks = face_detector_->Detect(
        rgba, width, height, width * 4, GPUPIXEL_MODE_FMT_VIDEO,
        GPUPIXEL_FRAME_TYPE_RGBA);

    if (!landmarks.empty()) {
      lipstick_filter_->SetFaceLandmarks(landmarks);
      blusher_filter_->SetFaceLandmarks(landmarks);
      reshape_filter_->SetFaceLandmarks(landmarks);
    }

    // Process the frame through GPUPixel pipeline
    source_raw_data_->ProcessData(rgba, width, height, width * 4,
                                  GPUPIXEL_FRAME_TYPE_RGBA);

    if (sink_raw_data_) {
      const uint8_t* data = sink_raw_data_->GetRgbaBuffer();
      if (data) {
        libyuv::ABGRToI420(data, width * 4, data_y, stride_y, data_u,
          stride_u, data_v, stride_v, width, height);
      }
    }
  } catch (const std::exception& e) {
    std::cerr << "[Plugin] Error processing frame: " << e.what() << std::endl;
  }

#else
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
#if defined(_WIN32)
  if (reshape_filter_) {
    reshape_filter_->SetFaceSlimLevel(static_cast<float>(value));
  }
#else
  face_reshape_filter_->setFaceSlimLevel(static_cast<float>(value));
#endif
}

void FlutterVirtualBackground::SetWhiteValue(const double value) {
#if defined(_WIN32)
  if (beauty_filter_) {
    beauty_filter_->SetWhite(static_cast<float>(value));
  }
#else
  beauty_face_filter_->setWhite(static_cast<float>(value));
#endif
}

void FlutterVirtualBackground::SetBigEyeValue(const double value) {
#if defined(_WIN32)
  if (reshape_filter_) {
    reshape_filter_->SetEyeZoomLevel(static_cast<float>(value));
  }
#else
  face_reshape_filter_->setEyeZoomLevel(static_cast<float>(value));
#endif
}

void FlutterVirtualBackground::SetSmoothValue(const double value) {
#if defined(_WIN32)
  if (beauty_filter_) {
    beauty_filter_->SetBlurAlpha(static_cast<float>(value));
  }
#else
  beauty_face_filter_->setBlurAlpha(static_cast<float>(value));
#endif
}

void FlutterVirtualBackground::SetLipstickValue(const double value) {
#if defined(_WIN32)
  if (lipstick_filter_) {
    lipstick_filter_->SetBlendLevel(static_cast<float>(value));
  }
#else
  lipstick_filter_->setBlendLevel(static_cast<float>(value));
#endif
}

void FlutterVirtualBackground::SetBlusherValue(const double value) {
#if defined(_WIN32)
  if (blusher_filter_) {
    blusher_filter_->SetBlendLevel(static_cast<float>(value));
  }
#else
  blusher_filter_->setBlendLevel(static_cast<float>(value));
#endif
}

}  // namespace flutter_webrtc_plus_plugin
