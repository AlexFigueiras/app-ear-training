import 'package:ear_training/monetization/monetization_config.dart';
import 'package:ear_training/monetization/plan_offer.dart';
import 'package:ear_training/monetization/pro_access.dart';
import 'package:ear_training/monetization/rewarded_quota.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProAccess', () {
    final now = DateTime.utc(2026, 10, 17, 12);

    test('PRO da Play vale até a validade', () {
      final access = ProAccess.fromProfile({
        'subscription_status': 'pro',
        'subscription_expires_at': '2026-11-17T12:00:00+00:00',
      });
      expect(access.isActiveAt(now), isTrue);
      expect(access.isActiveAt(DateTime.utc(2026, 11, 18)), isFalse);
    });

    test('PRO dado à mão (sem validade) e perfil antigo continuam valendo', () {
      expect(
          ProAccess.fromProfile({'subscription_status': 'elite'})
              .isActiveAt(now),
          isTrue);
      expect(
          ProAccess.fromProfile({'subscription_status': 'pro'}).isActiveAt(now),
          isTrue);
    });

    test('grátis, sem perfil ou com dado estranho não libera', () {
      expect(
          ProAccess.fromProfile({'subscription_status': 'free'})
              .isActiveAt(now),
          isFalse);
      expect(ProAccess.fromProfile(null).isActiveAt(now), isFalse);
      expect(ProAccess.fromProfile({'subscription_status': 42}).isActiveAt(now),
          isFalse);
      expect(
          ProAccess.fromProfile({
            'subscription_status': 'pro',
            'subscription_expires_at': '2026-10-17T11:59:59Z',
          }).isActiveAt(now),
          isFalse);
    });
  });

  group('RewardedQuota', () {
    final morning = DateTime(2026, 10, 17, 8);

    test('conta o uso do dia e zera no dia seguinte', () {
      var quota = RewardedQuota.empty;
      expect(quota.remaining(morning, 2), 2);
      quota = quota
          .register(morning)
          .register(morning.add(const Duration(hours: 3)));
      expect(quota.remaining(morning, 2), 0);
      expect(quota.remaining(DateTime(2026, 10, 18, 0, 1), 2), 2);
      expect(quota.register(DateTime(2026, 10, 18)).used, 1);
    });

    test('ida e volta em JSON; JSON estranho não bloqueia', () {
      final quota = RewardedQuota.empty.register(morning);
      expect(RewardedQuota.fromJson(quota.toJson()).remaining(morning, 2), 1);
      expect(RewardedQuota.fromJson('lixo').remaining(morning, 2), 2);
      expect(
          RewardedQuota.fromJson({'day': '2026-10-17', 'used': -3})
              .remaining(morning, 2),
          2);
    });
  });

  group('MonetizationConfig', () {
    test('sem IDs no build, usa os blocos de TESTE do Google', () {
      expect(
          MonetizationConfig.bannerAdUnitId, MonetizationConfig.testBannerId);
      expect(MonetizationConfig.rewardedAdUnitId,
          MonetizationConfig.testRewardedId);
      expect(MonetizationConfig.usesTestAds, isTrue);
      expect(
          MonetizationConfig.isTestAdUnit(
              'ca-app-pub-2201002106451470/5013583059'),
          isFalse);
    });

    test('link de gerenciar assinatura aponta para o pacote do app', () {
      expect(
        MonetizationConfig.manageSubscriptionsUrl(
            productId: 'bosyn_pro_mensal'),
        'https://play.google.com/store/account/subscriptions?sku=bosyn_pro_mensal&package=com.bosyn.app',
      );
    });
  });

  test(
      'PlanOffer: botão diz plano, preço e período; ignora produto de fora e repetido',
      () {
    final offers = PlanOffer.fromStore(const [
      PlanOffer(productId: 'bosyn_pro_anual', price: r'R$ 179,90'),
      PlanOffer(productId: 'bosyn_pro_mensal', price: r'R$ 19,90'),
      PlanOffer(productId: 'bosyn_pro_mensal', price: r'R$ 99,90'),
      PlanOffer(productId: 'moedas', price: r'R$ 1,00'),
    ]);
    expect(offers.map((o) => o.buttonLabel), [
      r'Assinar Mensal: R$ 19,90 por mês',
      r'Assinar Anual: R$ 179,90 por ano',
    ]);
  });
}
