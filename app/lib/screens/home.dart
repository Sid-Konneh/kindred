import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import '../ads.dart';
import '../alerts.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'matches.dart';
import 'profile.dart';
import 'sheets.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    app.cachedMatches();
    app.refreshMatches();
    Ads.init();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final unread = app.unreadChats;
        return Scaffold(
          body: Column(children: [
            Expanded(child: IndexedStack(index: _tab, children: const [DiscoverTab(), MatchesTab(), ProfileTab()])),
            const AdBanner(),
          ]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            backgroundColor: p.surface,
            indicatorColor: K.brand.withValues(alpha: .12),
            onDestinationSelected: (i) {
              setState(() => _tab = i);
              if (i == 1) app.refreshMatches();
            },
            destinations: [
              NavigationDestination(icon: KMark(size: 26, color: p.muted), selectedIcon: const KMark(size: 26), label: 'Discover'),
              NavigationDestination(
                icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), backgroundColor: K.brand, child: const Icon(Icons.chat_bubble_outline_rounded)),
                selectedIcon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), backgroundColor: K.brand, child: const Icon(Icons.chat_bubble_rounded, color: K.brand)),
                label: 'Matches',
              ),
              const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: K.brand), label: 'Profile'),
            ],
          ),
        );
      },
    );
  }
}

