import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Wraps FCM: asks for notification permission and hands the device token to
/// [onToken] at startup and whenever it rotates. Never throws to the caller.
class MessagingService {
  MessagingService._();

  static final MessagingService instance = MessagingService._();

  String? token;
  StreamSubscription<String>? _tokenSub;

  Future<void> init(void Function(String token) onToken) async {
    try {
      await _tokenSub?.cancel();
      await FirebaseMessaging.instance.requestPermission();
      token = await FirebaseMessaging.instance.getToken();
      if (token != null) onToken(token!);
      _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        token = t;
        onToken(t);
      });
    } catch (e) {
      debugPrint('FCM init failed: $e');
    }
  }

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    _tokenSub = null;
  }
}
