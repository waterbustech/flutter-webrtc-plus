@TestOn('browser')
library;

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:flutter_webrtc_plus/flutter_webrtc_plus.dart';

void main() {
  // TODO(wer-mathurin): should revisit after this bug is resolved, https://github.com/flutter/flutter/issues/66045.
  test('should complete succesfully', () async {
    var renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = await MediaDevices.getUserMedia({});
    await renderer.dispose();
  });
}
