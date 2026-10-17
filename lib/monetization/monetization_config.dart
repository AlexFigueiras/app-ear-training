/// Configuração da monetização [MONETIZAÇÃO]: produtos da assinatura (Google Play Billing) e
/// blocos de anúncio (AdMob).
///
/// Os IDs reais do AdMob entram no build pelo `.env` (`--dart-define-from-file`), e quem gera
/// esse `.env` com os IDs reais é o botão "2 - Gerar AAB" (`.github/workflows/2-gerar-aab.yml`).
/// Sem eles, o app usa os IDs de TESTE do Google: build de desenvolvimento nunca mostra anúncio
/// real. O ID do APP no AdMob vai para o AndroidManifest pelo Gradle, a partir do mesmo `.env`
/// (`android/app/build.gradle.kts`).
class MonetizationConfig {
  const MonetizationConfig._();

  /// Pacote do app na Play Store (`android/app/build.gradle.kts`).
  static const String packageName = 'com.bosyn.app';

  /// Assinaturas criadas na Play Console (Monetizar → Produtos → Assinaturas), cada uma com um
  /// plano base sem oferta. A Edge Function `play-subscription` aceita só estes IDs
  /// (`supabase/functions/_shared/play_entitlement.ts`).
  static const String monthlyProductId = 'bosyn_pro_mensal';
  static const String yearlyProductId = 'bosyn_pro_anual';
  static const Set<String> subscriptionProductIds = {
    monthlyProductId,
    yearlyProductId
  };

  /// Blocos de teste publicados pelo Google para Android.
  static const String testBannerId = 'ca-app-pub-3940256099942544/9214589741';
  static const String testRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testAccount = 'ca-app-pub-3940256099942544';

  static const String _bannerFromBuild =
      String.fromEnvironment('ADMOB_BANNER_ID');
  static const String _rewardedFromBuild =
      String.fromEnvironment('ADMOB_REWARD_ID');

  /// Vazio no `.env` conta como ausente (String.fromEnvironment devolveria '').
  static String get bannerAdUnitId =>
      _bannerFromBuild.isEmpty ? testBannerId : _bannerFromBuild;
  static String get rewardedAdUnitId =>
      _rewardedFromBuild.isEmpty ? testRewardedId : _rewardedFromBuild;

  static bool isTestAdUnit(String adUnitId) =>
      adUnitId.startsWith('$_testAccount/');

  static bool get usesTestAds =>
      isTestAdUnit(bannerAdUnitId) || isTestAdUnit(rewardedAdUnitId);

  /// Sessões PRO por dia que quem não assina pode liberar com um vídeo premiado. Pouco o
  /// bastante para a assinatura continuar valendo a pena; o bastante para a meta do dia (15 min).
  static const int rewardedSessionsPerDay = 2;

  /// Página de assinaturas da conta Google: cancelar, trocar o plano ou a forma de pagamento.
  static String manageSubscriptionsUrl({String? productId}) {
    final query = <String, String>{
      if (productId != null) 'sku': productId,
      'package': packageName,
    };
    return Uri.https('play.google.com', '/store/account/subscriptions', query)
        .toString();
  }
}
