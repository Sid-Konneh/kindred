import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sheets.dart';

const _icebreakers = ["What's your favourite spot in Salone?", 'Jollof or cassava leaves? 😄', 'What does a perfect weekend look like for you?', 'What are you looking for on Kindred?'];

class MatchesTab extends StatelessWidget {
  const MatchesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return SafeArea(
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final list = app.matches;
          return RefreshIndicator(
            color: K.brand,
            onRefresh: app.refreshMatches,
            child: CustomScrollView(slivers: [
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(20, 14, 20, 4), child: Text('Matches', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)))),
              if (list == null) const SliverToBoxAdapter(child: _MatchesSkeleton()),
              if (list != null && list.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const KMark(size: 64),
                        const SizedBox(height: 16),
                        const Text('No matches yet', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text("When someone you like likes you back, they'll show up here. Keep swiping!", textAlign: TextAlign.center, style: TextStyle(color: p.muted, height: 1.5)),
                      ]),
                    ),
                  ),
                ),
              if (list != null && list.isNotEmpty) ..._sections(context, list),
            ]),
          );
        },
      ),
    );
  }

  List<Widget> _sections(BuildContext context, List<MatchItem> list) {
    final p = Pal.of(context);
    final fresh = list.where((m) => m.lastMessageAt == null).toList();
    final convos = list.where((m) => m.lastMessageAt != null).toList();
    Widget title(String t, [int? n]) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(children: [
            Text(t.toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1, color: p.muted)),
            if (n != null) ...[const SizedBox(width: 8), _badge(n)],
          ]),
        );
    void open(MatchItem m) => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(match: m)));
    return [
      if (fresh.isNotEmpty) ...[
        SliverToBoxAdapter(child: title('New matches', fresh.length)),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: fresh.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => open(fresh[i]),
                child: Column(children: [
                  Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(gradient: K.grad, shape: BoxShape.circle), child: Avatar(fresh[i].other, size: 68, border: 3, borderColor: p.bg)),
                  const SizedBox(height: 6),
                  SizedBox(width: 76, child: Text(fresh[i].other.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                ]),
              ),
            ),
          ),
        ),
      ],
      SliverToBoxAdapter(child: title('Messages')),
      if (convos.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Text('Say hello to one of your new matches — a simple "Kushɛ!" works wonders.', textAlign: TextAlign.center, style: TextStyle(color: p.muted, height: 1.5)),
          ),
        ),
      SliverList.builder(
        itemCount: convos.length,
        itemBuilder: (_, i) {
          final m = convos[i];
          return InkWell(
            onTap: () => open(m),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(children: [
                Avatar(m.other, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(m.other.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                      if (m.other.recentlyActive) ...[const SizedBox(width: 8), const CircleAvatar(radius: 4, backgroundColor: K.good)],
                    ]),
                    const SizedBox(height: 3),
                    Text('${m.lastSender == Api.uid ? 'You: ' : ''}${m.lastBody ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: m.unread > 0 ? p.text : p.muted, fontWeight: m.unread > 0 ? FontWeight.w700 : FontWeight.w500, fontSize: 14.5)),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fmtWhen(m.lastMessageAt), style: TextStyle(fontSize: 12, color: p.muted)),
                  const SizedBox(height: 6),
                  if (m.unread > 0) _badge(m.unread),
                ]),
              ]),
            ),
          );
        },
      ),
    ];
  }

  Widget _badge(int n) => Container(
        constraints: const BoxConstraints(minWidth: 18),
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: K.brand, borderRadius: BorderRadius.circular(9)),
        child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

class _MatchesSkeleton extends StatelessWidget {
  const _MatchesSkeleton();
  @override
  Widget build(BuildContext context) => Silver(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Bone(width: 110, height: 12),
            const SizedBox(height: 14),
            Row(children: List.generate(4, (_) => const Padding(padding: EdgeInsets.only(right: 14), child: Bone(width: 70, height: 70, radius: 35)))),
            const SizedBox(height: 24),
            const Bone(width: 90, height: 12),
            for (var i = 0; i < 5; i++)
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Row(children: [
                  Bone(width: 60, height: 60, radius: 30),
                  SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Bone(width: 120), SizedBox(height: 10), Bone(height: 12)])),
                ]),
              ),
          ]),
        ),
      );
}

