import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../monetization/plan_offer.dart';
import 'billing_service.dart';

/// Usuário logado no Supabase (dono da compra).
String? currentUserId() => Supabase.instance.client.auth.currentUser?.id;

/// [PurchaseStore] sobre o plugin oficial `in_app_purchase` (Play Billing Library 8).
class InAppPurchaseStore implements PurchaseStore {
  final Map<String, ProductDetails> _products = {};

  InAppPurchase get _iap => InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<List<PlanOffer>> loadOffers(Set<String> productIds) async {
    final response = await _iap.queryProductDetails(productIds);
    // Assinatura com um plano base e sem oferta: um ProductDetails por produto.
    for (final product in response.productDetails) {
      _products.putIfAbsent(product.id, () => product);
    }
    return [
      for (final product in _products.values)
        PlanOffer(productId: product.id, price: product.price),
    ];
  }

  @override
  Future<bool> buy(String productId, {required String accountId}) {
    final product = _products[productId];
    if (product == null) return Future.value(false);
    // Assinaturas usam buyNonConsumable; applicationUserName vira obfuscatedAccountId.
    return _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(
          productDetails: product, applicationUserName: accountId),
    );
  }

  @override
  Future<void> complete(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);

  @override
  Future<void> restore() => _iap.restorePurchases();
}

/// [PurchaseVerifier] pela Edge Function `play-subscription` (supabase/functions/).
class SupabasePurchaseVerifier implements PurchaseVerifier {
  @override
  Future<VerifiedPlan> verify(String purchaseToken) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('play-subscription', body: {'purchaseToken': purchaseToken});
      final data = response.data;
      if (data is! Map) throw const PurchaseRejected(502, 'invalid_response');
      final expires = data['expiresAt'];
      return VerifiedPlan(
        entitled: data['entitled'] == true,
        expiresAt: expires is String ? DateTime.tryParse(expires) : null,
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map && details['error'] is String
          ? details['error'] as String
          : 'http_${e.status}';
      throw PurchaseRejected(e.status, code);
    }
  }
}
