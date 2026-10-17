import 'monetization_config.dart';

/// Um plano à venda na folha do PRO [MONETIZAÇÃO]. O preço vem da Play já formatado na moeda
/// e no idioma da pessoa (ex.: "R$ 19,90"); o app nunca escreve preço fixo.
class PlanOffer {
  final String productId;
  final String price;

  const PlanOffer({required this.productId, required this.price});

  bool get isYearly => productId == MonetizationConfig.yearlyProductId;

  String get name => isYearly ? 'Anual' : 'Mensal';

  String get period => isYearly ? 'por ano' : 'por mês';

  /// Texto do botão de compra, com o preço e o período (exigência da política de assinaturas).
  String get buttonLabel => 'Assinar $name: $price $period';

  /// Só os produtos do BOSYN, sem repetição, com o mensal primeiro.
  static List<PlanOffer> fromStore(Iterable<PlanOffer> offers) {
    final byId = <String, PlanOffer>{};
    for (final offer in offers) {
      if (MonetizationConfig.subscriptionProductIds.contains(offer.productId)) {
        byId.putIfAbsent(offer.productId, () => offer);
      }
    }
    return [
      for (final id in [
        MonetizationConfig.monthlyProductId,
        MonetizationConfig.yearlyProductId
      ])
        if (byId[id] != null) byId[id]!,
    ];
  }
}