class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});
  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> with TickerProviderStateMixin {
  List<Profile> _feed = [];
  bool _loading = true, _fetching = false;
  Offset _drag = Offset.zero;
  int _photo = 0;
  late final AnimationController _fly = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final AnimationController _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  Animation<Offset>? _flyAnim, _backAnim;
  String? _flyAction;

  @override
  void initState() {
    super.initState();
    _load();
    _fly.addListener(() => setState(() => _drag = _flyAnim!.value));
    _back.addListener(() => setState(() => _drag = _backAnim!.value));
  }

  @override
  void dispose() {
    _fly.dispose();
    _back.dispose();
    super.dispose();
  }

  bool _recycled = false;
  final Set<String> _seenRound = {}; // swiped in this round, so a refill doesn't bring them straight back

  /// New people first. When there's nobody new, bring back people you passed on, reshuffled,
  /// so Discover never ends in a dead end. [startOver] is the "Start over" button.
  Future<void> _load({bool append = false, bool startOver = false}) async {
    if (_fetching) return;
    _fetching = true;
    if (!append) setState(() => _loading = true);
    try {
      final city = Cache.getPref('city', '');
      var list = startOver ? <Profile>[] : await Api.feed(city: city);
      var recycled = false;
      if (list.isEmpty) {
        list = await Api.feed(city: city, recycle: true);
        recycled = list.isNotEmpty;
      }
      if (!append) _seenRound.clear();
      final have = _feed.map((p) => p.id).toSet();
      if (!mounted) return;
      setState(() => _feed = append ? [..._feed, ...list.where((p) => !have.contains(p.id) && !_seenRound.contains(p.id))] : list);
      if (recycled && !_recycled) toast(context, "You've seen everyone new. Here are people you passed on, reshuffled.");
      _recycled = recycled;
      if (startOver && list.isEmpty) toast(context, "There's nobody to show again yet. Everyone you've seen, you liked or matched with.");
    } catch (e) {
      if (mounted) toast(context, friendly(e));
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _swipe(String action) async {
    if (_feed.isEmpty || _fly.isAnimating) return;
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final target = switch (action) { 'like' => Offset(w * 1.5, _drag.dy + 40), 'pass' => Offset(-w * 1.5, _drag.dy + 40), _ => Offset(_drag.dx, -h) };
    _flyAction = action;
    _flyAnim = Tween(begin: _drag, end: target).animate(CurvedAnimation(parent: _fly, curve: Curves.easeOut));
    HapticFeedback.lightImpact();
    await _fly.forward(from: 0);
    final p = _feed.removeAt(0);
    _seenRound.add(p.id);
    setState(() {
      _drag = Offset.zero;
      _photo = 0;
      _flyAction = null;
    });
    if (_feed.length < 4) _load(append: true);
    try {
      final matchId = await Api.swipe(p.id, action);
      if (matchId != null) Alerts.shownMatch = matchId;
      if (matchId != null && mounted) {
        await app.refreshMatches();
        if (mounted) showMatch(context, p, matchId);
      }
    } catch (e) {
      if (mounted) {
        toast(context, friendly(e));
        setState(() => _feed.insert(0, p));
      }
    }
  }

  void _release(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    if (_drag.dx > 110 || (_drag.dx > 45 && v.dx > 600)) { _swipe('like'); return; }
    if (_drag.dx < -110 || (_drag.dx < -45 && v.dx < -600)) { _swipe('pass'); return; }
    if (_drag.dy < -130 && _drag.dx.abs() < 90) { _swipe('super'); return; }
    _backAnim = Tween(begin: _drag, end: Offset.zero).animate(CurvedAnimation(parent: _back, curve: Curves.easeOutBack));
    _back.forward(from: 0);
  }

  Future<void> _openProfile(Profile p) async {
    final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileView(p: p, onAction: _swipe)));
    if (r == 'reported') setState(() => _feed.removeWhere((x) => x.id == p.id));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
          child: Row(children: [
            const Wordmark(size: 22),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Discovery settings',
              onPressed: () async {
                if (await filtersSheet(context)) {
                  _feed = [];
                  _load();
                }
              },
            ),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _loading && _feed.isEmpty ? const _DeckSkeleton() : _feed.isEmpty ? _empty() : _deck(),
          ),
        ),
        if (_feed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              RoundAction.pass(onTap: () => _swipe('pass')),
              const SizedBox(width: 18),
              RoundAction.superLike(onTap: () => _swipe('super')),
              const SizedBox(width: 18),
              RoundAction.like(onTap: () => _swipe('like')),
            ]),
          )
        else
          const SizedBox(height: 14),
      ]),
    );
  }

  Widget _deck() {
    final w = MediaQuery.of(context).size.width;
    final visible = _feed.take(3).toList();
    final progress = (_drag.distance / 150).clamp(0.0, 1.0);
    return Stack(children: [
      for (var i = visible.length - 1; i >= 0; i--)
        Positioned.fill(
          child: i == 0
              ? GestureDetector(
                  onPanUpdate: (d) {
                    if (!_fly.isAnimating) setState(() => _drag += d.delta);
                  },
                  onPanEnd: _release,
                  onTapUp: (d) {
                    final photos = visible[0].photos;
                    if (photos.length < 2) return;
                    setState(() => _photo = d.localPosition.dx < w / 3 ? math.max(0, _photo - 1) : math.min(photos.length - 1, _photo + 1));
                  },
                  child: Transform.translate(
                    offset: _drag,
                    child: Transform.rotate(angle: _drag.dx / 900, child: _SwipeCard(p: visible[0], photo: _photo, drag: _drag, action: _flyAction, onInfo: () => _openProfile(visible[0]))),
                  ),
                )
              : Transform.translate(
                  offset: Offset(0, (i - (i == 1 ? progress : 0)) * 12),
                  child: Transform.scale(scale: 1 - (i - (i == 1 ? progress : 0)) * .045, child: _SwipeCard(p: visible[i], photo: 0, drag: Offset.zero)),
                ),
        ),
    ]);
  }

  Widget _empty() {
    final p = Pal.of(context);
    final city = Cache.getPref('city', '');
    // Pull down to check for new people
    return RefreshIndicator(
      color: K.brand,
      onRefresh: () => _load(),
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(constraints: BoxConstraints(minHeight: box.maxHeight), child: Center(child: _emptyBody(p, city))),
        ),
      ),
    );
  }

  Widget _emptyBody(Pal p, String city) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Pulse(child: Avatar(app.me!, size: 76)),
          const SizedBox(height: 22),
          const Text("You've seen everyone for now", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            city.isNotEmpty
                ? "There's no one new in $city right now. Try all of Sierra Leone, or widen your age range."
                : 'New people join Kindred every day. Check back soon, or widen your filters.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          SizedBox(width: 220, child: GradButton('Start over', icon: Icons.refresh_rounded, height: 48, onPressed: () => _load(startOver: true))),
          const SizedBox(height: 10),
          Row(mainAxisSize: MainAxisSize.min, children: [
            FilledButton.tonalIcon(
              onPressed: () async {
                if (await filtersSheet(context)) _load();
              },
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Adjust filters'),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: () => _load(), child: const Text('Check for new people')),
          ]),
          const SizedBox(height: 6),
          Text('or pull down to refresh', style: TextStyle(color: p.muted, fontSize: 12.5)),
        ]),
      ),
    );
  }
}

class _SwipeCard extends StatelessWidget {
  final Profile p;
  final int photo;
  final Offset drag;
  final String? action;
  final VoidCallback? onInfo;
  const _SwipeCard({required this.p, required this.photo, required this.drag, this.action, this.onInfo});

