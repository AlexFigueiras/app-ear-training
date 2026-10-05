import 'package:flutter/material.dart';

/// Peças da Home revisadas pela auditoria de UX (F1 e E2): próximo passo para quem está
/// começando, cards de treino que refletem o plano real e aviso honesto do PRO.
/// Contraste conferido contra #0A0A0A/#111111 (WCAG 1.4.3 e 1.4.11); nada abaixo de 14 px.
class HomeColors {
  const HomeColors._();
  static const accent = Color(0xFF00FF41);
  static const card = Color(0xFF111111);
  static const surface = Color(0xFF1A1A1A);
  static const border = Color(0xFF3A3A3A);
  static const textSecondary = Color(0xFFB0B0B0);
  static const primaryButton = Color(0xFF2563EB);
  static const amber = Color(0xFFFFBF00);
}

/// Um treino da Home: nome em linguagem comum e o que a pessoa faz nele.
class TrainingLevel {
  final int level;
  final String title;
  final String description;

  const TrainingLevel(this.level, this.title, this.description);

  static const all = [
    TrainingLevel(2, 'Palavras parecidas',
        'Ouça uma palavra e escolha entre duas parecidas, como "sala" e "fala".'),
    TrainingLevel(3, 'Voz de um lado, barulho do outro',
        'Entenda a voz que vem de um lado com barulho do outro, como numa mesa de restaurante.'),
    TrainingLevel(4, 'Conversa no barulho',
        'Entenda palavras com ruído de fundo, como num restaurante.'),
  ];
}

/// Cartão de próximo passo no topo da Home (achado E2).
class NextStepCard extends StatelessWidget {
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onPressed;

  const NextStepCard({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HomeColors.surface,
        border: Border.all(color: HomeColors.amber),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.hearing, color: HomeColors.amber, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body,
              style: const TextStyle(
                  color: HomeColors.textSecondary, fontSize: 16, height: 1.45)),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: HomeColors.primaryButton,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onPressed,
              child: Text(actionLabel,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card de treino. [locked] vem do plano real do usuário, não de um valor fixo (achado F1).
class LevelCard extends StatelessWidget {
  final TrainingLevel level;
  final bool locked;
  final VoidCallback onTap;

  const LevelCard(
      {super.key,
      required this.level,
      required this.locked,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = locked
        ? 'Plano PRO, em breve'
        : level.level == 2
            ? 'Grátis'
            : null;
    return Semantics(
      button: true,
      label: [level.title, level.description, if (status != null) status]
          .join('. '),
      excludeSemantics: true,
      child: Material(
        color: HomeColors.card,
        shape: RoundedRectangleBorder(
          side: BorderSide(
              color: locked ? HomeColors.border : HomeColors.primaryButton),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(level.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(level.description,
                          style: const TextStyle(
                              color: HomeColors.textSecondary,
                              fontSize: 15,
                              height: 1.4)),
                      if (status != null) ...[
                        const SizedBox(height: 6),
                        Text(status,
                            style: TextStyle(
                                color: locked
                                    ? HomeColors.amber
                                    : HomeColors.accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(locked ? Icons.lock_outline : Icons.play_circle_fill,
                    color:
                        locked ? HomeColors.textSecondary : HomeColors.accent,
                    size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado vazio do gráfico: em vez de um ponto falso em 0%, explica o que vai aparecer.
class EmptyProgressNote extends StatelessWidget {
  const EmptyProgressNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HomeColors.surface,
        border: Border.all(color: HomeColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Seus acertos aparecem aqui depois do primeiro treino.',
        style: TextStyle(color: HomeColors.textSecondary, fontSize: 16),
      ),
    );
  }
}

/// Aviso do PRO enquanto não há compra na loja: diz o que é, que ainda não está à venda e o
/// que fazer agora. Quando a venda existir, a folha precisa mostrar preço ("R$ X/mês"),
/// renovação e cancelamento (App Store 3.1.2 / política de assinaturas da Google Play).
Future<void> showProComingSoonSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: HomeColors.surface,
    showDragHandle: true,
    // Cresce até o tamanho do conteúdo: com a altura padrão (9/16 da tela) o botão ficava
    // abaixo da dobra em celulares pequenos.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: const Text('Plano PRO em breve',
                    style: TextStyle(
                        color: HomeColors.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Os treinos "Voz de um lado, barulho do outro" e "Conversa no barulho" vão fazer parte do '
                'plano PRO, que ainda não está à venda. Nada será cobrado sem a sua '
                'confirmação na loja de aplicativos.',
                style:
                    TextStyle(color: Colors.white, fontSize: 16, height: 1.45),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enquanto isso, continue com "Palavras parecidas", o treino base do programa.',
                style: TextStyle(
                    color: HomeColors.textSecondary,
                    fontSize: 16,
                    height: 1.45),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HomeColors.primaryButton,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendi',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
