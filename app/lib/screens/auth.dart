import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sheets.dart';

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
bool _isGmail(String e) => RegExp(r'@(gmail|googlemail)\.com$', caseSensitive: false).hasMatch(e);

int passwordStrength(String pw) {
  var s = 0;
  if (pw.length >= 8) s++;
  if (RegExp(r'[a-z]', caseSensitive: false).hasMatch(pw) && RegExp(r'\d').hasMatch(pw)) s++;
  if (RegExp(r'[A-Z]').hasMatch(pw) && RegExp(r'[a-z]').hasMatch(pw)) s++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw) || pw.length >= 12) s++;
  return pw.length < 8 ? (s > 1 ? 1 : s) : s;
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Column(children: [
                SizedBox(height: (box.maxHeight * .44).clamp(260, 380), child: const _HeroCards()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Wordmark(size: 26),
                    const SizedBox(height: 12),
                    Text('Where Salone hearts meet', style: serif(34, color: p.text)),
                    const SizedBox(height: 10),
                    Text('Meet genuine people across Sierra Leone — from Freetown to Kenema — who share your values.',
                        style: TextStyle(color: p.muted, fontSize: 16, height: 1.5)),
                    const SizedBox(height: 22),
                    GradButton('Create account', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen()))),
                    const SizedBox(height: 12),
                    GhostButton('I already have an account', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInScreen()))),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => showGuidelines(context),
                        child: Text.rich(
                          TextSpan(text: 'Kindred is for adults 18+. By continuing you agree to our ', children: [
                            TextSpan(text: 'Community Guidelines', style: TextStyle(color: K.brand, fontWeight: FontWeight.w700)),
                            const TextSpan(text: '.'),
                          ]),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.muted, fontSize: 12, height: 1.5),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCards extends StatefulWidget {
  const _HeroCards();
  @override
  State<_HeroCards> createState() => _HeroCardsState();
}

class _HeroCardsState extends State<_HeroCards> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _card(String id, String name, double w) => Container(
        width: w,
        height: w * 4 / 3,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 30, offset: const Offset(0, 16), spreadRadius: -10)]),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          ArtFill(id: id, name: name, fontSize: w * .5),
          Positioned(left: 12, bottom: 10, child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth * .44;
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          double bob(double phase) => 5 * math.sin(2 * math.pi * (_c.value + phase));
          return Stack(clipBehavior: Clip.none, children: [
            Positioned(left: box.maxWidth * .07, top: 30 + bob(0), child: Transform.rotate(angle: -.16, child: _card('a', 'Aminata', w))),
            Positioned(right: box.maxWidth * .07, top: 14 + bob(.33), child: Transform.rotate(angle: .12, child: _card('b', 'Mohamed', w))),
            Positioned(left: box.maxWidth * .28, top: 70 + bob(.66), child: Transform.rotate(angle: -.02, child: _card('c', 'Marie', w))),
            Positioned(
              left: box.maxWidth / 2 - 29,
              top: box.maxHeight - 90,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: Pal.of(context).surface, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 20, offset: const Offset(0, 8))]),
                child: const Icon(Icons.favorite_rounded, color: K.brand, size: 28),
              ),
            ),
          ]);
        },
      );
    });
  }
}

class _AuthScaffold extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  const _AuthScaffold({required this.title, required this.subtitle, required this.children});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(22, 0, 22, 28), children: [
          Text(title, style: serif(32, color: p.text)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: p.muted, fontSize: 15.5)),
          const SizedBox(height: 8),
          ...children,
        ]),
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final String? help;
  const LabeledField(this.label, {super.key, required this.child, this.help});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 7), child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.muted))),
        child,
        if (help != null) Padding(padding: const EdgeInsets.fromLTRB(4, 6, 4, 0), child: Text(help!, style: TextStyle(fontSize: 12.5, color: p.muted))),
      ]),
    );
  }
}

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final bool showStrength;
  final String hint;
  const PasswordField({super.key, required this.controller, this.showStrength = false, this.hint = ''});
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _show = false;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final v = widget.controller.text;
    final s = passwordStrength(v);
    const labels = ['Too short', 'Weak — add letters and numbers', 'Good', 'Strong', 'Very strong'];
    const colors = [K.danger, K.danger, Color(0xFFF59E0B), K.good, K.good];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: widget.controller,
        obscureText: !_show,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: widget.hint,
          suffixIcon: IconButton(
            icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: p.muted),
            tooltip: _show ? 'Hide password' : 'Show password',
            onPressed: () => setState(() => _show = !_show),
          ),
        ),
      ),
      if (widget.showStrength) ...[
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: v.isEmpty ? 0 : [.08, .3, .6, .8, 1.0][s],
            minHeight: 5,
            backgroundColor: p.line,
            color: colors[s],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Text(v.isEmpty ? 'Use 8+ characters with letters and numbers.' : labels[s], style: TextStyle(fontSize: 12.5, color: p.muted)),
        ),
      ],
    ]);
  }
}

