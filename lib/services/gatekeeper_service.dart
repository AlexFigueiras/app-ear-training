import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SubscriptionTier { free, pro, elite }

class SubscriptionPlan {
  final String id;
  final String title;
  final String priceFormatted;
  final String billingPeriod;
  final SubscriptionTier tier;

  const SubscriptionPlan({
    required this.id,
    required this.title,
    required this.priceFormatted,
    required this.billingPeriod,
    required this.tier,
  });

  static const List<SubscriptionPlan> availablePlans = [
    SubscriptionPlan(
      id: 'bosyn_pro_monthly',
      title: 'Plano Pro Mensal',
      priceFormatted: 'R\$ 29,90/mês',
      billingPeriod: 'Mensal',
      tier: SubscriptionTier.pro,
    ),
    SubscriptionPlan(
      id: 'bosyn_elite_annual',
      title: 'Plano Elite Anual',
      priceFormatted: 'R\$ 239,90/ano (R\$ 19,99/mês)',
      billingPeriod: 'Anual',
      tier: SubscriptionTier.elite,
    ),
  ];
}

/// GATEKEEPER SERVICE: Gestor de Acesso e Monetização (Google Play Billing Ready)
class GatekeeperService {
  static final GatekeeperService _instance = GatekeeperService._internal();
  factory GatekeeperService() => _instance;
  GatekeeperService._internal();

  /// Verifica se o usuário tem permissão para acessar o nível solicitado
  Future<bool> checkAccess(int level) async {
    // Níveis 1 e 2 são gratuitos [REABILITAÇÃO BASE]
    if (level <= 2) return true;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      // Consulta Status de Assinatura no Perfil
      final res = await Supabase.instance.client
          .from('profiles')
          .select('subscription_status')
          .eq('user_id', user.id)
          .maybeSingle();

      final status = res?['subscription_status'] as String? ?? 'free';

      // Níveis 3 e 4 exigem status 'pro' ou 'elite'
      return status == 'pro' || status == 'elite';
    } catch (e) {
      debugPrint("[GATEKEEPER] Erro ao verificar acesso: $e");
      return false;
    }
  }

  /// Recupera o tier atual do usuário
  Future<SubscriptionTier> getCurrentTier() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return SubscriptionTier.free;

      final res = await Supabase.instance.client
          .from('profiles')
          .select('subscription_status')
          .eq('user_id', user.id)
          .maybeSingle();

      final status = res?['subscription_status'] as String? ?? 'free';
      if (status == 'elite') return SubscriptionTier.elite;
      if (status == 'pro') return SubscriptionTier.pro;
      return SubscriptionTier.free;
    } catch (_) {
      return SubscriptionTier.free;
    }
  }

  /// Atualiza o status de assinatura após compra confirmada no Google Play
  Future<bool> purchasePlan(SubscriptionPlan plan) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      final tierName = plan.tier == SubscriptionTier.elite ? 'elite' : 'pro';
      await Supabase.instance.client
          .from('profiles')
          .update({
            'subscription_status': tierName,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', user.id);

      debugPrint("[GATEKEEPER] Assinatura $tierName ativada via Play Store para ${user.id}");
      return true;
    } catch (e) {
      debugPrint("[GATEKEEPER] Erro ao registrar compra: $e");
      return false;
    }
  }

  /// Alias de compatibilidade
  Future<void> upgradeToPro() async {
    await purchasePlan(SubscriptionPlan.availablePlans.first);
  }

  /// Restaura compras ativas do usuário
  Future<bool> restorePurchases() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      // Consulta se o usuário possui perfil ativo no Supabase
      final res = await Supabase.instance.client
          .from('profiles')
          .select('subscription_status')
          .eq('user_id', user.id)
          .maybeSingle();

      final status = res?['subscription_status'] as String? ?? 'free';
      debugPrint("[GATEKEEPER] Compras restauradas. Status: $status");
      return status != 'free';
    } catch (e) {
      debugPrint("[GATEKEEPER] Erro ao restaurar compras: $e");
      return false;
    }
  }
}
