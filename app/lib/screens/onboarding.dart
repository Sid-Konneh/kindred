import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth.dart';

/// Editable copy of the profile fields, shared by onboarding and Edit profile.
class Draft {
  String name, bio, city, job;
  String? gender, showMe, lookingFor, religion;
  DateTime? birthdate;
  List<String> photos, interests, languages;
  Draft.from(Profile p)
      : name = p.name,
        bio = p.bio,
        city = p.city ?? '',
        job = p.job ?? '',
        gender = p.gender,
        showMe = p.showMe,
        lookingFor = p.lookingFor,
        religion = p.religion,
        birthdate = p.birthdate,
        photos = [...p.photos],
        interests = [...p.interests],
        languages = p.languages.isEmpty ? ['Krio', 'English'] : [...p.languages];

  Map<String, dynamic> toPatch() => {
        'name': name.trim(),
        'bio': bio.trim(),
        'city': city.isEmpty ? null : city,
        'job': job.trim().isEmpty ? null : job.trim(),
        'gender': gender,
        'show_me': showMe,
        'looking_for': lookingFor,
        'religion': religion,
        'photos': photos,
        'interests': interests,
        'languages': languages,
      };
}

/// 3-column photo grid: tap an empty slot to add, first photo is the main one.
class PhotoGrid extends StatefulWidget {
  final List<String> photos;
  final VoidCallback onChanged;
  const PhotoGrid({super.key, required this.photos, required this.onChanged});
  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> {
  bool _uploading = false;

  Future<void> _add() async {
    if (_uploading) return;
    // image_picker resizes and recompresses on the phone, so uploads stay small on mobile data.
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, maxHeight: 1280, imageQuality: 82);
    if (x == null) return;
    setState(() => _uploading = true);
    try {
      final url = await Api.uploadPhoto(await x.readAsBytes(), x.name);
      widget.photos.add(url);
      widget.onChanged();
    } catch (e) {
      if (mounted) toast(context, friendly(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final ph = widget.photos;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 3 / 4,
      children: List.generate(6, (i) {
        if (i < ph.length) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(fit: StackFit.expand, children: [
              NetPhoto(ph[i]),
              Positioned(
                top: 6,
                right: 6,
                child: _mini(Icons.close_rounded, 'Remove photo', () {
                  ph.removeAt(i);
                  widget.onChanged();
                  setState(() {});
                }),
              ),
              Positioned(
                left: 6,
                bottom: 6,
                child: i == 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(gradient: K.grad, borderRadius: BorderRadius.circular(99)),
                        child: const Text('Main', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      )
                    : GestureDetector(
                        onTap: () {
                          ph.insert(0, ph.removeAt(i));
                          widget.onChanged();
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(99)),
                          child: const Text('Make main', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ),
              ),
            ]),
          );
        }
        final isNext = i == ph.length;
        return GestureDetector(
          onTap: _add,
          child: Container(
            decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line, width: 2)),
            child: isNext && _uploading
                ? const ClipRRect(borderRadius: BorderRadius.all(Radius.circular(14)), child: Silver(child: ColoredBox(color: Colors.white, child: SizedBox.expand())))
                : Center(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(gradient: K.grad, shape: BoxShape.circle),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    ),
                  ),
          ),
        );
      }),
    );
  }

  Widget _mini(IconData ic, String tip, VoidCallback onTap) => Semantics(
        button: true,
        label: tip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), shape: BoxShape.circle), child: Icon(ic, color: Colors.white, size: 16)),
        ),
      );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final Draft d = Draft.from(app.me!);
  late final bool _needDob = app.me!.birthdate == null;
  int step = 0;
  bool busy = false;
  static const steps = 4;
  late final _job = TextEditingController(text: d.job);
  late final _bio = TextEditingController(text: d.bio);

  String? _validate() {
    if (step == 0) {
      if (_needDob && d.birthdate == null) return 'Please add your date of birth.';
      if (_needDob && (ageFrom(d.birthdate) ?? 0) < 18) return 'You must be 18 or older to use Kindred.';
      if (d.gender == null) return "Please choose whether you're a woman or a man.";
    }
    if (step == 1 && d.photos.isEmpty) return 'Add at least one photo so people can see you.';
    if (step == 2) {
      if (d.city.isEmpty) return 'Please choose your city or town.';
      if (d.lookingFor == null) return "Tell people what you're looking for.";
    }
    if (step == 3 && d.interests.length < 3) return 'Pick at least 3 interests.';
    return null;
  }

  Future<void> _next() async {
    d.job = _job.text;
    d.bio = _bio.text;
    final err = _validate();
    if (err != null) return toast(context, err);
    if (step < steps - 1) return setState(() => step++);
    setState(() => busy = true);
    try {
      final patch = {...d.toPatch(), 'onboarded': true};
      if (_needDob) patch['birthdate'] = d.birthdate!.toIso8601String().substring(0, 10);
      final saved = await Api.saveProfile(patch);
      if (mounted) toast(context, "You're all set! Start discovering 💗");
      app.setMe(saved);
    } catch (e) {
      if (mounted) {
        toast(context, friendly(e));
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && step > 0) setState(() => step--);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: step == 0
              ? IconButton(icon: const Icon(Icons.close), tooltip: 'Sign out', onPressed: Api.signOut)
              : IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Back', onPressed: () => setState(() => step--)),
          title: Text('Step ${step + 1} of $steps', style: TextStyle(color: p.muted, fontSize: 15, fontWeight: FontWeight.w700)),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: (step + 1) / steps),
                  duration: const Duration(milliseconds: 350),
                  builder: (_, v, _) => Stack(children: [
                    Container(height: 5, color: p.line),
                    FractionallySizedBox(widthFactor: v, child: Container(height: 5, decoration: const BoxDecoration(gradient: K.grad))),
                  ]),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(children: [
            Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(22, 14, 22, 24), children: _body(p))),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
              child: GradButton(step == steps - 1 ? 'Start matching' : 'Continue', busy: busy, onPressed: _next),
            ),
          ]),
        ),
      ),
    );
  }

  List<Widget> _body(Pal p) {
    Widget title(String t) => Text(t, style: serif(32, color: p.text));
    Widget sub(String t) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(t, style: TextStyle(color: p.muted, fontSize: 15.5, height: 1.45)));
    switch (step) {
      case 0:
        return [
          title('Kushɛ, ${app.me!.name}! 👋'),
          sub("Let's set up your profile so the right people can find you."),
          if (_needDob)
            LabeledField('Date of birth',
                help: "You must be 18+. It can't be changed later.",
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final n = DateTime.now();
                    final max = DateTime(n.year - 18, n.month, n.day);
                    final v = await showDatePicker(context: context, initialDate: d.birthdate ?? DateTime(max.year - 7), firstDate: DateTime(1920), lastDate: max);
                    if (v != null) setState(() => d.birthdate = v);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined)),
                    child: Text(d.birthdate == null ? 'Choose your date of birth' : '${d.birthdate!.day}/${d.birthdate!.month}/${d.birthdate!.year}'),
                  ),
                )),
          const FieldLabel('I am a'),
          Segmented(options: const [('woman', 'Woman'), ('man', 'Man')], value: d.gender, onChanged: (v) => setState(() => d.gender = v)),
          const FieldLabel('Show me'),
          Segmented(options: const [('women', 'Women'), ('men', 'Men'), ('everyone', 'Everyone')], value: d.showMe, onChanged: (v) => setState(() => d.showMe = v)),
        ];
      case 1:
        return [
          title('Add your photos'),
          sub('Profiles with 3 or more clear photos get far more matches. Your first photo is your main one.'),
          const SizedBox(height: 18),
          PhotoGrid(photos: d.photos, onChanged: () => setState(() {})),
          const SizedBox(height: 14),
          Text('Tip: use a recent photo where your face is clear. No group photos as your main picture.', style: TextStyle(color: p.muted, fontSize: 13)),
        ];
      case 2:
        return [
          title('The basics'),
          ...basicsFields(context, d, _job, () => setState(() {})),
        ];
      default:
        return [
          title('Your story'),
          ...storyFields(context, d, _bio, () => setState(() {})),
        ];
    }
  }
}

