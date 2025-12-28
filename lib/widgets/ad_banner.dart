import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

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
    _loadAd();
  }

  void _loadAd() {
    if (_bannerAd != null || _adUnitId.isEmpty) return;

    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: _adUnitId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
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
