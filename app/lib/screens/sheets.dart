import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth.dart';

const _safety = [
  ('Meet in public', 'For the first few dates, meet somewhere busy in daylight — a restaurant, café or popular beach spot. Never at their home or yours.'),
  ('Tell a friend', "Share who you're meeting, where and when with someone you trust. Share your live location if you can."),
  ('Get there yourself', 'Arrange your own transport — your own okada, keke or taxi — so you can leave whenever you want.'),
  ('Never send money', 'No genuine match needs your money. Report anyone who asks for cash, Orange Money, Afrimoney, airtime or "transport fare".'),
  ('Protect your details', "Don't share your home address, workplace or bank details until you truly know someone."),
  ('Trust your instincts', "If something feels wrong, leave. You can unmatch, block and report anyone at any time — they won't be told who reported them."),
];
const _guidelines = [
  ('Be real', 'Use your own name, age and recent photos. Fake profiles are removed.'),
  ('18+ only', 'Kindred is only for adults. Report anyone who looks under 18.'),
  ('Be respectful', 'No harassment, hate, threats or pressure. No means no.'),
  ('Keep it clean', 'No nudity, violence or explicit content in photos or messages.'),
  ('No scams or selling', 'No asking for money, promoting businesses or sharing links to other services.'),
];

Future<T?> kSheet<T>(BuildContext context, Widget Function(BuildContext) builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: builder(ctx),
      ),
    );

Widget _tips(BuildContext context, String title, String intro, List<(String, String)> items) {
  final p = Pal.of(context);
  return SingleChildScrollView(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(intro, style: TextStyle(color: p.muted, fontSize: 14)),
      const SizedBox(height: 6),
      for (var i = 0; i < items.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: i == items.length - 1 ? null : Border(bottom: BorderSide(color: p.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: K.brand, shape: BoxShape.circle),
              child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${items[i].$1}\n', style: const TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: items[i].$2),
              ]), style: const TextStyle(height: 1.5, fontSize: 14.5)),
            ),
          ]),
        ),
      const SizedBox(height: 10),
      GhostButton('Got it', filled: true, onPressed: () => Navigator.pop(context)),
    ]),
  );
}

void showSafety(BuildContext context) => kSheet(context, (c) => _tips(c, 'Dating safety tips', 'Most people on Kindred are genuine. These habits keep it that way.', _safety));
void showGuidelines(BuildContext context) => kSheet(context, (c) => _tips(c, 'Community guidelines', 'Kindred works because members treat each other with respect.', _guidelines));

Future<bool> confirmSheet(BuildContext context, String title, String text, String action) async {
  final r = await kSheet<bool>(context, (c) {
    final p = Pal.of(c);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(text, style: TextStyle(color: p.muted)),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: K.danger, shape: const StadiumBorder()),
          onPressed: () => Navigator.pop(c, true),
          child: Text(action, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
      ),
      const SizedBox(height: 10),
      GhostButton('Cancel', onPressed: () => Navigator.pop(c, false)),
    ]);
  });
  return r ?? false;
}

/// Returns true when a report was sent (the person is also blocked).
Future<bool> reportSheet(BuildContext context, Profile who) async {
  var reason = reportReasons.first;
  final details = TextEditingController();
  var busy = false;
  final r = await kSheet<bool>(context, (c) {
    return StatefulBuilder(builder: (c, set) {
      final p = Pal.of(c);
      return SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Report ${who.name}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text("Your report is confidential. We'll also block them for you.", style: TextStyle(color: p.muted)),
          const SizedBox(height: 10),
          RadioGroup<String>(
            groupValue: reason,
            onChanged: (v) => set(() => reason = v ?? reason),
            child: Column(children: [
              for (final rr in reportReasons)
                RadioListTile<String>(value: rr, title: Text(rr, style: const TextStyle(fontWeight: FontWeight.w600)), contentPadding: EdgeInsets.zero, activeColor: K.brand),
            ]),
          ),
          TextField(controller: details, maxLength: 1000, maxLines: 3, decoration: const InputDecoration(hintText: 'Anything else? (optional)')),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: K.danger, shape: const StadiumBorder()),
              onPressed: busy
                  ? null
                  : () async {
                      set(() => busy = true);
                      try {
                        await Api.report(who.id, reason, details.text.trim());
                        if (c.mounted) Navigator.pop(c, true);
                      } catch (e) {
                        set(() => busy = false);
                        if (c.mounted) toast(c, friendly(e));
                      }
                    },
              child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Send report', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ]),
      );
    });
  });
  if (r == true && context.mounted) toast(context, "Thanks for telling us. We'll review this report.");
  return r == true;
}

