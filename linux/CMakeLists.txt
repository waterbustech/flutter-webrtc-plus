cmake_minimum_required(VERSION 3.10)
set(PROJECT_NAME "flutter_webrtc_plus")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "${PROJECT_NAME}_plugin")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 17)

add_definitions(-DRTC_DESKTOP_DEVICE)

# Add source files
add_library(${PLUGIN_NAME} SHARED
  "../third_party/uuidxx/uuidxx.cc"
  "../common/cpp/src/flutter_virtual_background.cc"
  "../common/cpp/src/flutter_data_channel.cc"
  "../common/cpp/src/flutter_frame_cryptor.cc"
  "../common/cpp/src/flutter_media_stream.cc"
  "../common/cpp/src/flutter_peerconnection.cc"
  "../common/cpp/src/flutter_frame_capturer.cc"
  "../common/cpp/src/flutter_video_renderer.cc"
  "../common/cpp/src/flutter_screen_capture.cc"
  "../common/cpp/src/flutter_webrtc.cc"
  "../common/cpp/src/flutter_webrtc_base.cc"
  "../common/cpp/src/flutter_common.cc"
  "flutter_webrtc_plus_plugin.cc"
  "flutter/core_implementations.cc"
  "flutter/standard_codec.cc"
  "flutter/plugin_registrar.cc"
  "task_runner_linux.cc"
)

# Include directories for gpupixel and vnn
include_directories(
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/flutter/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common/cpp/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/uuidxx"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/libwebrtc/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/svpng"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/gpupixel/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/glfw/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/stb"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/glad/include"
)

# Standard settings
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")

# Link libraries
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

# Add $ORIGIN to RPATH
set_property(TARGET ${PLUGIN_NAME} PROPERTY BUILD_RPATH "\$ORIGIN")

# Link gpupixel library
target_link_libraries(${PLUGIN_NAME} PRIVATE 
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/gpupixel/lib/linux/libgpupixel.so"
)

# Link libwebrtc library
target_link_libraries(${PLUGIN_NAME} PRIVATE 
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/libwebrtc/lib/${FLUTTER_TARGET_PLATFORM}/libwebrtc.so"
)

# Link vnn libraries
target_link_libraries(${PLUGIN_NAME} PRIVATE 
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vnn/libs/linux/libvnn_kit.so"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vnn/libs/linux/libvnn_face.so"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vnn/libs/linux/libvnn_core.so"
)

# Add flags to ensure all libraries are linked
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--no-as-needed")

# List of libraries to be bundled with the plugin
set(flutter_webrtc_plus_bundled_libraries
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/libwebrtc/lib/${FLUTTER_TARGET_PLATFORM}/libwebrtc.so"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/gpupixel/lib/linux/libgpupixel.so"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vnn/libs/linux/libvnn_kit.so"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vnn/libs/linux/libvnn_face.so"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vnn/libs/linux/libvnn_core.so"
  PARENT_SCOPE
)

set(RESOURCES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/gpupixel/res")

set(BUILD_OUTPUT_DIR "${CMAKE_BINARY_DIR}/res")

file(MAKE_DIRECTORY ${BUILD_OUTPUT_DIR})

add_custom_command(
    TARGET ${PLUGIN_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory_if_different
        ${RESOURCES_DIR}
        ${BUILD_OUTPUT_DIR}
    COMMENT "Copying resources from src/resources to resources directory"
)
