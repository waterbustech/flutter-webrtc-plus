cmake_minimum_required(VERSION 3.15)
set(PROJECT_NAME "flutter_webrtc_plus")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must not be changed
set(PLUGIN_NAME "flutter_webrtc_plus_plugin")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 17)

# Define necessary flags and settings
add_definitions(-DLIB_WEBRTC_API_DLL)
add_definitions(-DRTC_DESKTOP_DEVICE)
add_definitions(-DGPUPIXEL_EXPORTS)

# Link directories for additional libraries
LINK_DIRECTORIES( 
  ${CMAKE_CURRENT_SOURCE_DIR}/../third_party/glfw/lib-vc2022
  ${CMAKE_CURRENT_SOURCE_DIR}/../third_party/gpupixel/lib/windows
)

# Add glad as a subdirectory and ensure it is linked
add_subdirectory(glad)

# Add source files
add_library(${PLUGIN_NAME} SHARED
  "../common/cpp/src/flutter_virtual_background.cc"
  "../common/cpp/src/flutter_common.cc"
  "../common/cpp/src/flutter_data_channel.cc"
  "../common/cpp/src/flutter_frame_cryptor.cc"
  "../common/cpp/src/flutter_media_stream.cc"
  "../common/cpp/src/flutter_peerconnection.cc"
  "../common/cpp/src/flutter_frame_capturer.cc"
  "../common/cpp/src/flutter_video_renderer.cc"
  "../common/cpp/src/flutter_screen_capture.cc"
  "../common/cpp/src/flutter_webrtc.cc"
  "../common/cpp/src/flutter_webrtc_base.cc"
  "../third_party/uuidxx/uuidxx.cc"
  "flutter_webrtc_plus_plugin.cc"
  "task_runner_windows.cc"
)

# Include directories for dependencies
include_directories(
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common/cpp/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/uuidxx"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/svpng"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/libwebrtc/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/gpupixel/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/glfw/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/glad/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/stb"
)

# Link gpupixel and OpenGL libraries
target_link_libraries(${PLUGIN_NAME} PRIVATE
      gpupixel
      opengl32
      glfw3
      glad
      )

# Apply standard settings
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")

# Link libwebrtc library
target_link_libraries(${PLUGIN_NAME} PRIVATE 
  flutter
  flutter_wrapper_plugin
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/libwebrtc/lib/win64/libwebrtc.dll.lib"
)

# Link VNN libraries (.lib files for static linking)
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vnn/libs/windows/x64/vnn_kit.lib"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vnn/libs/windows/x64/vnn_face.lib"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vnn/libs/windows/x64/vnn_core.lib"
)

# Add flags to ensure all libraries are linked
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--no-as-needed")

# Set the list of DLLs to be bundled with the plugin
set(flutter_webrtc_plus_bundled_libraries
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/libwebrtc/lib/win64/libwebrtc.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/glfw/lib-vc2022/glfw3.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vnn/libs/windows/x64/vnn_kit.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vnn/libs/windows/x64/vnn_face.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vnn/libs/windows/x64/vnn_core.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vnn/libs/windows/x64/vnn_kit.lib"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vnn/libs/windows/x64/vnn_face.lib"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vnn/libs/windows/x64/vnn_core.lib"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/gpupixel/lib/windows/gpupixel.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/gpupixel/res"
  PARENT_SCOPE
)

# Set the RPATH for Windows
if(WIN32)
  set_property(TARGET ${PLUGIN_NAME} PROPERTY INSTALL_RPATH "$ORIGIN")
else()
  set_property(TARGET ${PLUGIN_NAME} PROPERTY BUILD_RPATH "$ORIGIN")
endif()

target_compile_options(${PLUGIN_NAME} PRIVATE 
  "/wd4251"  # Disable specific warning about shared_ptr
)
