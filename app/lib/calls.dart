import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'api.dart';
import 'main.dart' show navKey;
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

/// Voice and video calls between matches, peer to peer over WebRTC. The caller's offer and the callee's
/// answer (with their network candidates already gathered) travel through the calls table over Realtime,
/// which is also the call history shown in chat. Same protocol as the web app, so the two can call each other.
/// Only public STUN servers are used, so a few strict mobile networks may not connect without a TURN relay.
const _iceServers = {
  'iceServers': [
    {'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302', 'stun:stun.cloudflare.com:3478']},
  ],
};
const _endStates = ['declined', 'busy', 'missed', 'cancelled', 'ended', 'failed'];

String fmtDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

class CallSession extends ChangeNotifier {
  final String role; // 'caller' or 'callee'
  final String matchId;
  final bool video;
  Profile other;
  CallRecord? rec;
  RTCPeerConnection? pc;
  MediaStream? local;
  final localView = RTCVideoRenderer(), remoteView = RTCVideoRenderer();
  String status;
  DateTime? started;
  bool answered = false, accepting = false, muted = false, camOff = false, speaker, frontCamera = true, hasRemoteVideo = false, over = false;
  Timer? _ring, _drop, _tick;

  CallSession({required this.role, required this.matchId, required this.video, required this.other, required this.status, this.rec}) : speaker = video;

  bool get ringingIn => role == 'callee' && !accepting && !answered;
  bool get live => started != null;

  void set(String s) {
    status = s;
    notifyListeners();
  }
}

class Calls {
  static CallSession? cur;
  static VoidCallback? _unsub;
  static final _ringtone = FlutterRingtonePlayer();
  static bool _ringing = false;
  static final log = ValueNotifier<int>(0); // bumps when any call changes, so an open chat refreshes its history

  /// Start or stop listening for calls as the member signs in or out.
  static void watch(bool signedIn) {
    _unsub?.call();
    _unsub = null;
    if (!signedIn) {
      _teardown(null);
      return;
    }
    // Subscribing straight from the sign-in event can race Realtime getting the new login token, and without
    // it the calls table's row security hides every call. Hand it the token first.
    final token = sb.auth.currentSession?.accessToken;
    if (token != null) sb.realtime.setAuth(token);
    _unsub = Api.onCalls(_onRow);
    checkRinging();
    Future.delayed(const Duration(seconds: 3), checkRinging); // in case a call started while the channel was joining
  }

  /// Picks up a call that started ringing while the app was closed or in the background.
  static Future<void> checkRinging() async {
    if (Api.uid == null) return;
    try {
      for (final c in await Api.ringingCalls()) {
        _onRow(c);
      }
    } catch (_) {/* offline */}
  }

  static void _onRow(CallRecord c) {
    log.value++;
    final s = cur;
    if (c.callee == Api.uid && c.status == 'ringing' && s?.rec?.id != c.id) {
      if (s != null) {
        Api.updateCall(c.id, 'busy').catchError((_) => c);
        return;
      }
      _incoming(c);
      return;
    }
    if (s == null || s.rec?.id != c.id) return;
    s.rec = c;
    if (c.status == 'accepted' && s.role == 'caller' && c.answer != null && !s.answered) {
      s.answered = true;
      s._ring?.cancel();
      s.set('Connecting…');
      s.pc?.setRemoteDescription(RTCSessionDescription(c.answer, 'answer')).catchError((_) => hangup('failed', "Couldn't connect the call."));
    } else if (_endStates.contains(c.status)) {
      final n = s.other.name;
      _teardown(switch (c.status) {
        'declined' => '$n declined the call',
        'busy' => '$n is on another call',
        'missed' || 'cancelled' => s.role == 'callee' ? 'Missed call from $n' : "$n didn't answer",
        'ended' => s.started != null ? 'Call ended · ${fmtDuration(DateTime.now().difference(s.started!))}' : 'Call ended',
        _ => 'The call dropped',
      });
    }
  }

