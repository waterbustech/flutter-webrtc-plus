#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_webrtc_plus'
  s.version          = '0.14.0'
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
  s.dependency 'WebRTC-SDK', '125.6422.06'
  s.ios.deployment_target = '12.0'

  s.prepare_command = <<-CMD
    if [ -f "frameworks.zip" ]; then
      rm frameworks.zip
    fi
    if [ -d "gpupixel.framework" ]; then
      rm -rf gpupixel.framework
    fi
    
    curl -L -o frameworks.zip https://github.com/pixpark/gpupixel/releases/download/v0.3.1-beta.8/gpupixel_ios_arm64.zip
    unzip frameworks.zip
    mv lib/gpupixel.framework .
    rm -rf frameworks.zip lib models res include
  CMD

  s.preserve_paths = 'gpupixel.framework'
  s.vendored_frameworks = 'gpupixel.framework'
  s.framework = 'AVFoundation', 'CoreMedia', 'gpupixel'
  # s.static_framework = true
end
