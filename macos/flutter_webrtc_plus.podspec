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
  s.dependency 'WebRTC-SDK', '125.6422.06'
  s.osx.deployment_target = '11.0'

  s.prepare_command = <<-CMD
    if [ -f "frameworks.zip" ]; then
      rm frameworks.zip
    fi
    if [ -d "gpupixel-macos-1.2.5" ]; then
      rm -rf gpupixel-macos-1.2.5
    fi
    if [ -d "gpupixel.framework" ]; then
      rm -rf gpupixel.framework
    fi
    if [ -d "vnn_core_osx.framework" ]; then
      rm -rf vnn_core_osx.framework
    fi
    if [ -d "vnn_face_osx.framework" ]; then
      rm -rf vnn_face_osx.framework
    fi
    if [ -d "vnn_kit_osx.framework" ]; then
      rm -rf vnn_kit_osx.framework
    fi
    
    curl -L -o frameworks.zip https://github.com/webrtcsdk/gpupixel-macos/archive/refs/tags/1.2.5.zip
    unzip frameworks.zip
    mv gpupixel-macos-1.2.5/gpupixel.framework .
    mv gpupixel-macos-1.2.5/vnn_core_osx.framework .
    mv gpupixel-macos-1.2.5/vnn_face_osx.framework .
    mv gpupixel-macos-1.2.5/vnn_kit_osx.framework .
  CMD

  s.preserve_paths = 'gpupixel.framework', 'vnn_core_osx.framework', 'vnn_face_osx.framework', 'vnn_kit_osx.framework'
  s.vendored_frameworks = 'gpupixel.framework', 'vnn_core_osx.framework', 'vnn_face_osx.framework', 'vnn_kit_osx.framework'
  s.framework = 'AVFoundation', 'CoreMedia', 'gpupixel', 'vnn_core_osx', 'vnn_face_osx', 'vnn_kit_osx'
end