  static Future<void> start(MatchItem m, bool video) async {
    final ctx = navKey.currentContext;
    if (cur != null) {
      if (ctx != null) toast(ctx, "You're already on a call.");
      return;
    }
    final s = cur = CallSession(role: 'caller', matchId: m.id, video: video, other: m.other, status: 'Calling…');
    await _open(s);
    try {
      await _media(s);
      final pc = await _makePc(s);
      await pc.setLocalDescription(await pc.createOffer());
      final sdp = await _gathered(pc);
      if (cur != s) return;
      s.rec = await Api.startCall(m.id, video, sdp);
      if (cur != s) {
        Api.updateCall(s.rec!.id, 'cancelled').catchError((_) => s.rec!);
        return;
      }
      s.set('Ringing…');
      s._ring = Timer(const Duration(seconds: 45), () {
        if (cur == s && !s.answered) hangup('missed', "${s.other.name} didn't answer");
      });
    } catch (e) {
      debugPrint('[calls] start failed: $e');
      if (cur == s) _teardown(_mediaError(e, s));
    }
  }

  static Future<void> _incoming(CallRecord c) async {
    final s = cur = CallSession(role: 'callee', matchId: c.matchId, video: c.video, other: Profile(id: c.caller, name: 'Your match'), status: c.video ? 'Kindred video call…' : 'Kindred voice call…', rec: c);
    var m = app.matches?.where((x) => x.id == c.matchId).firstOrNull;
    if (m == null) {
      await app.refreshMatches();
      m = app.matches?.where((x) => x.id == c.matchId).firstOrNull;
    }
    if (cur != s) return;
    if (m != null) s.other = m.other;
    _ringing = !kIsWeb; // the ringtone plugin has no web version
    if (_ringing) _ringtone.playRingtone(looping: true, volume: 1, asAlarm: false).catchError((_) {});
    HapticFeedback.heavyImpact();
    s._ring = Timer(const Duration(seconds: 45), () {
      if (cur == s && !s.answered && !s.accepting) _teardown('Missed call from ${s.other.name}');
    });
    await _open(s);
  }

  static Future<void> accept() async {
    final s = cur;
    if (s == null || s.role != 'callee' || s.accepting) return;
    s.accepting = true;
    _stopRing();
    s._ring?.cancel();
    s.set('Connecting…');
    try {
      await _media(s);
      final pc = await _makePc(s);
      await pc.setRemoteDescription(RTCSessionDescription(s.rec!.offer, 'offer'));
      await pc.setLocalDescription(await pc.createAnswer());
      final sdp = await _gathered(pc);
      if (cur != s) return;
      final row = await Api.updateCall(s.rec!.id, 'accepted', sdp);
      if (cur != s) return;
      if (row.status == 'accepted') {
        s.answered = true;
      } else {
        _teardown('Missed call from ${s.other.name}');
      }
    } catch (e) {
      if (cur == s) {
        Api.updateCall(s.rec!.id, 'failed').catchError((_) => s.rec!);
        debugPrint('[calls] accept failed: $e');
        _teardown(_mediaError(e, s));
      }
    }
  }

  static void hangup([String? status, String? msg]) {
    final s = cur;
    if (s == null) return;
    final st = status ?? (s.answered ? 'ended' : s.role == 'caller' ? 'cancelled' : 'declined');
    if (s.rec != null) Api.updateCall(s.rec!.id, st).catchError((_) => s.rec!);
    _teardown(msg ?? (s.started != null ? 'Call ended · ${fmtDuration(DateTime.now().difference(s.started!))}' : null));
  }

  static void toggleMute() {
    final s = cur;
    if (s?.local == null) return;
    s!.muted = !s.muted;
    for (final t in s.local!.getAudioTracks()) {
      t.enabled = !s.muted;
    }
    s.set(s.status);
  }

  static void toggleCamera() {
    final s = cur;
    if (s?.local == null) return;
    s!.camOff = !s.camOff;
    for (final t in s.local!.getVideoTracks()) {
      t.enabled = !s.camOff;
    }
    s.set(s.status);
  }

  static Future<void> flipCamera() async {
    final s = cur;
    final t = s?.local?.getVideoTracks().firstOrNull;
    if (s == null || t == null) return;
    try {
      s.frontCamera = await Helper.switchCamera(t);
      s.set(s.status);
    } catch (_) {
      final ctx = navKey.currentContext;
      if (ctx != null && ctx.mounted) toast(ctx, 'This phone has only one camera.');
    }
  }

  static Future<void> toggleSpeaker() async {
    final s = cur;
    if (s == null) return;
    s.speaker = !s.speaker;
    if (!kIsWeb) await Helper.setSpeakerphoneOn(s.speaker).catchError((_) {});
    s.set(s.status);
  }

