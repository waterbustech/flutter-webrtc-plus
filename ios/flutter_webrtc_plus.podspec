#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_webrtc_plus'
  s.version          = '0.9.36'
  s.summary          = 'Flutter WebRTC plugin for iOS.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'https://github.com/cloudwebrtc/flutter-webrtc'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'CloudWebRTC' => 'duanweiwei1982@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'KaiRTC', '124.6367.01'
  s.ios.deployment_target = '12.0'

  s.prepare_command = <<-CMD
    curl -L -o frameworks.zip https://github.com/webrtcsdk/gpupixel-ios/archive/refs/tags/1.2.5.zip
    unzip frameworks.zip
    mv gpupixel-ios-1.2.5/gpupixel.framework .
    mv gpupixel-ios-1.2.5/vnn_core_ios.framework .
    mv gpupixel-ios-1.2.5/vnn_face_ios.framework .
    mv gpupixel-ios-1.2.5/vnn_kit_ios.framework .
  CMD

  s.preserve_paths = 'gpupixel.framework', 'vnn_core_ios.framework', 'vnn_face_ios.framework', 'vnn_kit_ios.framework'
  s.vendored_frameworks = 'gpupixel.framework', 'vnn_core_ios.framework', 'vnn_face_ios.framework', 'vnn_kit_ios.framework'
  s.framework = 'AVFoundation', 'CoreMedia', 'gpupixel', 'vnn_core_ios', 'vnn_face_ios', 'vnn_kit_ios'
  # s.static_framework = true
end
