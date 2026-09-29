import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'config.dart';

/// Google AdMob banner ads on the Android app's main tabs (Discover, Matches, Profile). Never in chats,
/// calls or sign-in screens: those are separate screens pushed over the tabs. Google's consent form is
/// shown first where the law requires one (for example visitors from the EU or UK).
class Ads {
  static final ready = ValueNotifier<bool>(false);
  static bool _started = false;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void init() {
    if (!supported || _started) return;
    _started = true;
    Future<void> start() async {
      try {
        if (!await ConsentInformation.instance.canRequestAds()) return;
        await MobileAds.instance.initialize();
        ready.value = true;
      } catch (_) {/* no ads is fine */}
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) => start()),
      (_) => start(), // offline or not configured: use whatever consent was given before
    );
  }
}

/// One adaptive banner sized to the screen width. Takes no space until an ad has loaded.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});
  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Ads.ready.addListener(_load);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!Ads.ready.value || _ad != null || !mounted) return;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(MediaQuery.sizeOf(context).width.truncate());
    if (size == null || !mounted || _ad != null) return;
    _ad = BannerAd(
      adUnitId: admobBannerUnit,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _ad = null; // try again next time the tabs are shown
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    Ads.ready.removeListener(_load);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(width: ad.size.width.toDouble(), height: ad.size.height.toDouble(), child: AdWidget(ad: ad));
  }
}
