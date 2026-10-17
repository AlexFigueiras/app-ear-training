import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../monetization/monetization_config.dart';
import '../monetization/plan_offer.dart';
import 'billing_adapters.dart';

/// Operações da loja usadas pelo app: Google Play em produção ([InAppPurchaseStore]), fake nos
/// testes.
abstract class PurchaseStore {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<List<PlanOffer>> loadOffers(Set<String> productIds);

  /// Abre a compra da Play. [accountId] vai como obfuscatedAccountId (ver [accountIdFor]).
  Future<bool> buy(String productId, {required String accountId});
  Future<void> complete(PurchaseDetails purchase);
  Future<void> restore();
}

/// Plano confirmado pelo servidor para uma compra.
class VerifiedPlan {
  final bool entitled;
  final DateTime? expiresAt;

  const VerifiedPlan({required this.entitled, this.expiresAt});
}

/// Recusa do servidor ([status] HTTP; 0 = sem conexão) com o código de
/// `supabase/functions/play-subscription`.
class PurchaseRejected implements Exception {
  final int status;
  final String code;

  const PurchaseRejected(this.status, this.code);

  bool get isDefinitive => status >= 400 && status < 500;

  @override
  String toString() => 'PurchaseRejected($status, $code)';
}

/// Confere a compra no servidor (Edge Function `play-subscription`).
abstract class PurchaseVerifier {
  Future<VerifiedPlan> verify(String purchaseToken);
}

enum BillingPhase { idle, purchasing, verifying }

/// Assinatura PRO pelo Google Play Billing [MONETIZAÇÃO].
///
/// O app nunca decide o plano: cada compra (nova ou restaurada) vai para o servidor, que lê o
/// token na Google e grava o plano em `profiles` (migration 004). Só depois a compra é concluída
/// na Play — sem isso, a Play reembolsa em 3 dias, que é o certo se o servidor não liberou o PRO.
class BillingService extends ChangeNotifier {
  static final BillingService _instance = BillingService._(
    InAppPurchaseStore(),
    SupabasePurchaseVerifier(),
    currentUserId,
  );
  factory BillingService() => _instance;

  @visibleForTesting
  BillingService.forTest(
      PurchaseStore store, PurchaseVerifier verifier, String? Function() userId)
      : this._(store, verifier, userId);

  BillingService._(this._store, this._verifier, this._userId);

  final PurchaseStore _store;
  final PurchaseVerifier _verifier;
  final String? Function() _userId;
  final _messages = StreamController<String>.broadcast();
  final _inFlight = <String>{};

  Future<void>? _starting;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _available = false;
  List<PlanOffer> _offers = const [];
  BillingPhase _phase = BillingPhase.idle;
  int _planVersion = 0;
  bool _userRestore = false;
  bool _launchChecked = false;

  bool get storeAvailable => _available;
  List<PlanOffer> get offers => _offers;
  BillingPhase get phase => _phase;

  /// Sobe quando o servidor confirma um plano; quem mostra o plano relê o acesso.
  int get planVersion => _planVersion;

  /// Avisos para a pessoa (mostrados como SnackBar em qualquer tela, ver PurchaseMessages).
  Stream<String> get messages => _messages.stream;

  /// SHA-256 do id do usuário: a Play não recebe o id real, e o servidor calcula o mesmo valor
  /// para recusar compra de outra conta (`accountIdFor` em play_entitlement.ts).
  static String accountIdFor(String userId) =>
      sha256.convert(utf8.encode(userId)).toString();

