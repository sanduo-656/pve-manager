import 'package:flutter/services.dart';

final class ConsoleCookieBridge {
  ConsoleCookieBridge._();

  static const MethodChannel _channel = MethodChannel(
    'com.sanduo.pvemanager/webview_security',
  );

  static Future<void> setSecureCookie({
    required Uri origin,
    required String ticket,
  }) async {
    final bool? accepted = await _channel.invokeMethod<bool>(
      'setSecureCookie',
      <String, String>{'origin': origin.toString(), 'ticket': ticket},
    );
    if (accepted != true) {
      throw StateError(
        'Android WebView rejected the PVE authentication cookie.',
      );
    }
  }

  static Future<void> clearAuthCookie({required Uri origin}) async {
    await _channel.invokeMethod<bool>('clearAuthCookie', <String, String>{
      'origin': origin.toString(),
    });
  }
}
