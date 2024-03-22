import '../desktop_capturer.dart';

export 'package:dart_webrtc_plus/dart_webrtc_plus.dart'
    hide videoRenderer, MediaDevices, MediaRecorder;

DesktopCapturer get desktopCapturer => throw UnimplementedError();
