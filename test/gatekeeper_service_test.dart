import 'package:flutter_test/flutter_test.dart';
import 'package:ear_training/services/gatekeeper_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GatekeeperService Clinical Access Rules Tests', () {
    test('Levels 1 and 2 are always free and accessible without auth', () async {
      final gatekeeper = GatekeeperService();

      expect(await gatekeeper.checkAccess(1), isTrue);
      expect(await gatekeeper.checkAccess(2), isTrue);
    });

    test('Available subscription plans contain valid Google Play identifiers', () {
      final plans = SubscriptionPlan.availablePlans;

      expect(plans.length, 2);
      expect(plans.any((p) => p.id == 'bosyn_pro_monthly'), isTrue);
      expect(plans.any((p) => p.id == 'bosyn_elite_annual'), isTrue);
      expect(plans.first.tier, SubscriptionTier.pro);
      expect(plans.last.tier, SubscriptionTier.elite);
    });
  });
}