class ChatScreen extends StatefulWidget {
  final MatchItem match;
  const ChatScreen({super.key, required this.match});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Message>? _msgs;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  VoidCallback? _unsub;
  MatchItem get m => widget.match;

  @override
  void initState() {
    super.initState();
    final cached = Cache.get('msgs:${m.id}');
    if (cached is List) _msgs = cached.map((j) => Message.fromJson(Map<String, dynamic>.from(j))).toList();
    _unsub = Api.subscribe(m.id, _onInsert, _reload);
    _reload();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _unsub?.call();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await Api.messages(m.id);
      if (!mounted) return;
      final pending = (_msgs ?? []).where((x) => (x.pending || x.failed) && !list.any((y) => y.sender == x.sender && y.body == x.body));
      setState(() => _msgs = [...list, ...pending]);
      Cache.set('msgs:${m.id}', list.length > 80 ? list.sublist(list.length - 80).map((x) => x.toJson()).toList() : list.map((x) => x.toJson()).toList());
      _toBottom();
      if (list.any((x) => x.sender != Api.uid && x.readAt == null)) {
        await Api.markRead(m.id);
        m.unread = 0;
        app.touch();
      }
    } catch (e) {
      if (mounted && _msgs == null) {
        setState(() => _msgs = []);
        toast(context, friendly(e));
      }
    }
  }

  void _onInsert(Message msg) {
    if (!mounted) return;
    final list = _msgs ?? [];
    if (list.any((x) => x.id == msg.id)) return;
    setState(() {
      list.removeWhere((x) => x.pending && x.sender == msg.sender && x.body == msg.body);
      list.add(msg);
      _msgs = list;
    });
    _toBottom();
    if (msg.sender != Api.uid) Api.markRead(m.id).catchError((_) {});
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  Future<void> _send([String? text]) async {
    final body = (text ?? _input.text).trim();
    if (body.isEmpty) return;
    if (text == null) _input.clear();
    final temp = Message(id: 'tmp-${DateTime.now().microsecondsSinceEpoch}', matchId: m.id, sender: Api.uid!, body: body, createdAt: DateTime.now(), pending: true);
    setState(() => _msgs = [...?_msgs, temp]);
    _toBottom();
    try {
      final saved = await Api.send(m.id, body);
      if (!mounted) return;
      setState(() {
        _msgs!.remove(temp);
        if (!_msgs!.any((x) => x.id == saved.id)) _msgs!.add(saved);
      });
      m
        ..lastMessageAt = saved.createdAt
        ..lastBody = saved.body
        ..lastSender = saved.sender;
      app.touch();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        temp.pending = false;
        temp.failed = true;
      });
      toast(context, friendly(e));
    }
  }

  Future<void> _menu() async {
    final o = m.other;
    final choice = await kSheet<String>(context, (c) {
      Widget row(String v, IconData ic, String t, {bool danger = false}) => ListTile(
            leading: Icon(ic, color: danger ? K.danger : null),
            title: Text(t, style: TextStyle(fontWeight: FontWeight.w600, color: danger ? K.danger : null)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(c, v),
          );
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text(o.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        row('view', Icons.person_outline, 'View profile'),
        row('unmatch', Icons.link_off, 'Unmatch'),
        row('block', Icons.block, 'Block ${o.name}', danger: true),
        row('report', Icons.flag_outlined, 'Report ${o.name}', danger: true),
      ]);
    });
    if (!mounted || choice == null) return;
    try {
      switch (choice) {
        case 'view':
          await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileView(p: o)));
        case 'unmatch':
          if (await confirmSheet(context, 'Unmatch ${o.name}?', "You'll both disappear from each other's matches and this chat will be deleted.", 'Unmatch')) {
            await Api.unmatch(m.id);
            _leave('Unmatched');
          }
        case 'block':
          if (await confirmSheet(context, 'Block ${o.name}?', "They won't be able to see you or message you again. They won't be told.", 'Block')) {
            await Api.block(o.id);
            _leave('Blocked');
          }
        case 'report':
          if (await reportSheet(context, o)) _leave(null);
      }
    } catch (e) {
      if (mounted) toast(context, friendly(e));
    }
  }

  void _leave(String? msg) {
    app.matches?.removeWhere((x) => x.id == m.id);
    app.touch();
    if (msg != null) toast(context, msg);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context), o = m.other;
    final msgs = _msgs;
    final lastMine = msgs?.lastWhere((x) => x.sender == Api.uid, orElse: () => Message(id: '', matchId: '', sender: '', body: '', createdAt: DateTime(0)));
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileView(p: o))),
          child: Row(children: [
            Avatar(o, size: 42),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
                Text(seenText(o.lastActive).isEmpty ? (o.city ?? '') : seenText(o.lastActive), style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
        actions: [IconButton(icon: const Icon(Icons.more_vert), tooltip: 'More options', onPressed: _menu)],
        shape: Border(bottom: BorderSide(color: p.line)),
      ),
      body: Column(children: [
        Expanded(
          child: msgs == null
              ? Silver(
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    for (var i = 0; i < 6; i++)
                      Align(alignment: i.isOdd ? Alignment.centerRight : Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Bone(width: [180.0, 130.0, 220.0, 110.0, 170.0, 140.0][i], height: 40, radius: 20))),
                  ]),
                )
              : ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(14, 14, 14, 8), children: [
                  _intro(p),
                  ..._bubbles(p, msgs, lastMine),
                ]),
        ),
        if (msgs != null && msgs.isEmpty)
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              itemCount: _icebreakers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(label: Text(_icebreakers[i]), onPressed: () => _send(_icebreakers[i]), shape: const StadiumBorder()),
            ),
          ),
        Container(
          padding: EdgeInsets.fromLTRB(10, 8, 10, 10 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message ${o.name}…',
                  counterText: '',
                  fillColor: p.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: p.line, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: p.line, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: K.brand, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Opacity(
              opacity: _input.text.trim().isEmpty ? .45 : 1,
              child: GestureDetector(
                onTap: _input.text.trim().isEmpty ? null : _send,
                child: Container(width: 46, height: 46, decoration: const BoxDecoration(gradient: K.grad, shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Colors.white, size: 20)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _intro(Pal p) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(children: [
          Avatar(m.other, size: 84),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(text: 'You matched with ', children: [
              TextSpan(text: m.other.name, style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
              TextSpan(text: ' · ${fmtDay(m.createdAt).toLowerCase()}'),
            ]),
            style: TextStyle(color: p.muted, fontSize: 14),
          ),
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(14)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.verified_user_outlined, color: K.good, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'Stay safe. ', style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
                    const TextSpan(text: "Keep chats on Kindred until you trust someone. Never send money or Orange Money / Afrimoney to someone you haven't met."),
                  ]),
                  style: TextStyle(color: p.muted, fontSize: 13, height: 1.45),
                ),
              ),
            ]),
          ),
        ]),
      );

  List<Widget> _bubbles(Pal p, List<Message> msgs, Message? lastMine) {
    final out = <Widget>[];
    DateTime? lastDay;
    for (final msg in msgs) {
      final day = DateTime(msg.createdAt.year, msg.createdAt.month, msg.createdAt.day);
      if (lastDay != day) {
        out.add(Padding(padding: const EdgeInsets.fromLTRB(0, 14, 0, 8), child: Center(child: Text(fmtDay(msg.createdAt), style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w700)))));
        lastDay = day;
      }
      final mine = msg.sender == Api.uid;
      out.add(Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Opacity(
          opacity: msg.pending ? .65 : 1,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: mine && !msg.failed ? K.grad : null,
              color: msg.failed ? K.danger : mine ? null : p.surface2,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(mine ? 20 : 6),
                bottomRight: Radius.circular(mine ? 6 : 20),
              ),
            ),
            child: Text(msg.body, style: TextStyle(color: mine ? Colors.white : p.text, fontSize: 15.5, height: 1.4)),
          ),
        ),
      ));
      if (identical(msg, lastMine)) {
        out.add(Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
            child: Text(
              msg.failed ? 'Not sent' : msg.pending ? 'Sending…' : msg.readAt != null ? 'Seen' : 'Sent ${fmtWhen(msg.createdAt)}',
              style: TextStyle(color: p.muted, fontSize: 11.5),
            ),
          ),
        ));
      }
    }
    return out;
  }
}
