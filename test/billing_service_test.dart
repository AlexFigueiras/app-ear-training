import 'dart:async';

import 'package:ear_training/monetization/plan_offer.dart';
import 'package:ear_training/services/billing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class _FakeStore implements PurchaseStore {
  final controller = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <String>[];
  final bought = <String>[];
  bool available = true;
  bool buyOpens = true;
  List<PurchaseDetails> restorable = [];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<PlanOffer>> loadOffers(Set<String> productIds) async => const [
        PlanOffer(productId: 'bosyn_pro_anual', price: r'R$ 179,90'),
        PlanOffer(productId: 'outro_produto', price: r'R$ 1,00'),
        PlanOffer(productId: 'bosyn_pro_mensal', price: r'R$ 19,90'),
      ];

  @override
  Future<bool> buy(String productId, {required String accountId}) async {
    bought.add('$productId:$accountId');
    return buyOpens;
  }

  @override
  Future<void> complete(PurchaseDetails purchase) async =>
      completed.add(purchase.verificationData.serverVerificationData);

  @override
  Future<void> restore() async => controller.add(restorable);
}

class _FakeVerifier implements PurchaseVerifier {
  final verified = <String>[];
  Object? failure;
  bool entitled = true;

  @override
  Future<VerifiedPlan> verify(String purchaseToken) async {
    verified.add(purchaseToken);
    if (failure != null) throw failure!;
    return VerifiedPlan(
        entitled: entitled, expiresAt: DateTime.utc(2026, 11, 17));
  }
}

PurchaseDetails _purchase(String token, PurchaseStatus status,
    {bool pendingComplete = true}) {
  return PurchaseDetails(
    purchaseID: 'GPA.$token',
    productID: 'bosyn_pro_mensal',
    verificationData: PurchaseVerificationData(
        localVerificationData: '{}',
        serverVerificationData: token,
        source: 'google_play'),
    transactionDate: '0',
    status: status,
  )..pendingCompletePurchase = pendingComplete;
}

