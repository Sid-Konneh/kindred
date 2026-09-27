import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth.dart';
import 'onboarding.dart';
import 'sheets.dart';

int completeness(Profile p) {
  var s = (p.photos.length.clamp(0, 3)) * 12;
  if (p.bio.length > 30) s += 20;
  if (p.interests.length >= 3) s += 12;
  if ((p.job ?? '').isNotEmpty) s += 8;
  if ((p.city ?? '').isNotEmpty) s += 8;
  if (p.lookingFor != null) s += 8;
  if (p.languages.isNotEmpty) s += 8;
  return s.clamp(0, 100);
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return SafeArea(
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final me = app.me;
          if (me == null) return const SizedBox.shrink();
          final pct = completeness(me);
          Widget section(String t) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(t.toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1, color: p.muted)),
              );
          Widget group(List<Widget> rows) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (var i = 0; i < rows.length; i++) ...[if (i > 0) Divider(height: 1, color: p.line), rows[i]],
                ]),
              );
          Widget row(IconData ic, String t, VoidCallback onTap, {bool danger = false}) => ListTile(
                leading: Icon(ic, color: danger ? K.danger : p.muted),
                title: Text(t, style: TextStyle(fontWeight: FontWeight.w600, color: danger ? K.danger : p.text)),
                trailing: Icon(Icons.chevron_right, color: p.muted),
                onTap: onTap,
              );
          return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            const Padding(padding: EdgeInsets.fromLTRB(20, 14, 20, 10), child: Text('Profile', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
            Center(
              child: SizedBox(
                width: 132,
                height: 140,
                child: Stack(alignment: Alignment.topCenter, children: [
                  SizedBox(
                    width: 128,
                    height: 128,
                    child: CircularProgressIndicator(value: pct / 100, strokeWidth: 5, color: K.brand, backgroundColor: p.line, strokeCap: StrokeCap.round),
                  ),
                  Positioned(top: 7, child: Avatar(me, size: 114)),
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(gradient: K.grad, borderRadius: BorderRadius.circular(99)),
                      child: Text('$pct% complete', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Text('${me.name}, ${me.age ?? ''}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            Text([me.city, me.job].whereType<String>().where((s) => s.isNotEmpty).join(' · '), textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Row(children: [
                Expanded(child: GradButton('Edit profile', icon: Icons.edit_outlined, height: 48, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())))),
                const SizedBox(width: 10),
                Expanded(child: GhostButton('Preview', icon: Icons.visibility_outlined, filled: true, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileView(p: me, isSelf: true))))),
              ]),
            ),
            section('Discovery'),
            group([row(Icons.tune_rounded, 'Discovery settings', () => filtersSheet(context))]),
            section('Safety'),
            group([
              row(Icons.verified_user_outlined, 'Dating safety tips', () => showSafety(context)),
              row(Icons.flag_outlined, 'Community guidelines', () => showGuidelines(context)),
            ]),
            section('Account'),
            group([
              ListTile(
                leading: Icon(Icons.mail_outline, color: p.muted),
                title: Text('Signed in as', style: TextStyle(color: p.muted, fontSize: 13)),
                subtitle: Text(Api.email ?? '', style: TextStyle(color: p.text, fontSize: 15)),
              ),
              row(Icons.lock_outline, 'Change password', () => changePasswordSheet(context)),
              row(Icons.logout, 'Sign out', Api.signOut),
              row(Icons.delete_outline, 'Delete account', () => deleteAccountSheet(context), danger: true),
            ]),
            const SizedBox(height: 18),
            Text('Kindred · Made for Salone 🇸🇱', textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12)),
          ]);
        },
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final Draft d = Draft.from(app.me!);
  late final _name = TextEditingController(text: d.name);
  late final _job = TextEditingController(text: d.job);
  late final _bio = TextEditingController(text: d.bio);
  bool _busy = false;

  Future<void> _save() async {
    d
      ..name = _name.text
      ..job = _job.text
      ..bio = _bio.text;
    if (d.name.trim().isEmpty) return toast(context, 'Please enter your first name.');
    if (d.photos.isEmpty) return toast(context, 'Keep at least one photo on your profile.');
    if (d.interests.length < 3) return toast(context, 'Pick at least 3 interests.');
    setState(() => _busy = true);
    try {
      app.setMe(await Api.saveProfile(d.toPatch()));
      if (mounted) {
        toast(context, 'Profile saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        toast(context, friendly(e));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    void changed() => setState(() {});
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 12), child: SizedBox(width: 92, child: GradButton('Save', height: 40, busy: _busy, onPressed: _save))),
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(22, 0, 22, 30), children: [
          const FieldLabel('Photos'),
          PhotoGrid(photos: d.photos, onChanged: changed),
          LabeledField('First name', child: TextField(controller: _name, maxLength: 40, decoration: const InputDecoration(counterText: ''))),
          const FieldLabel('I am a'),
          Segmented(options: const [('woman', 'Woman'), ('man', 'Man')], value: d.gender, onChanged: (v) => setState(() => d.gender = v)),
          ...storyFields(context, d, _bio, changed),
          ...basicsFields(context, d, _job, changed, allReligions: true),
        ]),
      ),
    );
  }
}
