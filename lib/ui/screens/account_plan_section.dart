import 'package:flutter/material.dart';

import '../../monetization/monetization_config.dart';
import '../../monetization/pro_access.dart';
import '../../services/ads_service.dart';
import '../../services/billing_service.dart';
import '../../services/external_links.dart';
import '../../services/gatekeeper_service.dart';

/// Plano na tela de conta [MONETIZAÇÃO]: situação do PRO, gerenciar ou cancelar a assinatura no
/// Google Play, restaurar a compra e, onde a lei pede (UE/Reino Unido), a privacidade dos
/// anúncios.
class AccountPlanSection extends StatefulWidget {
  const AccountPlanSection({super.key});

  @override
  State<AccountPlanSection> createState() => _AccountPlanSectionState();
}

class _AccountPlanSectionState extends State<AccountPlanSection> {
  late Future<ProAccess> _access;
  late int _seenPlanVersion;

  @override
  void initState() {
    super.initState();
    _seenPlanVersion = BillingService().planVersion;
    _access = _loadAccess();
    BillingService().addListener(_onBillingChanged);
    AdsService().addListener(_onAdsChanged);
  }

  @override
  void dispose() {
    BillingService().removeListener(_onBillingChanged);
    AdsService().removeListener(_onAdsChanged);
    super.dispose();
  }

  Future<ProAccess> _loadAccess() =>
      GatekeeperService().loadAccess().catchError((_) => ProAccess.free);

  void _onBillingChanged() {
    final version = BillingService().planVersion;
    if (version == _seenPlanVersion || !mounted) return;
    _seenPlanVersion = version;
    setState(() => _access = _loadAccess());
  }

  void _onAdsChanged() {
    if (mounted) setState(() {});
  }

  static String _date(DateTime d) {
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }

  static String _planText(ProAccess? access) {
    if (access == null || !access.isActiveAt(DateTime.now())) {
      return 'Plano grátis';
    }
    final expiresAt = access.expiresAt;
    return expiresAt == null
        ? 'Plano PRO ativo'
        : 'Plano PRO ativo até ${_date(expiresAt)}';
  }

  Future<void> _manage() async {
    final opened = await const ExternalLinks()
        .open(MonetizationConfig.manageSubscriptionsUrl());
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content:
          Text('Abra o Google Play, toque na sua foto e vá em "Pagamentos e '
              'assinaturas" → "Assinaturas".'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Seu plano',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        FutureBuilder<ProAccess>(
          future: _access,
          builder: (context, snapshot) => Text(
            snapshot.connectionState == ConnectionState.done
                ? _planText(snapshot.data)
                : 'Conferindo o plano…',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        _action(Icons.open_in_new,
            'Gerenciar ou cancelar a assinatura no Google Play', _manage),
        _action(Icons.restore, 'Restaurar compra',
            () => BillingService().restore(userInitiated: true)),
        if (AdsService().privacyOptionsRequired)
          _action(Icons.privacy_tip_outlined, 'Privacidade dos anúncios',
              () => AdsService().showPrivacyOptions()),
      ],
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: Colors.white),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        onTap: onTap,
      );
}
