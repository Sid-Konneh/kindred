import 'dart:convert';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'alerts.dart';
import 'calls.dart';
import 'config.dart';
import 'models.dart';

SupabaseClient get sb => Supabase.instance.client;

/// Reference data, identical to the web app.
const cities = ['Freetown', 'Bo', 'Kenema', 'Makeni', 'Koidu', 'Port Loko', 'Lungi', 'Waterloo', 'Kabala', 'Kailahun', 'Magburaka', 'Moyamba', 'Bonthe', 'Pujehun', 'Kambia'];
const allInterests = ['Afrobeats', 'Football', 'Cooking', 'Beach days', 'Church choir', 'Gospel & worship', 'Fashion', 'Tech', 'Reading', 'Dancing', 'Entrepreneurship', 'Travel', 'Movies', 'Nature', 'Photography', 'Volunteering', 'Farming', 'Fitness', 'Poetry', 'Gaming'];
const allLanguages = ['Krio', 'English', 'Temne', 'Mende', 'Limba', 'Fula', 'Kono', 'Susu', 'Loko', 'Sherbro', 'Mandingo', 'French', 'Arabic'];
const lookingOptions = [('relationship', 'A relationship', '💞'), ('marriage', 'Marriage', '💍'), ('friendship', 'New friends', '🤝'), ('not_sure', 'Still figuring it out', '✨')];
const religionOptions = [('muslim', 'Muslim'), ('christian', 'Christian'), ('other', 'Other'), ('prefer_not', 'Prefer not to say')];
const reportReasons = ['Fake profile or scam', 'Asked me for money', 'Inappropriate photos', 'Harassment or threats', 'Looks under 18', 'Something else'];

String lookingLabel(String? k) => lookingOptions.where((o) => o.$1 == k).map((o) => o.$2).firstOrNull ?? '';
String religionLabel(String? k) => religionOptions.where((o) => o.$1 == k).map((o) => o.$2).firstOrNull ?? '';

String friendly(Object e) {
  final m = e is AuthException ? e.message : e is PostgrestException ? e.message : e is StorageException ? e.message : '$e';
  final s = m.toLowerCase();
  if (s.contains('invalid login credentials')) return 'Email or password is incorrect.';
  if (s.contains('temporary email addresses are not allowed')) return "Temporary email addresses can't be used on Kindred. Please use your own email.";
  if (s.contains('please use a valid email') || s.contains('database error saving new user')) return "We couldn't create an account with that email. Please check it and try again.";
  if (s.contains('real first name')) return 'Please use your real first name, using letters only.';
  if (s.contains('user is banned') || s.contains('been suspended')) return 'This account has been suspended. If you think this is a mistake, email kindred.salone@gmail.com.';
  if (s.contains('email not confirmed')) return 'Please confirm your email first. Check your inbox (and spam folder).';
  if (s.contains('already registered') || s.contains('already exists')) return 'An account with this email already exists. Try signing in instead.';
  if (s.contains('18 or older')) return 'You must be 18 or older to use Kindred.';
  if (s.contains('socketexception') || s.contains('failed host lookup') || s.contains('network') || s.contains('clientexception')) {
    return "Can't reach Kindred right now. Check your data or Wi-Fi and try again.";
  }
  if (s.contains('email rate limit') || s.contains('over_email_send_rate_limit') || s.contains('error sending')) {
    return "We couldn't send your email just now because our email service is busy. Your details weren't saved, so please try again a little later. Sorry about that!";
  }
  if (s.contains('rate limit') || s.contains('security purposes') || s.contains('too many')) return 'Too many attempts. Please wait a minute and try again.';
  if (s.contains('password should be') || s.contains('weak password')) return 'Please choose a stronger password (8+ characters, letters and numbers).';
  if (s.contains('different from the old')) return 'Your new password must be different from the old one.';
  if (s.contains('jwt') || s.contains('sign in again')) return 'Your session expired. Please sign in again.';
  return m.isEmpty ? 'Something went wrong. Please try again.' : m;
}

