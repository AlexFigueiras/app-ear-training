import 'package:flutter/material.dart';

import '../../monetization/plan_offer.dart';
import 'home_widgets.dart' show HomeColors;

enum ProChoiceKind { subscribe, watchVideo, restore }

/// O que a pessoa escolheu na folha do PRO.
class ProChoice {
  final ProChoiceKind kind;
  final String? productId;

  const ProChoice.subscribe(String this.productId)
      : kind = ProChoiceKind.subscribe;
  const ProChoice.watchVideo()
      : kind = ProChoiceKind.watchVideo,
        productId = null;
  const ProChoice.restore()
      : kind = ProChoiceKind.restore,
        productId = null;
}

/// Folha do plano PRO para quem não assina [MONETIZAÇÃO]: assinar (com preço, período,
/// renovação e cancelamento à vista, como pede a política de assinaturas da Google Play) ou
/// liberar 1 sessão com um vídeo. Nada é cobrado sem a confirmação na tela do Google Play.
Future<ProChoice?> showProOfferSheet(
  BuildContext context, {
  required String trainingTitle,
  required List<PlanOffer> plans,
  required bool storeAvailable,
  required int videosLeft,
  required bool videosAvailable,
}) {
  return showModalBottomSheet<ProChoice>(
    context: context,
    backgroundColor: HomeColors.surface,
    showDragHandle: true,
    // Cresce até o tamanho do conteúdo: com a altura padrão os botões ficariam abaixo da dobra
    // em celulares pequenos.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => ProOfferSheet(
      trainingTitle: trainingTitle,
      plans: plans,
      storeAvailable: storeAvailable,
      videosLeft: videosLeft,
      videosAvailable: videosAvailable,
    ),
  );
}

class ProOfferSheet extends StatelessWidget {
  final String trainingTitle;
  final List<PlanOffer> plans;
  final bool storeAvailable;
  final int videosLeft;
  final bool videosAvailable;

  const ProOfferSheet({
    super.key,
    required this.trainingTitle,
    required this.plans,
    required this.storeAvailable,
    required this.videosLeft,
    required this.videosAvailable,
  });

  static const _body =
      TextStyle(color: Colors.white, fontSize: 16, height: 1.45);
  static const _secondary =
      TextStyle(color: HomeColors.textSecondary, fontSize: 15, height: 1.45);
  static const _heading =
      TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700);

  String get _videoText {
    if (!videosAvailable) {
      return 'Os vídeos não estão disponíveis agora. Tente daqui a pouco.';
    }
    if (videosLeft <= 0) {
      return 'Você já usou os vídeos de hoje. Volte amanhã ou assine o plano PRO.';
    }
    final left = videosLeft == 1
        ? 'Resta 1 vídeo hoje.'
        : 'Restam $videosLeft vídeos hoje.';
    return 'Assista a um vídeo curto e faça 1 sessão deste treino. $left';
  }

  @override
  Widget build(BuildContext context) {
    final canSubscribe = storeAvailable && plans.isNotEmpty;
    final canWatch = videosAvailable && videosLeft > 0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: const Text('Treino do plano PRO',
                  style: TextStyle(
                      color: HomeColors.accent,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 12),
            Text(
                '"$trainingTitle" faz parte do plano PRO. Escolha como quer continuar.',
                style: _body),
            const SizedBox(height: 24),
            const Text('Assinar o plano PRO', style: _heading),
            const SizedBox(height: 6),
            const Text(
                'Libera todos os treinos, quantas vezes quiser, sem anúncios.',
                style: _body),
            const SizedBox(height: 12),
            if (canSubscribe)
              for (final plan in plans) ...[
                _button(
                  label: plan.buttonLabel,
                  filled: true,
                  onPressed: () => Navigator.pop(
                      context, ProChoice.subscribe(plan.productId)),
                ),
                const SizedBox(height: 10),
              ]
            else
              const Text(
                'A assinatura não está disponível agora. Confira se o Google Play está '
                'atualizado e tente mais tarde.',
                style: _secondary,
              ),
            const Text(
              'A assinatura renova sozinha pelo mesmo preço até você cancelar. Cancele quando '
              'quiser no Google Play, em "Pagamentos e assinaturas". A cobrança é feita na sua '
              'conta Google.',
              style: _secondary,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () =>
                    Navigator.pop(context, const ProChoice.restore()),
                child: const Text('Já assino: restaurar compra',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
            const Divider(height: 32, color: HomeColors.border),
            const Text('Treinar agora com um vídeo', style: _heading),
            const SizedBox(height: 6),
            Text(_videoText, style: _body),
            const SizedBox(height: 12),
            _button(
              label: 'Ver vídeo e treinar',
              filled: false,
              onPressed: canWatch
                  ? () => Navigator.pop(context, const ProChoice.watchVideo())
                  : null,
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: HomeColors.textSecondary),
              onPressed: () => Navigator.pop(context),
              child: const Text('Agora não', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(
      {required String label, required bool filled, VoidCallback? onPressed}) {
    final child = Text(label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700));
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: filled
          ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: HomeColors.primaryButton,
                foregroundColor: Colors.white,
                padding: padding,
                shape: shape,
              ),
              onPressed: onPressed,
              child: child,
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: HomeColors.accent,
                side: const BorderSide(color: HomeColors.accent),
                padding: padding,
                shape: shape,
              ),
              onPressed: onPressed,
              child: child,
            ),
    );
  }
}