class FormError extends StatelessWidget {
  final String? text;
  const FormError(this.text, {super.key});
  @override
  Widget build(BuildContext context) => text == null || text!.isEmpty
      ? const SizedBox.shrink()
      : Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 0), child: Text(text!, style: const TextStyle(color: K.danger, fontWeight: FontWeight.w600)));
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _name = TextEditingController(), _email = TextEditingController(), _pw = TextEditingController();
  DateTime? _dob;
  bool _agree = false, _busy = false;
  String? _err;

  DateTime get _maxDob {
    final n = DateTime.now();
    return DateTime(n.year - 18, n.month, n.day);
  }

  Future<void> _pickDob() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(_maxDob.year - 7, 1, 1),
      firstDate: DateTime(1920),
      lastDate: _maxDob,
      helpText: 'Your date of birth',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (d != null) setState(() => _dob = d);
  }

  Future<void> _submit() async {
    final name = _name.text.trim(), email = _email.text.trim().toLowerCase();
    String? e;
    if (name.isEmpty) {
      e = 'Please enter your first name.';
    } else if (!_emailRe.hasMatch(email)) {
      e = 'Please enter a valid email address.';
    } else if (_dob == null) {
      e = 'Please enter your date of birth.';
    } else if (_dob!.isAfter(_maxDob)) {
      e = 'You must be 18 or older to use Kindred.';
    } else if (passwordStrength(_pw.text) < 2) {
      e = 'Use at least 8 characters with letters and numbers.';
    } else if (!_agree) {
      e = "Please confirm you're 18+ and agree to the guidelines.";
    }
    if (e != null) return setState(() => _err = e);
    setState(() {
      _err = null;
      _busy = true;
    });
    try {
      final dob = '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}';
      final needsVerify = await Api.signUp(name: name, email: email, password: _pw.text, birthdate: dob);
      if (!mounted) return;
      if (needsVerify) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => InboxScreen(email: email, kind: InboxKind.signup)));
    } catch (err) {
      if (mounted) setState(() => _err = friendly(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    String dobText() => _dob == null ? 'Choose your date of birth' : '${_dob!.day}/${_dob!.month}/${_dob!.year}';
    return _AuthScaffold(title: 'Create your account', subtitle: 'It takes less than a minute.', children: [
      LabeledField('First name', child: TextField(controller: _name, textCapitalization: TextCapitalization.words, maxLength: 40, decoration: const InputDecoration(counterText: ''))),
      LabeledField('Email', child: TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false)),
      LabeledField(
        'Date of birth',
        help: 'You must be 18+. Only your age is shown, never your birthday.',
        child: InkWell(
          onTap: _pickDob,
          borderRadius: BorderRadius.circular(16),
          child: InputDecorator(
            decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined)),
            child: Text(dobText(), style: TextStyle(fontSize: 16, color: _dob == null ? p.muted : p.text)),
          ),
        ),
      ),
      LabeledField('Password', child: PasswordField(controller: _pw, showStrength: true)),
      const SizedBox(height: 14),
      InkWell(
        onTap: () => setState(() => _agree = !_agree),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(value: _agree, activeColor: K.brand, onChanged: (v) => setState(() => _agree = v ?? false)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GestureDetector(
                onTap: () => showGuidelines(context),
                child: Text.rich(TextSpan(text: "I'm 18 or older and I agree to the ", children: [
                  TextSpan(text: 'Community Guidelines', style: TextStyle(color: K.brand, fontWeight: FontWeight.w700)),
                  const TextSpan(text: '.'),
                ]), style: TextStyle(color: p.muted, height: 1.45)),
              ),
            ),
          ),
        ]),
      ),
      FormError(_err),
      const SizedBox(height: 16),
      GradButton('Create account', busy: _busy, onPressed: _submit),
      const SizedBox(height: 18),
      Center(
        child: TextButton(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignInScreen())),
          child: Text.rich(TextSpan(text: 'Already have an account? ', style: TextStyle(color: p.muted), children: const [
            TextSpan(text: 'Sign in', style: TextStyle(color: K.brand, fontWeight: FontWeight.w700)),
          ])),
        ),
      ),
    ]);
  }
}

class SignInScreen extends StatefulWidget {
  final String email;
  const SignInScreen({super.key, this.email = ''});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final _email = TextEditingController(text: widget.email);
  final _pw = TextEditingController();
  bool _busy = false;
  String? _err;

  Future<void> _submit() async {
    final email = _email.text.trim().toLowerCase();
    if (!_emailRe.hasMatch(email)) return setState(() => _err = 'Please enter a valid email address.');
    if (_pw.text.isEmpty) return setState(() => _err = 'Please enter your password.');
    setState(() {
      _err = null;
      _busy = true;
    });
    try {
      await Api.signIn(email, _pw.text);
    } catch (e) {
      if (mounted) setState(() => _err = friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return _AuthScaffold(title: 'Welcome back', subtitle: "Sign in to see who's waiting for you.", children: [
      LabeledField('Email', child: TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false)),
      LabeledField('Password', child: PasswordField(controller: _pw)),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ForgotScreen(email: _email.text.trim()))),
          child: const Text('Forgot password?', style: TextStyle(color: K.brand, fontWeight: FontWeight.w700)),
        ),
      ),
      FormError(_err),
      const SizedBox(height: 12),
      GradButton('Sign in', busy: _busy, onPressed: _submit),
      const SizedBox(height: 18),
      Center(
        child: TextButton(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
          child: Text.rich(TextSpan(text: 'New to Kindred? ', style: TextStyle(color: p.muted), children: const [
            TextSpan(text: 'Create an account', style: TextStyle(color: K.brand, fontWeight: FontWeight.w700)),
          ])),
        ),
      ),
    ]);
  }
}

