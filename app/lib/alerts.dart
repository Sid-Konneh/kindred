import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api.dart';
import 'calls.dart';
import 'main.dart' show navKey;
import 'models.dart';
import 'push.dart';
import 'screens/matches.dart' show ChatScreen;
import 'theme.dart';
import 'widgets.dart';

/// Alerts for new likes, matches, messages and calls. Likes, matches and messages arrive over Realtime from the
/// notifications table (migration 017); calls come from the calls table (see calls.dart). On screen they show as a
/// banner at the top; in the background, as a phone notification. Android keeps the Realtime connection open for a
/// while after Kindred leaves the screen, but once the system stops the app nothing arrives (that needs Firebase push).
class Alerts {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static VoidCallback? _unsub;
  static String? _launchPayload;
  static final _rang = <String, String>{}; // call id -> caller name, for calls we put a notification up for
  static OverlayEntry? _banner;
  static Timer? _bannerTimer;

  /// Match id of the chat on screen, so its own messages don't alert.
  static String? openChat;

  /// Match this phone just celebrated after a swipe: its "It's a match!" screen is already showing.
  static String? shownMatch;

  static const _activity = AndroidNotificationDetails('activity', 'Likes, matches and messages',
      channelDescription: 'New likes, matches and messages', importance: Importance.high, priority: Priority.high, icon: 'ic_stat_kindred', color: K.brand);
  static const _calls = AndroidNotificationDetails('calls', 'Calls',
      channelDescription: 'Incoming voice and video calls', importance: Importance.max, priority: Priority.max,
      category: AndroidNotificationCategory.call, icon: 'ic_stat_kindred', color: K.brand);

  static bool get _onScreen => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  static int _id(String key) => key.hashCode & 0x7fffffff;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_kindred'),
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (r) => open(r.payload),
      );
      _ready = true;
      // Firebase pushes name these channels, so they must exist even before the first local alert
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel('activity', 'Likes, matches and messages', description: 'New likes, matches and messages', importance: Importance.high));
      await android?.createNotificationChannel(const AndroidNotificationChannel('calls', 'Calls', description: 'Incoming voice and video calls', importance: Importance.max));
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) _launchPayload = launch!.notificationResponse?.payload;
    } catch (_) {/* alerts are optional */}
  }

  /// Start or stop listening as the member signs in or out. Call after [Calls.watch], which hands Realtime the login token.
  static void watch(bool signedIn) {
    _unsub?.call();
    _unsub = null;
    if (!signedIn) {
      _hideBanner();
      if (_ready) _plugin.cancelAll().catchError((_) {});
      return;
    }
    _unsub = Api.onNotifications(_onRow);
    if (!_ready) return;
    _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission().catchError((_) => false);
    _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true).catchError((_) => false);
    final p = _launchPayload;
    _launchPayload = null;
    if (p != null) Future.delayed(const Duration(seconds: 3), () => open(p)); // after the splash and home screen settle
  }

  static void _onRow(Map<String, dynamic> n) {
    final kind = '${n['kind']}', matchId = n['match_id'] as String?, title = '${n['title']}', body = '${n['body'] ?? ''}';
    if (kind == 'match' || kind == 'message') app.refreshMatches();
    final payload = matchId ?? 'discover';
    if (!_onScreen) {
      if (!Push.enabled) _show(_id(matchId ?? kind), title, body, payload, _activity); // with push, Firebase shows it
    } else if (kind == 'message' && openChat == matchId) {
      // already reading it
    } else if (kind == 'match') {
      // the alert can arrive before the swipe reply that shows "It's a match!" on this phone
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (shownMatch != matchId) banner(title, body, payload);
      });
    } else {
      banner(title, body, payload);
    }
  }

  static void _show(int id, String title, String body, String payload, AndroidNotificationDetails android) {
    if (!_ready) return;
    _plugin
        .show(id: id, title: title, body: body, notificationDetails: NotificationDetails(android: android, iOS: const DarwinNotificationDetails()), payload: payload)
        .catchError((_) {});
  }

  /// A call started ringing. On screen the call screen already shows it; in the background, alert.
  static void ringing(CallRecord c, String name) {
    if (_onScreen || Push.enabled) return;
    _rang[c.id] = name;
    _show(_id('call-${c.id}'), '$name is calling you', c.video ? 'Kindred video call' : 'Kindred voice call', c.matchId, _calls);
  }

  /// A ringing call we alerted for has stopped: swap the alert for "Missed call", or clear it if it was answered.
  static void callDone(String callId, String status, String matchId) {
    final name = _rang.remove(callId);
    if (name == null || !_ready) return;
    final id = _id('call-$callId');
    if ((status == 'missed' || status == 'cancelled') && !_onScreen && !Push.enabled) {
      _show(id, 'Missed call from $name', 'Tap to open the chat.', matchId, _activity);
    } else {
      _plugin.cancel(id: id).catchError((_) {});
    }
  }

  /// Opening a chat clears its alerts.
  static void chatOpened(String matchId) {
    openChat = matchId;
    if (_ready) _plugin.cancel(id: _id(matchId)).catchError((_) {});
  }

  static void chatClosed(String matchId) {
    if (openChat == matchId) openChat = null;
  }

  /// Where tapping an alert goes: a match id opens that chat, 'discover' goes back to the home screen.
  static Future<void> open(String? payload) async {
    final nav = navKey.currentState;
    if (payload == null || nav == null || Api.uid == null || Calls.cur != null) return; // a ringing call has its own screen
    if (payload == 'discover') {
      nav.popUntil((r) => r.isFirst);
      return;
    }
    var m = app.matches?.where((x) => x.id == payload).firstOrNull;
    if (m == null) {
      await app.refreshMatches();
      m = app.matches?.where((x) => x.id == payload).firstOrNull;
    }
    if (m == null || openChat == payload) return;
    final match = m;
    nav.popUntil((r) => r.isFirst);
    nav.push(MaterialPageRoute(builder: (_) => ChatScreen(match: match)));
  }

  static void banner(String title, String body, String payload) {
    final overlay = navKey.currentState?.overlay;
    if (overlay == null) return;
    _hideBanner();
    final entry = OverlayEntry(builder: (_) => _AlertBanner(title: title, body: body, onTap: () {
          _hideBanner();
          open(payload);
        }, onDismiss: _hideBanner));
    _banner = entry;
    overlay.insert(entry);
    _bannerTimer = Timer(const Duration(seconds: 5), _hideBanner);
  }

  static void _hideBanner() {
    _bannerTimer?.cancel();
    _banner?.remove();
    _banner = null;
  }
}

class _AlertBanner extends StatelessWidget {
  final String title, body;
  final VoidCallback onTap, onDismiss;
  const _AlertBanner({required this.title, required this.body, required this.onTap, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Positioned(
      top: 0,
      left: 12,
      right: 12,
      child: SafeArea(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, -40 * (1 - t)), child: child)),
          child: GestureDetector(
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < 0) onDismiss();
            },
            child: Material(
              color: p.surface,
              elevation: 10,
              shadowColor: Colors.black45,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(children: [
                    const KMark(size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.text)),
                        if (body.isNotEmpty) Text(body, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: p.muted)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
