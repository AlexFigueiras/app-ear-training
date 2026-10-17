import 'package:flutter/material.dart';

import '../models/audiogram.dart';
import 'speech_in_noise_screen.dart';

/// Treino espacial (Etapa 9 do plano): a voz vem de um lado e o burburinho do outro. É o mesmo
/// fluxo da "Conversa no barulho" (escada salva, 4 opções, retorno, resumo), no modo
/// [NoiseTraining.spatial]. O antigo "de que lado veio" tocava a palavra num ouvido só (pan ±1)
/// e não tinha adaptação: qualquer pessoa com os dois ouvidos acertava quase tudo.
class SpatialAttentionScreen extends StatelessWidget {
  final Audiogram audiogram;

  const SpatialAttentionScreen({super.key, required this.audiogram});

  @override
  Widget build(BuildContext context) =>
      SpeechInNoiseScreen(audiogram: audiogram, training: NoiseTraining.spatial);
}