  // ----- internals -----
  static Future<void> _open(CallSession s) async {
    await s.localView.initialize();
    await s.remoteView.initialize();
    if (cur != s) return;
    navKey.currentState?.push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => CallScreen(s: s),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  static Future<void> _media(CallSession s) async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
      'video': !s.video
          ? false
          : kIsWeb
              ? {'facingMode': 'user', 'width': {'ideal': 640}, 'height': {'ideal': 480}, 'frameRate': {'ideal': 24}}
              : {
                  'facingMode': 'user',
                  'mandatory': {'minWidth': '640', 'minHeight': '480', 'minFrameRate': '24'},
                  'optional': [],
                },
    });
    if (cur != s) {
      for (final t in stream.getTracks()) {
        t.stop();
      }
      throw const _Gone();
    }
    s.local = stream;
    if (s.video) s.localView.srcObject = stream;
    s.set(s.status);
  }

  static Future<RTCPeerConnection> _makePc(CallSession s) async {
    final pc = s.pc = await createPeerConnection(_iceServers);
    for (final t in s.local!.getTracks()) {
      await pc.addTrack(t, s.local!);
    }
    pc.onTrack = (e) {
      if (e.streams.isEmpty) return;
      s.remoteView.srcObject = e.streams.first;
      if (e.track.kind == 'video') s.hasRemoteVideo = true;
      s.set(s.status);
    };
    pc.onConnectionState = (st) {
      if (cur != s) return;
      switch (st) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          s._drop?.cancel();
          if (s.started == null) {
            s.started = DateTime.now();
            if (!kIsWeb) Helper.setSpeakerphoneOn(s.speaker).catchError((_) {});
            s._tick = Timer.periodic(const Duration(seconds: 1), (_) => s.set(fmtDuration(DateTime.now().difference(s.started!))));
          }
          s.set(fmtDuration(DateTime.now().difference(s.started!)));
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          s.set('Reconnecting…');
          s._drop?.cancel();
          s._drop = Timer(const Duration(seconds: 12), () {
            if (cur == s && pc.connectionState != RTCPeerConnectionState.RTCPeerConnectionStateConnected) hangup('failed', 'The call dropped. The connection was lost.');
          });
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          hangup('failed', s.started != null ? 'The call dropped. The connection was lost.' : "Couldn't connect. One of you may be on a network that blocks calls. Try Wi-Fi.");
        default:
      }
    };
    return pc;
  }

  /// Waits (up to 2.5 s) for network candidates, then returns the full offer/answer to send.
  static Future<String> _gathered(RTCPeerConnection pc) async {
    if (pc.iceGatheringState != RTCIceGatheringState.RTCIceGatheringStateComplete) {
      final done = Completer<void>();
      pc.onIceGatheringState = (st) {
        if (st == RTCIceGatheringState.RTCIceGatheringStateComplete && !done.isCompleted) done.complete();
      };
      await done.future.timeout(const Duration(milliseconds: 2500), onTimeout: () {});
    }
    final d = await pc.getLocalDescription();
    return d!.sdp!;
  }

  static String? _mediaError(Object e, CallSession s) {
    if (e is _Gone) return null;
    final t = '$e'.toLowerCase();
    if (t.contains('permission') || t.contains('notallowed')) {
      return 'Kindred needs your microphone${s.video ? ' and camera' : ''} for calls. Allow it in your phone settings and try again.';
    }
    if (t.contains('notfound') || t.contains('no camera') || t.contains('device')) return "Your phone's microphone${s.video ? ' or camera' : ''} isn't available right now.";
    return friendly(e);
  }

  static void _stopRing() {
    if (_ringing) {
      _ringing = false;
      _ringtone.stop().catchError((_) {});
    }
  }

  static void _teardown(String? msg) {
    final s = cur;
    if (s == null) return;
    cur = null;
    s.over = true;
    _stopRing();
    s._ring?.cancel();
    s._drop?.cancel();
    s._tick?.cancel();
    s.pc?.close().catchError((_) {});
    for (final t in s.local?.getTracks() ?? <MediaStreamTrack>[]) {
      t.stop();
    }
    s.local?.dispose().catchError((_) {});
    if (!kIsWeb) Helper.setSpeakerphoneOn(false).catchError((_) {}); // speaker routing only exists on phones
    s.set(s.status); // the call screen closes itself
    Future.delayed(const Duration(milliseconds: 800), () {
      s.localView.dispose();
      s.remoteView.dispose();
    });
    log.value++;
    final ctx = navKey.currentContext;
    if (msg != null && ctx != null) toast(ctx, msg);
  }
}

