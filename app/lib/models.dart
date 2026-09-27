import 'dart:typed_data';

int? ageFrom(DateTime? b) {
  if (b == null) return null;
  final n = DateTime.now();
  var a = n.year - b.year;
  if (n.month < b.month || (n.month == b.month && n.day < b.day)) a--;
  return a;
}

List<String> _strings(dynamic v) => v is List ? v.map((e) => '$e').toList() : <String>[];
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

class Profile {
  final String id;
  String name;
  DateTime? birthdate;
  int? age;
  String? gender;
  String showMe;
  String? city, job, lookingFor, religion;
  String bio;
  List<String> interests, languages, photos;
  int ageMin, ageMax;
  bool onboarded;
  DateTime? lastActive;

  Profile({
    required this.id,
    required this.name,
    this.birthdate,
    this.age,
    this.gender,
    this.showMe = 'everyone',
    this.city,
    this.job,
    this.lookingFor,
    this.religion,
    this.bio = '',
    List<String>? interests,
    List<String>? languages,
    List<String>? photos,
    this.ageMin = 18,
    this.ageMax = 45,
    this.onboarded = false,
    this.lastActive,
  })  : interests = interests ?? [],
        languages = languages ?? [],
        photos = photos ?? [];

  factory Profile.fromJson(Map<String, dynamic> j) {
    final bd = j['birthdate'] == null ? null : DateTime.tryParse('${j['birthdate']}');
    return Profile(
      id: '${j['id']}',
      name: '${j['name'] ?? ''}',
      birthdate: bd,
      age: (j['age'] as num?)?.toInt() ?? ageFrom(bd),
      gender: j['gender'],
      showMe: j['show_me'] ?? 'everyone',
      city: j['city'],
      job: j['job'],
      lookingFor: j['looking_for'],
      religion: j['religion'],
      bio: j['bio'] ?? '',
      interests: _strings(j['interests']),
      languages: _strings(j['languages']),
      photos: _strings(j['photos']),
      ageMin: (j['age_min'] as num?)?.toInt() ?? 18,
      ageMax: (j['age_max'] as num?)?.toInt() ?? 45,
      onboarded: j['onboarded'] == true,
      lastActive: _date(j['last_active']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'birthdate': birthdate?.toIso8601String().substring(0, 10),
        'age': age,
        'gender': gender,
        'show_me': showMe,
        'city': city,
        'job': job,
        'looking_for': lookingFor,
        'religion': religion,
        'bio': bio,
        'interests': interests,
        'languages': languages,
        'photos': photos,
        'age_min': ageMin,
        'age_max': ageMax,
        'onboarded': onboarded,
        'last_active': lastActive?.toUtc().toIso8601String(),
      };

  bool get recentlyActive => lastActive != null && DateTime.now().difference(lastActive!).inHours < 3;
}

class MatchItem {
  final String id;
  final DateTime createdAt;
  DateTime? lastMessageAt;
  String? lastBody, lastSender;
  int unread;
  final Profile other;

  MatchItem({required this.id, required this.createdAt, this.lastMessageAt, this.lastBody, this.lastSender, this.unread = 0, required this.other});

  factory MatchItem.fromRpc(Map<String, dynamic> j) => MatchItem(
        id: '${j['match_id'] ?? j['id']}',
        createdAt: _date(j['created_at']) ?? DateTime.now(),
        lastMessageAt: _date(j['last_message_at']),
        lastBody: j['last_body'],
        lastSender: j['last_sender'],
        unread: (j['unread'] as num?)?.toInt() ?? 0,
        other: Profile.fromJson(Map<String, dynamic>.from(j['other'] as Map)),
      );

  Map<String, dynamic> toJson() => {
        'match_id': id,
        'created_at': createdAt.toUtc().toIso8601String(),
        'last_message_at': lastMessageAt?.toUtc().toIso8601String(),
        'last_body': lastBody,
        'last_sender': lastSender,
        'unread': unread,
        'other': other.toJson(),
      };
}

class Message {
  final String id, matchId, sender, body;

  /// 'text', 'image' or 'video'. Photos and videos live in the private chat-media bucket at [mediaPath].
  final String kind;
  final String? mediaPath;
  final DateTime createdAt;
  DateTime? readAt;
  bool pending, failed;

  /// Only on a photo or video this phone is still sending: its bytes or file, shown until the upload finishes.
  final Uint8List? localBytes;
  final String? localFile;

  Message({required this.id, required this.matchId, required this.sender, required this.body, required this.createdAt, this.kind = 'text', this.mediaPath, this.readAt, this.pending = false, this.failed = false, this.localBytes, this.localFile});

  bool get isMedia => kind == 'image' || kind == 'video';

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: '${j['id']}',
        matchId: '${j['match_id']}',
        sender: '${j['sender']}',
        body: '${j['body'] ?? ''}',
        kind: '${j['kind'] ?? 'text'}',
        mediaPath: j['media_path'] as String?,
        createdAt: _date(j['created_at']) ?? DateTime.now(),
        readAt: _date(j['read_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'match_id': matchId,
        'sender': sender,
        'body': body,
        'kind': kind,
        'media_path': mediaPath,
        'created_at': createdAt.toUtc().toIso8601String(),
        'read_at': readAt?.toUtc().toIso8601String(),
      };
}

/// One voice or video call between two matches (the calls table). [offer] and [answer] carry the WebRTC setup.
class CallRecord {
  final String id, matchId, caller, callee, status;
  final bool video;
  final String? offer, answer;
  final DateTime createdAt;
  final DateTime? answeredAt, endedAt;

  CallRecord({required this.id, required this.matchId, required this.caller, required this.callee, required this.status, required this.video, this.offer, this.answer, required this.createdAt, this.answeredAt, this.endedAt});

  factory CallRecord.fromJson(Map<String, dynamic> j) => CallRecord(
        id: '${j['id']}',
        matchId: '${j['match_id']}',
        caller: '${j['caller']}',
        callee: '${j['callee']}',
        status: '${j['status']}',
        video: j['video'] == true,
        offer: j['offer'] as String?,
        answer: j['answer'] as String?,
        createdAt: _date(j['created_at']) ?? DateTime.now(),
        answeredAt: _date(j['answered_at']),
        endedAt: _date(j['ended_at']),
      );
}
