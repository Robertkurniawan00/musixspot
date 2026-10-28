import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.spotivibes.app/native');

  /// Opens native Android Bluetooth Settings screen directly
  static Future<bool> openBluetoothSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openBluetoothSettings');
      return res ?? false;
    } catch (e) {
      debugPrint('NativeBridge.openBluetoothSettings error: $e');
      return false;
    }
  }

  /// Opens native Android Share sheet
  static Future<bool> shareSong({
    required String title,
    required String text,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('shareSong', {
        'title': title,
        'text': text,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('NativeBridge.shareSong error: $e');
      return false;
    }
  }
}