class _Gone implements Exception {
  const _Gone();
}

/// Full-screen call: incoming (accept / decline), ringing, and the live call with its controls.
class CallScreen extends StatefulWidget {
  final CallSession s;
  const CallScreen({super.key, required this.s});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  bool _popped = false;
  CallSession get s => widget.s;

  @override
  void initState() {
    super.initState();
    s.addListener(_changed);
  }

  void _changed() {
    if (s.over && !_popped) {
      _popped = true;
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    s.removeListener(_changed);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showRemote = s.video && s.live && s.hasRemoteVideo;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_popped) Calls.hangup();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: const Color(0xFF0C0709),
          body: Stack(fit: StackFit.expand, children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(center: Alignment(0, -1), radius: 1.3, colors: [Color(0xFF4A1A2C), Color(0xFF1A0D13), Color(0xFF0C0709)], stops: [0, .58, 1]),
              ),
            ),
            if (s.video && !s.over)
              AnimatedOpacity(
                opacity: showRemote ? 1 : 0,
                duration: const Duration(milliseconds: 350),
                child: RTCVideoView(s.remoteView, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            SafeArea(
              child: Column(children: [
                if (showRemote) _pill() else _who(),
                const Spacer(),
                _controls(),
                const SizedBox(height: 30),
              ]),
            ),
            if (s.video && s.local != null && !s.over)
              Positioned(
                right: 14,
                bottom: 130 + MediaQuery.of(context).padding.bottom,
                width: 104,
                height: 146,
                child: Opacity(
                  opacity: s.camOff ? .25 : 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8))],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: RTCVideoView(s.localView, mirror: s.frontCamera, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _who() => Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * .12),
        child: Column(children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Container(
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                if (!s.live) BoxShadow(color: K.g1.withValues(alpha: .5 * (1 - _pulse.value)), spreadRadius: 28 * _pulse.value),
              ]),
              child: child,
            ),
            child: Avatar(s.other, size: 112),
          ),
          const SizedBox(height: 18),
          Text(s.other.name, style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(s.status, style: TextStyle(color: Colors.white.withValues(alpha: .74), fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );

  Widget _pill() => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.fromLTRB(5, 5, 16, 5),
        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Avatar(s.other, size: 38),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.other.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            Text(s.status, style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
        ]),
      );

  Widget _controls() {
    if (s.ringingIn) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _btn(Icons.call_end, 'Decline', () => Calls.hangup(), color: const Color(0xFFE5484D), label: 'Decline'),
        const SizedBox(width: 96),
        _btn(s.video ? Icons.videocam : Icons.call, 'Accept', Calls.accept, color: K.good, label: 'Accept'),
      ]);
    }
    return Wrap(alignment: WrapAlignment.center, spacing: 16, runSpacing: 16, children: [
      _btn(s.muted ? Icons.mic_off : Icons.mic, s.muted ? 'Unmute' : 'Mute', Calls.toggleMute, on: s.muted),
      if (s.video) _btn(s.camOff ? Icons.videocam_off : Icons.videocam, s.camOff ? 'Turn camera on' : 'Turn camera off', Calls.toggleCamera, on: s.camOff),
      if (s.video) _btn(Icons.cameraswitch_outlined, 'Switch camera', Calls.flipCamera),
      _btn(s.speaker ? Icons.volume_up : Icons.volume_down_outlined, s.speaker ? 'Speaker on' : 'Speaker off', Calls.toggleSpeaker, on: s.speaker),
      _btn(Icons.call_end, 'End call', () => Calls.hangup(), color: const Color(0xFFE5484D)),
    ]);
  }

  Widget _btn(IconData ic, String tip, VoidCallback onTap, {Color? color, bool on = false, String? label}) => Column(mainAxisSize: MainAxisSize.min, children: [
        Semantics(
          button: true,
          label: tip,
          child: Material(
            color: color ?? (on ? Colors.white : Colors.white.withValues(alpha: .16)),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 62, height: 62, child: Icon(ic, color: on && color == null ? const Color(0xFF1A0D13) : Colors.white, size: 27)),
            ),
          ),
        ),
        if (label != null)
          GestureDetector(
            onTap: onTap, // the caption under the button is part of the target too
            behavior: HitTestBehavior.opaque,
            child: ExcludeSemantics(child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)))),
          ),
      ]);
}