/// Discovery settings. Returns true if they changed.
Future<bool> filtersSheet(BuildContext context) async {
  final me = app.me!;
  var showMe = me.showMe;
  var range = RangeValues(me.ageMin.toDouble(), me.ageMax.clamp(18, 70).toDouble());
  var city = Cache.getPref('city', '');
  var busy = false;
  final r = await kSheet<bool>(context, (c) {
    return StatefulBuilder(builder: (c, set) {
      final p = Pal.of(c);
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Discovery settings', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        Text("Who you'd like to see on Kindred.", style: TextStyle(color: p.muted)),
        const FieldLabel('Show me'),
        Segmented(options: const [('women', 'Women'), ('men', 'Men'), ('everyone', 'Everyone')], value: showMe, onChanged: (v) => set(() => showMe = v)),
        FieldLabel('Age range', trailing: '${range.start.round()} – ${range.end.round()}${range.end >= 70 ? '+' : ''}'),
        RangeSlider(values: range, min: 18, max: 70, divisions: 52, activeColor: K.brand, onChanged: (v) => set(() => range = v)),
        const FieldLabel('Location'),
        DropdownButtonFormField<String>(
          initialValue: city,
          items: [const DropdownMenuItem(value: '', child: Text('Anywhere in Sierra Leone')), ...cities.map((x) => DropdownMenuItem(value: x, child: Text(x)))],
          onChanged: (v) => set(() => city = v ?? ''),
        ),
        const SizedBox(height: 20),
        GradButton('Show people', busy: busy, onPressed: () async {
          set(() => busy = true);
          try {
            app.setMe(await Api.saveProfile({'show_me': showMe, 'age_min': range.start.round(), 'age_max': range.end.round()}));
            await Cache.setPref('city', city);
            if (c.mounted) Navigator.pop(c, true);
          } catch (e) {
            set(() => busy = false);
            if (c.mounted) toast(c, friendly(e));
          }
        }),
      ]);
    });
  });
  return r == true;
}

Future<void> changePasswordSheet(BuildContext context) async {
  final pw = TextEditingController(), confirm = TextEditingController();
  String? err;
  var busy = false;
  await kSheet(context, (c) => StatefulBuilder(builder: (c, set) {
        return SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Change password', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            LabeledField('New password', child: PasswordField(controller: pw, showStrength: true)),
            LabeledField('Confirm new password', child: PasswordField(controller: confirm)),
            FormError(err),
            const SizedBox(height: 18),
            GradButton('Update password', busy: busy, onPressed: () async {
              if (passwordStrength(pw.text) < 2) return set(() => err = 'Use at least 8 characters with letters and numbers.');
              if (pw.text != confirm.text) return set(() => err = "The passwords don't match.");
              set(() {
                err = null;
                busy = true;
              });
              try {
                await Api.updatePassword(pw.text);
                if (c.mounted) {
                  Navigator.pop(c);
                  toast(context, 'Password updated');
                }
              } catch (e) {
                set(() {
                  busy = false;
                  err = friendly(e);
                });
              }
            }),
          ]),
        );
      }));
}

Future<void> deleteAccountSheet(BuildContext context) async {
  final ctl = TextEditingController();
  String? err;
  var busy = false;
  await kSheet(context, (c) => StatefulBuilder(builder: (c, set) {
        final p = Pal.of(c);
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Delete your account?', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text("This permanently deletes your profile, photos, matches and messages. It can't be undone.", style: TextStyle(color: p.muted)),
          LabeledField('Type DELETE to confirm', child: TextField(controller: ctl, textCapitalization: TextCapitalization.characters, autocorrect: false)),
          FormError(err),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: K.danger, shape: const StadiumBorder()),
              onPressed: busy
                  ? null
                  : () async {
                      if (ctl.text.trim().toUpperCase() != 'DELETE') return set(() => err = 'Type DELETE to confirm.');
                      set(() => busy = true);
                      try {
                        await Api.deleteAccount();
                        if (c.mounted) Navigator.pop(c);
                      } catch (e) {
                        set(() {
                          busy = false;
                          err = friendly(e);
                        });
                      }
                    },
              child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Delete my account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ]);
      }));
}

