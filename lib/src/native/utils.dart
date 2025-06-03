// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';

class WebRTC {
  static const MethodChannel _channel = MethodChannel('FlutterWebRTC.Method');

  static bool get platformIsDesktop {
    if (kIsWeb) return false;

    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  static bool get platformIsWindows => !kIsWeb && Platform.isWindows;

  static bool get platformIsMacOS => !kIsWeb && Platform.isMacOS;

  static bool get platformIsLinux => !kIsWeb && Platform.isLinux;

  static bool get platformIsMobile =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  static bool get platformIsIOS => !kIsWeb && Platform.isIOS;

  static bool get platformIsAndroid => !kIsWeb && Platform.isAndroid;

  static bool get platformIsWeb => false;

  static bool get platformIsDarwin =>
      !kIsWeb && Platform.isIOS || Platform.isMacOS;

  static Future<T?> invokeMethod<T, P>(String methodName,
      [dynamic param]) async {
    if (kIsWeb) return null;

    await initialize();

    return _channel.invokeMethod<T>(
      methodName,
      param,
    );
  }

  static bool initialized = false;

  /// Initialize the WebRTC plugin. If this is not manually called, will be
  /// initialized with default settings.
  ///
  /// Params:
  ///
  /// "networkIgnoreMask": a list of AdapterType objects converted to string with `.value`
  ///
  /// Android specific params:
  ///
  /// "forceSWCodec": a boolean that forces software codecs to be used for video.
  ///
  /// "forceSWCodecList": a list of strings of software codecs that should use software.
  ///
  /// "androidAudioConfiguration": an AndroidAudioConfiguration object mapped with toMap()
  ///
  /// "bypassVoiceProcessing": a boolean that bypasses the audio processing for the audio device.
  static Future<void> initialize({Map<String, dynamic>? options}) async {
    if (kIsWeb) return;

    if (!initialized) {
      await _channel.invokeMethod<void>('initialize', <String, dynamic>{
        'options': options ?? {},
      });
      initialized = true;
    }
  }
}
