import 'package:flutter/material.dart';

/// Barra superior dos treinos por tempo: título, "Terminar" (depois da primeira resposta) e a
/// barra de progresso da sessão de ~10 minutos.
class TrainingAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool canFinish;
  final VoidCallback onFinish;
  final double progress;
  final Color color;

  const TrainingAppBar({
    super.key,
    required this.title,
    required this.canFinish,
    required this.onFinish,
    required this.progress,
    this.color = Colors.greenAccent,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4);

  @override
  Widget build(BuildContext context) => AppBar(
        backgroundColor: Colors.transparent,
        title: Text(title, style: const TextStyle(fontSize: 18)),
        actions: [
          if (canFinish)
            TextButton(onPressed: onFinish, child: const Text('Terminar', style: TextStyle(fontSize: 16))),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      );
}

/// Guarda de audibilidade (Etapa 5): nenhuma pista aguda chega ao ouvido nem no máximo.
Future<void> showInaudibleHighFrequencyWarning(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Os sons agudos estão fora do alcance'),
        content: const Text(
          'Pelo seu teste, os sons agudos das palavras (como o "s") não chegam ao seu ouvido nem '
          'no volume máximo. Treinar não consegue criar essa percepção. Procure um '
          'fonoaudiólogo: um aparelho auditivo pode trazer esses sons de volta. '
          'Por enquanto, o treino vai usar só palavras com sons mais graves.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi'))],
      ),
    );