List<Widget> basicsFields(BuildContext context, Draft d, TextEditingController job, VoidCallback changed, {bool allReligions = false}) {
  final p = Pal.of(context);
  return [
    LabeledField('City or town',
        child: DropdownButtonFormField<String>(
          initialValue: d.city.isEmpty ? null : d.city,
          hint: const Text('Choose…'),
          items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) {
            d.city = v ?? '';
            changed();
          },
        )),
    LabeledField('Work or study (optional)', child: TextField(controller: job, maxLength: 60, decoration: const InputDecoration(hintText: 'e.g. Nurse, Fourah Bay College student', counterText: ''))),
    const FieldLabel("I'm looking for"),
    for (final o in lookingOptions)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            d.lookingFor = o.$1;
            changed();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: d.lookingFor == o.$1 ? K.brand.withValues(alpha: .06) : p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: d.lookingFor == o.$1 ? K.brand : p.line, width: 1.5),
            ),
            child: Row(children: [Text(o.$3, style: const TextStyle(fontSize: 22)), const SizedBox(width: 14), Text(o.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5))]),
          ),
        ),
      ),
    FieldLabel(allReligions ? 'Religion' : 'Religion (optional)'),
    Segmented(
      options: allReligions ? religionOptions : religionOptions.take(3).toList(),
      value: d.religion,
      onChanged: (v) {
        d.religion = v;
        changed();
      },
    ),
  ];
}

List<Widget> storyFields(BuildContext context, Draft d, TextEditingController bio, VoidCallback changed) {
  void toggle(List<String> list, String v, int cap) {
    if (list.contains(v)) {
      list.remove(v);
    } else if (list.length >= cap) {
      toast(context, 'You can pick up to $cap.');
      return;
    } else {
      list.add(v);
    }
    changed();
  }

  return [
    LabeledField('About me',
        child: TextField(
          controller: bio,
          maxLength: 500,
          maxLines: 5,
          minLines: 4,
          onChanged: (v) => d.bio = v,
          decoration: const InputDecoration(hintText: 'What makes you, you? What are you hoping to find?'),
        )),
    FieldLabel('Interests', trailing: '${d.interests.length}/10 · pick at least 3'),
    Wrap(spacing: 8, runSpacing: 8, children: [for (final t in allInterests) PickChip(t, on: d.interests.contains(t), onTap: () => toggle(d.interests, t, 10))]),
    const FieldLabel('Languages I speak'),
    Wrap(spacing: 8, runSpacing: 8, children: [for (final t in allLanguages) PickChip(t, on: d.languages.contains(t), onTap: () => toggle(d.languages, t, 13))]),
  ];
}
