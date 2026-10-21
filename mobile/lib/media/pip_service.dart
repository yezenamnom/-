import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android Picture-in-Picture for the whole browser activity (the web video
/// keeps playing in the small window). iOS uses WKWebView's own native video
/// PiP from the system player controls (`allowsPictureInPictureMediaPlayback`),
/// so this service reports unsupported there.
class PipService extends ChangeNotifier {
  PipService({required this.isAndroid, MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('vela/pip') {
    if (isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onPipChanged') {
          inPip = call.arguments == true;
          notifyListeners();
        }
      });
    }
  }

  final bool isAndroid;
  final MethodChannel _channel;
  bool inPip = false;
  bool? _supported;

  Future<bool> isSupported() async {
    if (!isAndroid) return false;
    try {
      return _supported ??=
          await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> enter() async {
    if (!await isSupported()) return false;
    return await _channel.invokeMethod<bool>('enter') ?? false;
  }

  /// Arms automatic PiP when the user leaves the app (only while a video is
  /// fullscreen and the user enabled it).
  Future<void> setAuto(bool enabled, {int width = 16, int height = 9}) async {
    if (!await isSupported()) return;
    await _channel.invokeMethod<bool>(
        'setAuto', {'enabled': enabled, 'width': width, 'height': height});
  }
}