/// Full-screen profile. [actions] adds pass/like buttons at the bottom (used from Discover).
class ProfileView extends StatefulWidget {
  final Profile p;
  final bool isSelf;
  final void Function(String action)? onAction;
  const ProfileView({super.key, required this.p, this.isSelf = false, this.onAction});
  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    final p = widget.p, pal = Pal.of(context);
    Widget fact(IconData ic, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [Icon(ic, size: 21, color: pal.muted), const SizedBox(width: 10), Expanded(child: Text(t, style: TextStyle(color: pal.muted, fontWeight: FontWeight.w600, fontSize: 15)))]),
        );
    Widget heading(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
          child: Text(t.toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1, color: pal.muted)),
        );
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Stack(children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: GestureDetector(
                onTapUp: (d) {
                  if (p.photos.length < 2) return;
                  final w = MediaQuery.of(context).size.width;
                  setState(() => _i = d.localPosition.dx < w / 3 ? (_i - 1).clamp(0, p.photos.length - 1) : (_i + 1).clamp(0, p.photos.length - 1));
                },
                child: p.photos.isEmpty ? ArtFill(id: p.id, name: p.name) : NetPhoto(p.photos[_i]),
              ),
            ),
            if (p.photos.length > 1)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 60,
                child: Row(children: [
                  for (var k = 0; k < p.photos.length; k++)
                    Expanded(child: Container(height: 4, margin: const EdgeInsets.symmetric(horizontal: 2.5), decoration: BoxDecoration(color: Colors.white.withValues(alpha: k == _i ? 1 : .4), borderRadius: BorderRadius.circular(4)))),
                ]),
              ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: .5)),
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ]),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          sliver: SliverList.list(children: [
            Text('${p.name}, ${p.age ?? ''}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            if (p.lastActive != null) Text(seenText(p.lastActive), style: TextStyle(color: pal.muted, fontSize: 14)),
            const SizedBox(height: 14),
            fact(Icons.place_outlined, p.city ?? 'Sierra Leone'),
            if ((p.job ?? '').isNotEmpty) fact(Icons.work_outline, p.job!),
            if (p.lookingFor != null) fact(Icons.search, 'Looking for: ${lookingLabel(p.lookingFor).toLowerCase()}'),
            if (p.religion != null && p.religion != 'prefer_not') fact(Icons.public, religionLabel(p.religion)),
            if (p.bio.isNotEmpty) ...[heading('About'), Text(p.bio, style: const TextStyle(fontSize: 15.5, height: 1.55))],
            if (p.interests.isNotEmpty) ...[heading('Interests'), Wrap(spacing: 8, runSpacing: 8, children: p.interests.map((t) => InfoChip(t)).toList())],
            if (p.languages.isNotEmpty) ...[heading('Speaks'), Wrap(spacing: 8, runSpacing: 8, children: p.languages.map((t) => InfoChip(t)).toList())],
            if (widget.onAction != null) ...[
              const SizedBox(height: 22),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                RoundAction.pass(onTap: () => _act('pass')),
                const SizedBox(width: 18),
                RoundAction.superLike(onTap: () => _act('super')),
                const SizedBox(width: 18),
                RoundAction.like(onTap: () => _act('like')),
              ]),
            ],
            if (!widget.isSelf) ...[
              const SizedBox(height: 18),
              GhostButton('Report ${p.name}', icon: Icons.flag_outlined, onPressed: () async {
                final sent = await reportSheet(context, p);
                if (sent && context.mounted) Navigator.pop(context, 'reported');
              }),
            ],
          ]),
        ),
      ]),
    );
  }

  void _act(String a) {
    Navigator.pop(context);
    widget.onAction!(a);
  }
}

/// The round pass / super like / like buttons.
class RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool gradient;
  final double size;
  final VoidCallback onTap;
  final String label;
  const RoundAction({super.key, required this.icon, required this.color, required this.onTap, required this.label, this.gradient = false, this.size = 64});
  factory RoundAction.pass({required VoidCallback onTap}) => RoundAction(icon: Icons.close_rounded, color: const Color(0xFFFF4D6D), onTap: onTap, label: 'Pass');
  factory RoundAction.superLike({required VoidCallback onTap}) => RoundAction(icon: Icons.star_rounded, color: K.superBlue, onTap: onTap, size: 52, label: 'Super like');
  factory RoundAction.like({required VoidCallback onTap}) => RoundAction(icon: Icons.favorite_rounded, color: Colors.white, onTap: onTap, gradient: true, size: 72, label: 'Like');

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: gradient ? null : p.surface,
            gradient: gradient ? K.grad : null,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -8)],
          ),
          child: Icon(icon, color: color, size: size * .5),
        ),
      ),
    );
  }
}
