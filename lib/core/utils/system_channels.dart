import 'package:flutter/services.dart';

class AppSystemChannels {
  AppSystemChannels._();

  static const MethodChannel _channel = MethodChannel('jp.genbanote.app/system');

  static Future<void> requestBackgroundLocationPermissionIfNeeded() async {
    try {
      await _channel.invokeMethod<void>('requestBackgroundLocationPermission');
    } catch (_) {
      // 権限要求に失敗してもアプリ継続
    }
  }

  static Future<void> requestNotificationPermissionIfNeeded() async {
    try {
      await _channel.invokeMethod<void>('requestNotificationPermission');
    } catch (_) {
      // 権限要求に失敗してもアプリ継続
    }
  }
}
