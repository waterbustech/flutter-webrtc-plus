import 'package:flutter_webrtc_plus/flutter_webrtc_plus.dart';

extension VideoRendererExtension on RTCVideoRenderer {
  RTCVideoValue get videoValue => value;
}
