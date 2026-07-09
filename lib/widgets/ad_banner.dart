import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ads_config.dart';

/// Banner ad that only renders when the `ads_enabled` Remote Config flag is
/// on. While ads are disabled (the default), this widget renders nothing and
/// never touches the Mobile Ads SDK.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  /// The Mobile Ads SDK is initialized lazily, once, and only if ads are on.
  static Future<void>? _sdkInit;

  String get _adUnitId {
    if (Platform.isAndroid) {
      // In release builds, use the real ad unit ID.
      // In debug/profile builds (e.g. emulators), use Google's test ID.
      return kReleaseMode
          ? 'ca-app-pub-9003779081896617/3090430284'
          : 'ca-app-pub-3940256099942544/6300978111';
    } else if (Platform.isIOS) {
      return kReleaseMode
          ? 'ca-app-pub-9003779081896617/9599998315'
          : 'ca-app-pub-3940256099942544/2934735716';
    }
    // No ads on other platforms (web, desktop).
    return '';
  }

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final enabled = await AdsConfig.load();
    if (!enabled || !mounted || _adUnitId.isEmpty) return;

    _sdkInit ??= MobileAds.instance.initialize();
    await _sdkInit;
    if (!mounted) return;

    _loadAd();
  }

  void _loadAd() {
    if (_bannerAd != null) return;

    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: _adUnitId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
      request: const AdRequest(),
    );

    ad.load();
    _bannerAd = ad;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: SizedBox(
        height: _bannerAd!.size.height.toDouble(),
        width: double.infinity,
        child: Center(
          child: SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ),
      ),
    );
  }
}