/// Small JSON cache so screens open instantly with the last known data (stale-while-revalidate).
class Cache {
  static late SharedPreferences _p;
  static Future<void> init() async => _p = await SharedPreferences.getInstance();
  static String? get _u => sb.auth.currentUser?.id;
  static dynamic get(String k) {
    final raw = _p.getString('kc:$k');
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      return v['u'] == _u ? v['d'] : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> set(String k, dynamic d) => _p.setString('kc:$k', jsonEncode({'u': _u, 'd': d}));
  static Future<void> clear() async {
    for (final k in _p.getKeys().where((k) => k.startsWith('kc:')).toList()) {
      await _p.remove(k);
    }
  }

  static String getPref(String k, String d) => _p.getString('kp:$k') ?? d;
  static Future<void> setPref(String k, String v) => _p.setString('kp:$k', v);
}

class Api {
  static String? get uid => sb.auth.currentUser?.id;
  static String? get email => sb.auth.currentUser?.email;

  /// Returns true when the account still needs its email confirmed.
  static Future<bool> signUp({required String name, required String email, required String password, required String birthdate}) async {
    final r = await sb.auth.signUp(email: email, password: password, emailRedirectTo: appRedirect, data: {'name': name, 'birthdate': birthdate});
    if (r.user != null && (r.user!.identities?.isEmpty ?? false)) throw const AuthException('User already registered');
    return r.session == null;
  }

  static Future<void> signIn(String email, String password) => sb.auth.signInWithPassword(email: email, password: password);
  static Future<void> resendSignup(String email) => sb.auth.resend(type: OtpType.signup, email: email, emailRedirectTo: appRedirect);
  static Future<void> sendReset(String email) => sb.auth.resetPasswordForEmail(email, redirectTo: appRedirect);
  static Future<void> updatePassword(String pw) => sb.auth.updateUser(UserAttributes(password: pw));
  static Future<void> signOut() async {
    await Cache.clear();
    await sb.auth.signOut();
  }

  static Future<Profile> me() async => Profile.fromJson(await sb.from('profiles').select().eq('id', uid!).single());
  static Future<Profile> saveProfile(Map<String, dynamic> patch) async =>
      Profile.fromJson(await sb.from('profiles').update(patch).eq('id', uid!).select().single());
  static Future<void> touch() async {
    if (uid != null) await sb.from('profiles').update({'last_active': DateTime.now().toUtc().toIso8601String()}).eq('id', uid!);
  }

  /// Records which device the member uses (for account security and support). The device key is a
  /// random id created once per install, not a hardware identifier.
  static Future<void> registerDevice(bool newSignIn) async {
    if (uid == null) return;
    var key = Cache.getPref('device', '');
    if (key.isEmpty) {
      final r = Random.secure();
      key = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await Cache.setPref('device', key);
    }
    String platform = 'web', os = '', browser = '';
    String? model;
    final info = DeviceInfoPlugin();
    if (kIsWeb) {
      final w = await info.webBrowserInfo;
      browser = w.browserName.name;
      os = w.platform ?? '';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final a = await info.androidInfo;
      platform = 'android_app';
      os = 'Android ${a.version.release}';
      final maker = a.manufacturer.isEmpty ? '' : '${a.manufacturer[0].toUpperCase()}${a.manufacturer.substring(1)} ';
      model = '$maker${a.model}'.trim();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final i = await info.iosInfo;
      platform = 'ios_app';
      os = 'iOS ${i.systemVersion}';
      model = i.utsname.machine;
    }
    final pkg = await PackageInfo.fromPlatform();
    await sb.rpc('register_device', params: {
      'p_key': key,
      'p_platform': platform,
      'p_os': os.isEmpty ? null : os,
      'p_browser': browser.isEmpty ? null : browser,
      'p_model': model,
      'p_app_version': kIsWeb ? null : '${pkg.version} (${pkg.buildNumber})',
      'p_new_sign_in': newSignIn,
    });
  }

  static Future<String> uploadPhoto(Uint8List bytes, String name) async {
    final ext = name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final path = '$uid/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await sb.storage.from('photos').uploadBinary(path, bytes,
        fileOptions: FileOptions(contentType: ext == 'png' ? 'image/png' : 'image/jpeg', cacheControl: '31536000'));
    return sb.storage.from('photos').getPublicUrl(path);
  }

