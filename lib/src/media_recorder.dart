// Package imports:
import 'package:webrtc_interface_plus/webrtc_interface_plus.dart' as rtc;

// Project imports:
import '../flutter_webrtc_plus.dart';

class MediaRecorder extends rtc.MediaRecorder {
  MediaRecorder() : _delegate = mediaRecorder();
  final rtc.MediaRecorder _delegate;

  @override
  Future<void> start(String path,
          {MediaStreamTrack? videoTrack, RecorderAudioChannel? audioChannel}) =>
      _delegate.start(path, videoTrack: videoTrack, audioChannel: audioChannel);

  @override
  Future stop() => _delegate.stop();

  @override
  void startWeb(
    MediaStream stream, {
    Function(dynamic blob, bool isLastOne)? onDataChunk,
    String? mimeType,
    int timeSlice = 1000,
  }) =>
      _delegate.startWeb(
        stream,
        onDataChunk: onDataChunk,
        mimeType: mimeType ?? 'video/webm',
        timeSlice: timeSlice,
      );
}