void main() {
  late _FakeStore store;
  late _FakeVerifier verifier;
  late BillingService billing;
  late List<String> messages;

  setUp(() async {
    store = _FakeStore();
    verifier = _FakeVerifier();
    billing = BillingService.forTest(store, verifier, () => 'user-1');
    messages = [];
    billing.messages.listen(messages.add);
    await billing.start();
  });

  Future<void> emit(List<PurchaseDetails> purchases) async {
    store.controller.add(purchases);
    await pumpEventQueue();
  }

  test('carrega só os planos do BOSYN, mensal primeiro', () {
    expect(billing.storeAvailable, isTrue);
    expect(billing.offers.map((o) => o.buttonLabel), [
      r'Assinar Mensal: R$ 19,90 por mês',
      r'Assinar Anual: R$ 179,90 por ano',
    ]);
  });

  test('compra leva o SHA-256 do usuário como id da conta (igual ao servidor)',
      () async {
    await billing.buy('bosyn_pro_mensal');
    expect(store.bought,
        ['bosyn_pro_mensal:${BillingService.accountIdFor('user-1')}']);
    expect(BillingService.accountIdFor('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });

  test('compra aprovada: confere no servidor, conclui na Play e avisa',
      () async {
    final version = billing.planVersion;
    await emit([_purchase('tok-1', PurchaseStatus.purchased)]);

    expect(verifier.verified, ['tok-1']);
    expect(store.completed, ['tok-1']);
    expect(billing.planVersion, version + 1);
    expect(messages, ['Pronto! Plano PRO ativo. Bons treinos.']);
    expect(billing.phase, BillingPhase.idle);
  });

  test('pagamento pendente não libera nada nem conclui a compra', () async {
    await emit([_purchase('tok-1', PurchaseStatus.pending)]);
    expect(verifier.verified, isEmpty);
    expect(store.completed, isEmpty);
    expect(messages.single, contains('Pagamento pendente'));
  });

  test('servidor fora do ar: não conclui (a compra é conferida de novo depois)',
      () async {
    verifier.failure = const PurchaseRejected(502, 'play_unavailable');
    await emit([_purchase('tok-1', PurchaseStatus.purchased)]);
    expect(store.completed, isEmpty);
    expect(messages.single, contains('próxima vez que você abrir o app'));
  });

  test('sem conexão (status 0) também não conclui', () async {
    verifier.failure = const PurchaseRejected(0, 'http_0');
    await emit([_purchase('tok-1', PurchaseStatus.purchased)]);
    expect(store.completed, isEmpty);
  });

  test('assinatura de outra conta do BOSYN: conclui, não libera e explica',
      () async {
    verifier.failure =
        const PurchaseRejected(409, 'purchase_owned_by_other_account');
    final version = billing.planVersion;
    await emit([_purchase('tok-1', PurchaseStatus.purchased)]);
    expect(store.completed, ['tok-1']);
    expect(billing.planVersion, version);
    expect(messages.single, contains('ligada a outra conta do BOSYN'));
  });

  test('restauração silenciosa confere sem mostrar aviso', () async {
    store.restorable = [
      _purchase('tok-1', PurchaseStatus.restored, pendingComplete: false)
    ];
    await billing.restore();
    await pumpEventQueue();
    expect(verifier.verified, ['tok-1']);
    expect(store.completed, isEmpty, reason: 'já estava concluída');
    expect(messages, isEmpty);
  });

  test('restauração pedida pela pessoa sempre dá retorno', () async {
    await billing.restore(userInitiated: true);
    await pumpEventQueue();
    expect(messages, ['Nenhuma assinatura ativa nesta conta Google.']);

    store.restorable = [_purchase('tok-1', PurchaseStatus.restored)];
    await billing.restore(userInitiated: true);
    await pumpEventQueue();
    expect(messages.last, 'Assinatura encontrada: plano PRO ativo.');
  });

  test('erro e cancelamento na Play concluem a transação sem liberar',
      () async {
    await emit([
      _purchase('tok-err', PurchaseStatus.error),
      _purchase('tok-cancel', PurchaseStatus.canceled),
    ]);
    expect(verifier.verified, isEmpty);
    expect(store.completed, ['tok-err', 'tok-cancel']);
    expect(messages, ['A compra não foi concluída. Tente de novo.']);
  });

  test('Play indisponível: não quebra e avisa ao tentar comprar', () async {
    final offline = _FakeStore()..available = false;
    final service = BillingService.forTest(offline, verifier, () => 'user-1');
    final said = <String>[];
    service.messages.listen(said.add);
    await service.start();
    expect(service.storeAvailable, isFalse);
    expect(service.offers, isEmpty);

    await service.buy('bosyn_pro_mensal');
    await pumpEventQueue();
    expect(offline.bought, isEmpty);
    expect(said.single, contains('não está disponível'));
  });

  test('restauração com assinatura de outra conta: só o aviso que explica',
      () async {
    verifier.failure =
        const PurchaseRejected(409, 'purchase_owned_by_other_account');
    store.restorable = [_purchase('tok-1', PurchaseStatus.restored)];
    await billing.restore(userInitiated: true);
    await pumpEventQueue();
    expect(messages, hasLength(1));
    expect(messages.single, contains('ligada a outra conta do BOSYN'));
  });

  test('restauração sem conexão com o servidor: não diz que não há assinatura',
      () async {
    verifier.failure = const PurchaseRejected(0, 'http_0');
    store.restorable = [_purchase('tok-1', PurchaseStatus.restored)];
    await billing.restore(userInitiated: true);
    await pumpEventQueue();
    expect(messages.single, contains('próxima vez que você abrir o app'));
  });

  test('plano que não carregou: avisa em vez de ficar quieto', () async {
    store.buyOpens = false;
    await billing.buy('bosyn_pro_anual');
    await pumpEventQueue();
    expect(messages.single, contains('não está disponível agora'));
    expect(billing.phase, BillingPhase.idle);
  });

  test('Play fora do ar ao abrir: a próxima chamada tenta de novo', () async {
    final flaky = _FakeStore()..available = false;
    final service = BillingService.forTest(flaky, verifier, () => 'user-1');
    await service.start();
    expect(service.storeAvailable, isFalse);

    flaky.available = true;
    await service.start();
    expect(service.storeAvailable, isTrue);
    expect(service.offers, hasLength(2));
  });
}