  /// New people by default; with [recycle], people you passed on, in a new random order.
  static Future<List<Profile>> feed({String? city, bool recycle = false}) async {
    final rows = await sb.rpc('discover_feed', params: {'p_limit': 20, 'p_city': (city == null || city.isEmpty) ? null : city, 'p_recycle': recycle});
    return (rows as List).map((r) => Profile.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  static Future<String?> swipe(String target, String action) async {
    final r = await sb.rpc('swipe', params: {'p_target': target, 'p_action': action});
    return r == null ? null : '$r';
  }

  static Future<List<MatchItem>> matches() async {
    final rows = await sb.rpc('my_matches');
    return (rows as List).map((r) => MatchItem.fromRpc(Map<String, dynamic>.from(r))).toList();
  }

  static Future<List<Message>> messages(String matchId) async {
    final rows = await sb.from('messages').select().eq('match_id', matchId).order('created_at', ascending: true).limit(300);
    return rows.map(Message.fromJson).toList();
  }

  static Future<Message> send(String matchId, String body) async =>
      Message.fromJson(await sb.from('messages').insert({'match_id': matchId, 'sender': uid, 'body': body}).select().single());

  /// Photo or video: upload to the match's private folder, then post a message pointing at it.
  static Future<Message> sendMedia(String matchId, Uint8List bytes, String kind, String ext, String contentType, {int? duration}) async {
    final r = Random.secure();
    final id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final path = '$matchId/$id.$ext';
    await sb.storage.from('chat-media').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType, upsert: false));
    return Message.fromJson(await sb
        .from('messages')
        .insert({'match_id': matchId, 'sender': uid, 'body': '', 'kind': kind, 'media_path': path, 'media_meta': duration == null ? null : {'duration': duration}})
        .select()
        .single());
  }

  static final _mediaUrls = <String, (String, DateTime)>{};

  /// Short-lived private link to a chat photo or video (reused for most of its hour).
  static Future<String> mediaUrl(String path) async {
    final hit = _mediaUrls[path];
    if (hit != null && hit.$2.isAfter(DateTime.now())) return hit.$1;
    final url = await sb.storage.from('chat-media').createSignedUrl(path, 3600);
    _mediaUrls[path] = (url, DateTime.now().add(const Duration(minutes: 50)));
    return url;
  }

  /// Chat files of removed matches are deleted by an edge function (storage can't be cleared from SQL).
  static Future<void> cleanupMedia() async {
    try {
      await sb.functions.invoke('chat-media-cleanup', body: {});
    } catch (_) {/* retried on the next unmatch or deletion */}
  }

  // ----- calls: the WebRTC offer and answer travel through the calls table (migration 014) -----
  static Future<CallRecord> startCall(String matchId, bool video, String offer) async =>
      CallRecord.fromJson(Map<String, dynamic>.from(await sb.rpc('start_call', params: {'p_match': matchId, 'p_video': video, 'p_offer': offer})));
  static Future<CallRecord> updateCall(String id, String status, [String? answer]) async =>
      CallRecord.fromJson(Map<String, dynamic>.from(await sb.rpc('update_call', params: {'p_call': id, 'p_status': status, 'p_answer': answer})));
  static Future<CallRecord?> getCall(String id) async {
    final r = await sb.from('calls').select().eq('id', id).maybeSingle();
    return r == null ? null : CallRecord.fromJson(r);
  }

