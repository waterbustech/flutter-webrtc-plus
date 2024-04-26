#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_webrtc_plus'
  s.version          = '0.9.36'
  s.summary          = 'Flutter WebRTC plugin for macOS.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'https://github.com/cloudwebrtc/flutter-webrtc'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'CloudWebRTC' => 'duanweiwei1982@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = ['Classes/**/*']

  s.dependency 'FlutterMacOS'
  s.dependency 'KaiRTC', '122.6261.07'
  s.osx.deployment_target = '11.0'
  s.preserve_paths = 'gpupixel.framework', 'vnn_core_osx.framework', 'vnn_face_osx.framework', 'vnn_kit_osx.framework'
  s.vendored_frameworks = 'gpupixel.framework', 'vnn_core_osx.framework', 'vnn_face_osx.framework', 'vnn_kit_osx.framework'
  s.framework = 'AVFoundation', 'CoreMedia', 'gpupixel', 'vnn_core_osx', 'vnn_face_osx', 'vnn_kit_osx'
end