  @override
  Widget build(BuildContext context) {
    final up = drag.dy < -40 && drag.dx.abs() < 80;
    final like = action == 'like' ? 1.0 : up ? 0.0 : (drag.dx / 100).clamp(0.0, 1.0);
    final nope = action == 'pass' ? 1.0 : up ? 0.0 : (-drag.dx / 100).clamp(0.0, 1.0);
    final sup = action == 'super' ? 1.0 : up ? (-drag.dy / 120).clamp(0.0, 1.0) : 0.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .28), blurRadius: 40, offset: const Offset(0, 20), spreadRadius: -18)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        p.photos.isEmpty ? ArtFill(id: p.id, name: p.name, fontSize: 120) : NetPhoto(p.photos[photo.clamp(0, p.photos.length - 1)]),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x40000000), Colors.transparent, Colors.transparent, Color(0xC7000000)], stops: [0, .18, .45, 1]),
          ),
        ),
        if (p.photos.length > 1)
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Row(children: [
              for (var k = 0; k < p.photos.length; k++)
                Expanded(child: Container(height: 4, margin: const EdgeInsets.symmetric(horizontal: 2.5), decoration: BoxDecoration(color: Colors.white.withValues(alpha: k == photo ? 1 : .35), borderRadius: BorderRadius.circular(4)))),
            ]),
          ),
        Positioned(top: 44, left: 22, child: _Stamp('LIKE', const Color(0xFF3BE0A8), -.28, like)),
        Positioned(top: 44, right: 22, child: _Stamp('NOPE', const Color(0xFFFF5A76), .28, nope)),
        Positioned(bottom: 200, left: 0, right: 0, child: Center(child: _Stamp('SUPER', const Color(0xFF5AB0FF), -.1, sup))),
        Positioned(
          left: 18,
          right: 18,
          bottom: 22,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p.recentlyActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: K.good.withValues(alpha: .9), borderRadius: BorderRadius.circular(99)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(radius: 3.5, backgroundColor: Colors.white),
                  SizedBox(width: 6),
                  Text('Recently active', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(
                    TextSpan(text: p.name, children: [TextSpan(text: '  ${p.age ?? ''}', style: const TextStyle(fontWeight: FontWeight.w500))]),
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.place_outlined, color: Colors.white, size: 17),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text([p.city ?? 'Sierra Leone', if ((p.job ?? '').isNotEmpty) p.job!].join(' · '),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: p.interests.take(3).map((t) => InfoChip(t, glass: true)).toList()),
                ]),
              ),
              if (onInfo != null)
                Semantics(
                  button: true,
                  label: 'More about ${p.name}',
                  child: GestureDetector(
                    onTap: onInfo,
                    child: Container(width: 42, height: 42, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.keyboard_arrow_up_rounded, color: K.ink)),
                  ),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Stamp extends StatelessWidget {
  final String text;
  final Color color;
  final double angle, opacity;
  const _Stamp(this.text, this.color, this.angle, this.opacity);
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: angle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: color, width: 4), borderRadius: BorderRadius.circular(12)),
            child: Text(text, style: TextStyle(color: color, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ),
        ),
      );
}

class _DeckSkeleton extends StatelessWidget {
  const _DeckSkeleton();
  @override
  Widget build(BuildContext context) => Silver(
        child: Stack(children: [
          Positioned.fill(child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)))),
        ]),
      );
}

class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 130,
        height: 130,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Stack(alignment: Alignment.center, children: [
            for (final off in [0.0, .5])
              Builder(builder: (_) {
                final t = (_c.value + off) % 1;
                return Transform.scale(
                  scale: .6 + .9 * t,
                  child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: K.brand.withValues(alpha: .18 * (1 - t)))),
                );
              }),
            widget.child,
          ]),
        ),
      );
}

void showMatch(BuildContext context, Profile p, String matchId) {
  HapticFeedback.mediumImpact();
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, a1, a2) => _MatchOverlay(p: p, matchId: matchId),
    transitionBuilder: (ctx, a, _, child) => FadeTransition(opacity: a, child: child),
  );
}

class _MatchOverlay extends StatelessWidget {
  final Profile p;
  final String matchId;
  const _MatchOverlay({required this.p, required this.matchId});
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        decoration: const BoxDecoration(gradient: K.grad),
        padding: const EdgeInsets.all(26),
        child: SafeArea(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text("It's a match!", style: serif(50, color: Colors.white, style: FontStyle.italic, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('You and ${p.name} like each other.', style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 30),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Transform.translate(offset: const Offset(14, 0), child: Transform.rotate(angle: -.14, child: Avatar(app.me!, size: 124, border: 4))),
              Transform.translate(offset: const Offset(-14, 0), child: Transform.rotate(angle: .14, child: Avatar(p, size: 124, border: 4))),
            ]),
            const SizedBox(height: 34),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: K.brand, shape: const StadiumBorder(), textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: Text('Say hello to ${p.name}'),
                onPressed: () {
                  Navigator.pop(context);
                  final m = (app.matches ?? []).where((x) => x.id == matchId).firstOrNull;
                  if (m != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(match: m)));
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70, width: 1.5), shape: const StadiumBorder(), textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep swiping'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