  /// Liga a escuta das compras e carrega os planos. Pode ser chamado várias vezes.
  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    try {
      _available = await _store.isAvailable();
      if (!_available) return;
      _subscription = _store.purchaseStream.listen(_onPurchases,
          onError: (Object e) => debugPrint('[BILLING] stream: $e'));
      _offers = PlanOffer.fromStore(
          await _store.loadOffers(MonetizationConfig.subscriptionProductIds));
    } catch (e) {
      debugPrint('[BILLING] Play indisponível: $e');
      _available = false;
    } finally {
      notifyListeners();
    }
  }

  Future<void> buy(String productId) async {
    await start();
    final userId = _userId();
    if (!_available || userId == null) {
      _say('A assinatura não está disponível agora. Tente de novo mais tarde.');
      return;
    }
    _setPhase(BillingPhase.purchasing);
    try {
      final opened =
          await _store.buy(productId, accountId: accountIdFor(userId));
      if (!opened) _setPhase(BillingPhase.idle);
    } catch (e) {
      debugPrint('[BILLING] compra não abriu: $e');
      _setPhase(BillingPhase.idle);
      _say('Não foi possível abrir a compra no Google Play. Tente de novo.');
    }
  }

  /// Uma vez por abertura do app (Home): confere as compras da conta Google — renovação que
  /// estende a validade e compra que ficou sem conferência por falta de conexão.
  Future<void> checkOnLaunch() async {
    if (_launchChecked) return;
    _launchChecked = true;
    await restore();
  }

  /// Confere as compras da conta Google no aparelho. Silenciosa ao abrir o app (pega
  /// renovação e compra não concluída); com [userInitiated], sempre dá retorno.
  Future<void> restore({bool userInitiated = false}) async {
    await start();
    if (!_available) {
      if (userInitiated) {
        _say('O Google Play não está disponível neste aparelho agora.');
      }
      return;
    }
    _userRestore = userInitiated;
    try {
      await _store.restore();
    } catch (e) {
      debugPrint('[BILLING] restauração falhou: $e');
      if (userInitiated) {
        _userRestore = false;
        _say(
            'Não foi possível conferir as compras agora. Verifique a conexão e tente de novo.');
      }
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    final userRestore = _userRestore;
    _userRestore = false;
    var restoredPro = false;

    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _setPhase(BillingPhase.idle);
          _say(
              'Pagamento pendente. O plano PRO é liberado assim que o Google Play '
              'confirmar o pagamento.');
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final entitled = await _verify(purchase,
              announce:
                  purchase.status == PurchaseStatus.purchased || userRestore);
          restoredPro = restoredPro || entitled;
        case PurchaseStatus.error:
          _setPhase(BillingPhase.idle);
          _say('A compra não foi concluída. Tente de novo.');
          await _complete(purchase);
        case PurchaseStatus.canceled:
          _setPhase(BillingPhase.idle);
          await _complete(purchase);
      }
    }

    if (userRestore) {
      _say(restoredPro
          ? 'Assinatura encontrada: plano PRO ativo.'
          : 'Nenhuma assinatura ativa nesta conta Google.');
    }
  }

  /// Confere no servidor e conclui a compra na Play. Devolve se o PRO ficou ativo.
  Future<bool> _verify(PurchaseDetails purchase,
      {required bool announce}) async {
    final token = purchase.verificationData.serverVerificationData;
    if (!_inFlight.add(token)) return false;
    _setPhase(BillingPhase.verifying);
    try {
      final plan = await _verifier.verify(token);
      await _complete(purchase);
      _planVersion++;
      if (announce && purchase.status == PurchaseStatus.purchased) {
        _say(plan.entitled
            ? 'Pronto! Plano PRO ativo. Bons treinos.'
            : 'O Google Play ainda não confirmou o pagamento. Toque em "Restaurar compra" '
                'daqui a alguns minutos.');
      }
      return plan.entitled;
    } on PurchaseRejected catch (e) {
      debugPrint('[BILLING] servidor recusou: $e');
      if (!e.isDefinitive) {
        if (announce) {
          _say(
              'Não foi possível confirmar a compra agora. Vamos conferir de novo '
              'na próxima vez que você abrir o app.');
        }
        return false;
      }
      // Recusa definitiva: a compra é válida na conta Google (ex.: ligada a outra conta do
      // BOSYN), então é concluída; só não libera o PRO aqui.
      await _complete(purchase);
      if (announce) _say(_rejectionMessage(e.code));
      return false;
    } finally {
      _inFlight.remove(token);
      _setPhase(BillingPhase.idle);
    }
  }

  static String _rejectionMessage(String code) => switch (code) {
        'purchase_owned_by_other_account' ||
        'account_mismatch' =>
          'Esta assinatura do Google Play já está ligada a outra conta do BOSYN. '
              'Entre com essa conta para usar o plano PRO.',
        _ => 'Esta compra não é do plano PRO do BOSYN.',
      };

  Future<void> _complete(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _store.complete(purchase);
    } catch (e) {
      // O servidor já confirmou a compra na Play (acknowledge); aqui é só reforço.
      debugPrint('[BILLING] completePurchase: $e');
    }
  }

  void _setPhase(BillingPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    notifyListeners();
  }

  void _say(String message) => _messages.add(message);

  @override
  void dispose() {
    _subscription?.cancel();
    _messages.close();
    super.dispose();
  }
}
