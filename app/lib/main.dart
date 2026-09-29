import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'alerts.dart';
import 'api.dart';
import 'calls.dart';
import 'config.dart';
import 'push.dart';
import 'screens/auth.dart';
import 'screens/home.dart';
import 'screens/onboarding.dart';
import 'theme.dart';
import 'widgets.dart';

final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  await Cache.init();
  await Alerts.init();
  await Push.init();
  runApp(const KindredApp());
}

class KindredApp extends StatelessWidget {
  const KindredApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Kindred',
        debugShowCheckedModeBanner: false,
        navigatorKey: navKey,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const Root(),
      );
}

/// Shows the splash, then whichever part of the app fits the current session.
class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> with WidgetsBindingObserver {
  bool _splash = true;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    app.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Realtime may have slept in the background: catch a call that is ringing right now.
    if (s == AppLifecycleState.resumed) Calls.checkRinging();
  }

  Future<void> _boot() async {
    final minSplash = Future.delayed(const Duration(milliseconds: 1900));
    // Load the brand fonts while the splash shows, so no screen appears in a fallback font.
    // Give up after 5 s on a poor connection; they are cached on the phone after the first load.
    final fonts = Future.any([
      GoogleFonts.pendingFonts([
        GoogleFonts.fraunces(fontWeight: FontWeight.w600),
        GoogleFonts.fraunces(fontWeight: FontWeight.w700, fontStyle: FontStyle.italic),
        GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w400),
        GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
      ]),
      Future.delayed(const Duration(seconds: 5)),
    ]).catchError((_) => null);
    await app.load(sb.auth.currentSession);
    await fonts;
    _sub = sb.auth.onAuthStateChange.listen((s) async {
      final e = s.event;
      if (e == AuthChangeEvent.signedOut) {
        await app.load(null);
      } else if (e == AuthChangeEvent.signedIn && s.session?.user.id != app.session?.user.id) {
        await app.load(s.session);
      } else if (e == AuthChangeEvent.passwordRecovery) {
        // A reset-password email link opened the app: sign in, then ask for the new password.
        await app.load(s.session);
        navKey.currentState?.push(MaterialPageRoute(builder: (_) => const NewPasswordScreen()));
      } else if (e == AuthChangeEvent.tokenRefreshed) {
        app.session = s.session;
      }
    });
    await minSplash;
    if (mounted) setState(() => _splash = false);
  }

  String? _lastGate;
  void _changed() {
    // When the gate changes (signed in, signed out, finished onboarding) clear any pushed screens.
    final gate = _gate();
    if (gate != _lastGate) {
      _lastGate = gate;
      navKey.currentState?.popUntil((r) => r.isFirst);
    }
    if (mounted) setState(() {});
  }

  String _gate() => app.session == null ? 'out' : app.me == null ? 'loading' : app.me!.onboarded ? 'home' : 'setup';

  @override
  void dispose() {
    _sub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    app.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (_splash ? 'splash' : _gate()) {
      'splash' => const SplashView(key: ValueKey('splash')),
      'out' => const WelcomeScreen(key: ValueKey('out')),
      'loading' => Scaffold(key: const ValueKey('loading'), body: Center(child: KMark(size: 64))),
      'setup' => const OnboardingScreen(key: ValueKey('setup')),
      _ => const HomeShell(key: ValueKey('home')),
    };
    return AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: child);
  }
}

/// Animated splash: the heart draws itself, the spark pops, a silver bar sweeps.
class SplashView extends StatefulWidget {
  const SplashView({super.key});
  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with TickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  late final AnimationController _beat = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  late final AnimationController _bar = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _draw.dispose();
    _beat.dispose();
    _bar.dispose();
    super.dispose();
  }

  double _beatScale(double t) {
    if (t < .14) return 1 + .07 * (t / .14);
    if (t < .28) return 1.07 - .07 * ((t - .14) / .14);
    if (t < .42) return 1 + .05 * ((t - .28) / .14);
    if (t < .6) return 1.05 - .05 * ((t - .42) / .18);
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: K.grad),
          child: Stack(children: [
            Positioned(top: -60, left: -80, child: _glow(260, Colors.white)),
            Positioned(bottom: -40, right: -60, child: _glow(220, const Color(0xFFFFD1A8))),
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_draw, _beat, _bar]),
                builder: (context, _) {
                  final d = Curves.easeOut.transform(_draw.value);
                  final dot = _draw.value < .78 ? 0.0 : Curves.elasticOut.transform(((_draw.value - .78) / .22).clamp(0, 1));
                  final textIn = ((_draw.value - .45) / .4).clamp(0.0, 1.0);
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    Transform.scale(
                      scale: _beatScale(_beat.value),
                      child: CustomPaint(size: const Size.square(108), painter: MarkPainter(color: Colors.white, progress: d, dot: dot)),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: textIn,
                      child: Transform.translate(offset: Offset(0, 8 * (1 - textIn)), child: Text('kindred', style: serif(46, color: Colors.white))),
                    ),
                    Opacity(opacity: textIn, child: const Text('Find your kindred spirit in Salone', style: TextStyle(color: Colors.white, fontSize: 14))),
                    const SizedBox(height: 44),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 132,
                        height: 4,
                        color: Colors.white.withValues(alpha: .25),
                        child: FractionalTranslation(
                          translation: Offset(-1.1 + 3.5 * _bar.value, 0),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: .45,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: [Color(0x33DCE0E6), Color(0xFFF4F6F8), Color(0xFFC9CED6), Color(0x33DCE0E6)]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _glow(double d, Color c) => ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(width: d, height: d, decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: .35))),
      );
}