  static Future<List<CallRecord>> ringingCalls() async {
    final rows = await sb.rpc('my_ringing_calls');
    return (rows as List).map((r) => CallRecord.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  static Future<List<CallRecord>> callLog(String matchId) async {
    final rows = await sb.from('calls').select('id,match_id,caller,callee,video,status,created_at,answered_at,ended_at').eq('match_id', matchId).order('created_at', ascending: false).limit(40);
    return rows.map(CallRecord.fromJson).toList();
  }

  /// Calls to me (new and updated) and updates to calls I made. Returns a function that stops listening.
  static VoidCallback onCalls(void Function(CallRecord c) cb) {
    final me = uid!;
    void h(PostgresChangePayload p) => cb(CallRecord.fromJson(p.newRecord));
    final toMe = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'callee', value: me);
    final fromMe = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'caller', value: me);
    final ch = sb
        .channel('calls:$me')
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'calls', filter: toMe, callback: h)
        .onPostgresChanges(event: PostgresChangeEvent.update, schema: 'public', table: 'calls', filter: toMe, callback: h)
        .onPostgresChanges(event: PostgresChangeEvent.update, schema: 'public', table: 'calls', filter: fromMe, callback: h)
        .subscribe();
    return () => sb.removeChannel(ch);
  }

  /// Alerts for likes, matches and messages, written by database triggers (migration 017).
  static VoidCallback onNotifications(void Function(Map<String, dynamic> n) cb) {
    final me = uid!;
    final ch = sb
        .channel('notif:$me')
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'recipient', value: me),
            callback: (p) => cb(p.newRecord))
        .subscribe();
    return () => sb.removeChannel(ch);
  }

  static Future<void> markRead(String matchId) => sb.rpc('mark_read', params: {'p_match': matchId});
  static Future<void> unmatch(String matchId) async {
    await sb.rpc('unmatch', params: {'p_match': matchId});
    cleanupMedia();
  }
  static Future<void> block(String userId) => sb.from('blocks').insert({'blocker': uid, 'blocked': userId});
  static Future<void> report(String userId, String reason, String details) async {
    await sb.from('reports').insert({'reporter': uid, 'reported': userId, 'reason': reason, 'details': details.isEmpty ? null : details});
    try {
      await block(userId);
    } catch (_) {/* already blocked */}
  }

  static Future<void> deleteAccount() async {
    final me = uid!;
    final files = await sb.storage.from('photos').list(path: me);
    if (files.isNotEmpty) await sb.storage.from('photos').remove(files.map((f) => '$me/${f.name}').toList());
    final sent = await sb.from('messages').select('media_path').eq('sender', me).not('media_path', 'is', null).limit(1000);
    if (sent.isNotEmpty) {
      try {
        await sb.storage.from('chat-media').remove(sent.map((x) => '${x['media_path']}').toList());
      } catch (_) {/* the cleanup below catches anything left */}
    }
    await sb.rpc('delete_my_account');
    await cleanupMedia();
    await Cache.clear();
    await sb.auth.signOut();
  }

  /// Realtime updates for one chat. Returns a function that stops listening.
  static VoidCallback subscribe(String matchId, void Function(Message m) onInsert, VoidCallback onRead) {
    final filter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'match_id', value: matchId);
    final ch = sb
        .channel('chat:$matchId')
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'messages', filter: filter, callback: (p) => onInsert(Message.fromJson(p.newRecord)))
        .onPostgresChanges(event: PostgresChangeEvent.update, schema: 'public', table: 'messages', filter: filter, callback: (_) => onRead())
        .subscribe();
    return () => sb.removeChannel(ch);
  }
}

/// App-wide state: who is signed in, their profile and their matches.
class AppState extends ChangeNotifier {
  Session? session;
  Profile? me;
  List<MatchItem>? matches;
  bool booting = true;

  int get unreadChats => (matches ?? []).where((m) => m.unread > 0).length;

  Future<void> load(Session? s) async {
    final changed = s?.user.id != session?.user.id;
    session = s;
    if (changed) {
      Calls.watch(s != null);
      Alerts.watch(s != null);
    }
    if (s == null) {
      me = null;
      matches = null;
      notifyListeners();
      return;
    }
    if (changed) {
      matches = null;
      final cached = Cache.get('me');
      me = cached == null ? null : Profile.fromJson(Map<String, dynamic>.from(cached));
      notifyListeners();
    }
    try {
      me = await Api.me();
      await Cache.set('me', me!.toJson());
      Api.touch().catchError((_) {});
      Api.registerDevice(changed).catchError((_) {});
    } catch (_) {/* keep cached profile when offline */}
    notifyListeners();
  }

  void setMe(Profile p) {
    me = p;
    Cache.set('me', p.toJson());
    notifyListeners();
  }

  Future<List<MatchItem>?> refreshMatches() async {
    try {
      matches = await Api.matches();
      await Cache.set('matches', matches!.map((m) => m.toJson()).toList());
    } catch (_) {
      final c = Cache.get('matches');
      if (matches == null && c is List) matches = c.map((j) => MatchItem.fromRpc(Map<String, dynamic>.from(j))).toList();
    }
    notifyListeners();
    return matches;
  }

  void cachedMatches() {
    final c = Cache.get('matches');
    if (matches == null && c is List) matches = c.map((j) => MatchItem.fromRpc(Map<String, dynamic>.from(j))).toList();
  }

  void touch() => notifyListeners();
}

final app = AppState();
