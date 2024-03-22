import 'package:webrtc_interface_plus/webrtc_interface_plus.dart';

import 'mediadevices_impl.dart';

class NavigatorNative extends Navigator {
  NavigatorNative._internal();

  static final NavigatorNative instance = NavigatorNative._internal();

  @override
  Future<MediaStream> getDisplayMedia(Map<String, dynamic> mediaConstraints) {
    return mediaDevices.getDisplayMedia(mediaConstraints);
  }

  @override
  Future<List> getSources() {
    return mediaDevices.enumerateDevices();
  }

  @override
  Future<MediaStream> getUserMedia(Map<String, dynamic> mediaConstraints) {
    return mediaDevices.getUserMedia(mediaConstraints);
  }

  @override
  MediaDevices get mediaDevices => MediaDeviceNative.instance;
}
