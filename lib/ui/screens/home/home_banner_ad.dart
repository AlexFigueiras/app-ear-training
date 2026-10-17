import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../monetization/monetization_config.dart';
import '../../../services/ads_service.dart';

/// Banner do AdMob no rodapé da Home, só para quem não assina o PRO [MONETIZAÇÃO].
///
/// Fica no espaço próprio do rodapé do Scaffold (nunca por cima dos cartões) e com 8 px de
/// folga acima, para não ser tocado sem querer — clique acidental é o motivo mais comum de
/// bloqueio de conta no AdMob. Enquanto o consentimento não sai ou o anúncio não carrega, não
/// ocupa espaço nenhum.
class HomeBannerAd extends StatefulWidget {
  const HomeBannerAd({super.key});

  @override
  State<HomeBannerAd> createState() => _HomeBannerAdState();
}

class _HomeBannerAdState extends State<HomeBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _requestedWidth;

  @override
  void initState() {
    super.initState();
    AdsService().addListener(_maybeLoad);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  Future<void> _maybeLoad() async {
    if (!mounted || !AdsService().canRequestAds) return;
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width <= 0 || width == _requestedWidth) return;
    _requestedWidth = width;

    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null) return;
    final ad = BannerAd(
      size: size,
      adUnitId: MonetizationConfig.bannerAdUnitId,
      request: AdsService.request,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (failed, error) {
          failed.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
    );
    _ad?.dispose();
    setState(() {
      _ad = ad;
      _loaded = false;
    });
    await ad.load();
  }

  @override
  void dispose() {
    AdsService().removeListener(_maybeLoad);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Center(
          heightFactor: 1,
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ),
      ),
    );
  }
}
