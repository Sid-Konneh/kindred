import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'alerts.dart';
import 'api.dart';

/// Push through Firebase Cloud Messaging, so alerts reach the phone even when Kindred is closed (migration 018
/// and the "push" edge function). The server sends ready-made notifications that Android shows by itself; while
/// Kindred is on screen, Firebase hands them to the app instead and the in-app banner from alerts.dart shows.
class Push {
  static bool _ready = false;
  static String? _token;
  static StreamSubscription<String>? _refresh;

  /// True once this phone is registered for push, so alerts.dart leaves background alerts to Firebase.
  static bool get enabled => _token != null;

  static Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Firebase.initializeApp();
      _ready = true;
      // Tapping a push opens the chat (or Discover), from the background or from a closed app
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data));
      final first = await FirebaseMessaging.instance.getInitialMessage();
      if (first != null) Future.delayed(const Duration(seconds: 3), () => _open(first.data));
    } catch (e) {
      debugPrint('[push] Firebase unavailable: $e');
    }
  }

  static void _open(Map<String, dynamic> data) {
    final link = '${data['link'] ?? ''}';
    Alerts.open(link.startsWith('chat/') ? link.substring(5) : 'discover');
  }

  /// Register this phone for the signed-in member (or forget it when they sign out).
  static Future<void> watch(bool signedIn) async {
    if (!_ready) return;
    if (!signedIn) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await sb.rpc('register_push', params: {'p_kind': 'fcm', 'p_endpoint': token});
      _token = token;
      _refresh ??= FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
        try {
          await sb.rpc('register_push', params: {'p_kind': 'fcm', 'p_endpoint': t});
          _token = t;
        } catch (_) {/* next start */}
      });
    } catch (e) {
      debugPrint('[push] register failed: $e');
    }
  }

  /// Call BEFORE signing out (it needs the session), so a shared phone stops getting this member's alerts.
  static Future<void> signOut() async {
    final t = _token;
    _token = null;
    if (!_ready || t == null) return;
    try {
      await sb.rpc('unregister_push', params: {'p_endpoint': t});
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {/* the server drops dead tokens by itself */}
  }
}
