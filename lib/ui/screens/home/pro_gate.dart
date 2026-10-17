import 'package:flutter/material.dart';

import '../../../services/ads_service.dart';
import '../../../services/billing_service.dart';
import '../pro_offer_sheet.dart';

/// Treino PRO para quem não assina [MONETIZAÇÃO]: mostra a folha do PRO e executa a escolha.
///
/// Devolve true só quando a pessoa ganhou 1 sessão assistindo ao vídeo até o fim. A compra da
/// assinatura termina fora daqui: o resultado chega pelo [BillingService] (aviso na tela e
/// `planVersion`, que faz a Home reler o plano).
Future<bool> offerProSession(BuildContext context,
    {required String trainingTitle}) async {
  final billing = BillingService();
  final ads = AdsService();
  await billing.start();
  if (!context.mounted) return false;

  final choice = await showProOfferSheet(
    context,
    trainingTitle: trainingTitle,
    plans: billing.offers,
    storeAvailable: billing.storeAvailable,
    videosLeft: ads.remainingToday(),
    videosAvailable: ads.canRequestAds,
  );
  if (choice == null || !context.mounted) return false;

  switch (choice.kind) {
    case ProChoiceKind.subscribe:
      await billing.buy(choice.productId!);
      return false;
    case ProChoiceKind.restore:
      await billing.restore(userInitiated: true);
      return false;
    case ProChoiceKind.watchVideo:
      final messenger = ScaffoldMessenger.of(context);
      if (!ads.rewardedReady) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Carregando o vídeo…'),
            duration: Duration(seconds: 2)));
      }
      final outcome = await ads.showRewardedForSession();
      if (outcome == RewardedOutcome.earned) return true;
      messenger.showSnackBar(SnackBar(content: Text(_videoMessage(outcome))));
      return false;
  }
}

String _videoMessage(RewardedOutcome outcome) => switch (outcome) {
      RewardedOutcome.dismissed =>
        'O vídeo foi fechado antes do fim, então a sessão não foi liberada.',
      RewardedOutcome.limitReached =>
        'Você já usou os vídeos de hoje. Volte amanhã ou assine o plano PRO.',
      _ => 'Nenhum vídeo disponível agora. Tente daqui a pouco.',
    };