class ForgotScreen extends StatefulWidget {
  final String email;
  const ForgotScreen({super.key, this.email = ''});
  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  late final _email = TextEditingController(text: widget.email);
  bool _busy = false;
  String? _err;

  Future<void> _submit() async {
    final email = _email.text.trim().toLowerCase();
    if (!_emailRe.hasMatch(email)) return setState(() => _err = 'Please enter a valid email address.');
    setState(() {
      _err = null;
      _busy = true;
    });
    try {
      await Api.sendReset(email);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => InboxScreen(email: email, kind: InboxKind.reset)));
    } catch (e) {
      if (mounted) setState(() => _err = friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Reset your password',
        subtitle: "Enter the email you signed up with and we'll send you a secure link to choose a new password.",
        children: [
          LabeledField('Email', child: TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false)),
          FormError(_err),
          const SizedBox(height: 18),
          GradButton('Send reset link', busy: _busy, onPressed: _submit),
        ],
      );
}

enum InboxKind { signup, reset }

class InboxScreen extends StatefulWidget {
  final String email;
  final InboxKind kind;
  const InboxScreen({super.key, required this.email, required this.kind});
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  int _cool = 0;
  Timer? _t;
  bool _busy = false;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      widget.kind == InboxKind.reset ? await Api.sendReset(widget.email) : await Api.resendSignup(widget.email);
      if (mounted) toast(context, 'Email sent again.');
    } catch (e) {
      if (mounted) toast(context, friendly(e));
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _cool = 60;
    });
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _cool <= 1) {
        t.cancel();
        if (mounted) setState(() => _cool = 0);
        return;
      }
      setState(() => _cool--);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final reset = widget.kind == InboxKind.reset;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(22, 10, 22, 28), children: [
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(gradient: K.grad, borderRadius: BorderRadius.circular(34), boxShadow: [BoxShadow(color: K.brand.withValues(alpha: .5), blurRadius: 40, offset: const Offset(0, 20), spreadRadius: -18)]),
              child: const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 56),
            ),
          ),
          const SizedBox(height: 22),
          Text('Check your inbox', textAlign: TextAlign.center, style: serif(32, color: p.text)),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(text: 'We sent ${reset ? 'a password reset link' : 'a confirmation link'} to\n', children: [
              TextSpan(text: widget.email, style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
            ]),
            textAlign: TextAlign.center,
            style: TextStyle(color: p.muted, fontSize: 15.5, height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            reset
                ? 'Open the email on this phone and tap the link. Kindred will open so you can choose a new password.'
                : 'Open the email on this phone and tap the link. Kindred will open and sign you in.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 6),
          Text("Can't find it? Check Spam or Promotions.", textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 13)),
          const SizedBox(height: 22),
          if (_isGmail(widget.email)) ...[
            GradButton('Open Gmail', icon: Icons.mail_outline_rounded, onPressed: () => launchUrl(Uri.parse('https://mail.google.com/'), mode: LaunchMode.externalApplication)),
            const SizedBox(height: 12),
          ],
          GhostButton(_cool > 0 ? 'Resend in ${_cool}s' : 'Resend email', busy: _busy, onPressed: _cool > 0 ? null : _resend),
          const SizedBox(height: 12),
          GhostButton('Back to sign in', filled: true, onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SignInScreen(email: widget.email)))),
        ]),
      ),
    );
  }
}

/// Shown when a password-reset email link opens the app.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});
  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _pw = TextEditingController(), _confirm = TextEditingController();
  bool _busy = false;
  String? _err;

  Future<void> _save() async {
    if (passwordStrength(_pw.text) < 2) return setState(() => _err = 'Use at least 8 characters with letters and numbers.');
    if (_pw.text != _confirm.text) return setState(() => _err = "The passwords don't match.");
    setState(() {
      _err = null;
      _busy = true;
    });
    try {
      await Api.updatePassword(_pw.text);
      if (!mounted) return;
      toast(context, 'Password updated');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _err = friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Choose a new password',
        subtitle: "Make it something you don't use anywhere else.",
        children: [
          LabeledField('New password', child: PasswordField(controller: _pw, showStrength: true)),
          LabeledField('Confirm new password', child: PasswordField(controller: _confirm)),
          FormError(_err),
          const SizedBox(height: 18),
          GradButton('Save new password', busy: _busy, onPressed: _save),
        ],
      );
}
