import 'package:flutter/services.dart';

class AECBridge {
  static const MethodChannel _channel = MethodChannel('com.example.agentic_chat/audio_aec');

  static Future<bool> enableAEC(int audioSessionId) async {
    try {
      final bool? success = await _channel.invokeMethod('enableAEC', {
        'sessionId': audioSessionId,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      print("Failed to enable AEC: ${e.message}");
      return false;
    }
  }

  static Future<void> disableAEC() async {
    await _channel.invokeMethod('disableAEC');
  }
}
