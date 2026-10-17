import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';

import '../monetization/monetization_config.dart';
import '../monetization/rewarded_quota.dart';

enum RewardedOutcome { earned, dismissed, unavailable, limitReached }

/// Anúncios do AdMob para quem não assina o PRO [MONETIZAÇÃO].
///
/// - Banner só na Home (`HomeBannerAd`). Nunca no teste de audição nem durante um treino: o som
///   ou o toque de um anúncio estragaria o exercício.
/// - Vídeo premiado sempre por escolha da pessoa: libera 1 sessão PRO, com limite por dia
///   ([MonetizationConfig.rewardedSessionsPerDay]).
/// - Anúncios não personalizados ([request]): o app trata dado de saúde e não usa interesse da
///   pessoa para publicidade (docs/legal/politica-de-privacidade.md).
/// - Consentimento (UMP) pedido antes do primeiro anúncio onde a lei exige (UE/Reino Unido).
/// - Quem assina o PRO nunca liga o SDK: [start] só é chamado para o plano grátis.
class AdsService extends ChangeNotifier {
  static final AdsService _instance = AdsService._internal();
  factory AdsService() => _instance;
  AdsService._internal();

  static const AdRequest request = AdRequest(nonPersonalizedAds: true);

  Future<void>? _starting;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;
  RewardedAd? _rewarded;
  bool _loadingRewarded = false;
  Timer? _retry;
  RewardedQuota _quota = RewardedQuota.empty;

  /// Consentimento resolvido e SDK ligado: pode pedir anúncio.
  bool get canRequestAds => _canRequestAds;

  /// A lei pede o link "Privacidade dos anúncios" (tela de conta).
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  bool get rewardedReady => _rewarded != null;

  int remainingToday([DateTime? now]) => _quota.remaining(
      now ?? DateTime.now(), MonetizationConfig.rewardedSessionsPerDay);

  /// Pede o consentimento onde a lei exige e liga o SDK. Pode ser chamado várias vezes: se o
  /// consentimento não saiu (ex.: sem conexão ao abrir), a próxima chamada tenta de novo.
  Future<void> start() {
    if (_canRequestAds) return Future.value();
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    _quota = await _readQuota();
    try {
      await _updateConsent();
      await _refreshConsentState();
      if (_canRequestAds) {
        await MobileAds.instance.initialize();
        // Público 18+ (Play Console): sem tratamento de idade (ageRestrictedTreatment padrão).
        // Conteúdo dos anúncios limitado a "PG" num app de saúde.
        await MobileAds.instance.updateRequestConfiguration(
            RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg));
        _loadRewarded();
      }
    } catch (e) {
      debugPrint('[ADS] indisponível: $e');
      _canRequestAds = false;
    }
    notifyListeners();
  }

  Future<void> _updateConsent() {
    final done = Completer<void>();
    void finish([FormError? error]) {
      if (error != null) debugPrint('[ADS] consentimento: ${error.message}');
      if (!done.isCompleted) done.complete();
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired(finish),
      finish,
    );
    return done.future;
  }

  Future<void> _refreshConsentState() async {
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    _privacyOptionsRequired = await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  }

  /// Formulário "Privacidade dos anúncios" (rever ou retirar o consentimento).
  Future<void> showPrivacyOptions() async {
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) debugPrint('[ADS] privacidade: ${error.message}');
    });
    await _refreshConsentState();
    notifyListeners();
  }

  void _loadRewarded() {
    if (!_canRequestAds || _rewarded != null || _loadingRewarded) return;
    _retry?.cancel();
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: MonetizationConfig.rewardedAdUnitId,
      request: request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          debugPrint('[ADS] vídeo não carregou: ${error.message}');
          _loadingRewarded = false;
          _retry = Timer(const Duration(seconds: 30), _loadRewarded);
          notifyListeners();
        },
      ),
    );
  }

  Future<RewardedAd?> _waitForRewarded(Duration timeout) async {
    _loadRewarded();
    final deadline = DateTime.now().add(timeout);
    while (_rewarded == null &&
        _loadingRewarded &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return _rewarded;
  }

  /// Mostra o vídeo premiado que libera 1 sessão PRO. Conta no limite do dia só se a pessoa
  /// assistiu até ganhar o prêmio.
  Future<RewardedOutcome> showRewardedForSession() async {
    if (remainingToday() <= 0) return RewardedOutcome.limitReached;
    if (!_canRequestAds) return RewardedOutcome.unavailable;
    final ad = _rewarded ?? await _waitForRewarded(const Duration(seconds: 8));
    if (ad == null) return RewardedOutcome.unavailable;
    _rewarded = null;

    var earned = false;
    final closed = Completer<void>();
    void close(RewardedAd shown) {
      shown.dispose();
      if (!closed.isCompleted) closed.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: close,
      onAdFailedToShowFullScreenContent: (shown, error) => close(shown),
    );
    try {
      await ad.show(onUserEarnedReward: (_, __) => earned = true);
      // Rede de segurança: se o SDK não avisar o fechamento, a Home não fica esperando.
      await closed.future
          .timeout(const Duration(minutes: 5), onTimeout: () => close(ad));
    } catch (e) {
      debugPrint('[ADS] vídeo não abriu: $e');
      close(ad);
    }
    _loadRewarded();

    if (earned) {
      _quota = _quota.register(DateTime.now());
      await _saveQuota();
    }
    notifyListeners();
    return earned ? RewardedOutcome.earned : RewardedOutcome.dismissed;
  }

  Future<File> _quotaFile() async => File(
      '${(await getApplicationSupportDirectory()).path}/rewarded_quota.json');

  Future<RewardedQuota> _readQuota() async {
    try {
      final file = await _quotaFile();
      if (!await file.exists()) return RewardedQuota.empty;
      return RewardedQuota.fromJson(jsonDecode(await file.readAsString()));
    } catch (e) {
      debugPrint('[ADS] limite diário não lido: $e');
      return RewardedQuota.empty;
    }
  }

  Future<void> _saveQuota() async {
    try {
      await (await _quotaFile()).writeAsString(jsonEncode(_quota.toJson()));
    } catch (e) {
      debugPrint('[ADS] limite diário não salvo: $e');
    }
  }
}
