import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/audiogram.dart';
import '../../services/supabase_service.dart';
import '../threshold_test_screen.dart';

/// Abrir o teste auditivo e salvar o resultado; pedir reteste de audiograma antigo.
class HearingTestFlow {
  const HearingTestFlow._();

  /// Abre o teste e salva. Devolve o audiograma salvo, ou null se a pessoa saiu sem terminar.
  static Future<Audiogram?> runAndSave(BuildContext context) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const ThresholdTestScreen()),
    );
    final user = Supabase.instance.client.auth.currentUser;
    if (result == null || user == null) return null;
    final audiogram = Audiogram(
      id: '',
      patientId: user.id,
      date: DateTime.now(),
      leftEar: List<AudiometryPoint>.from(result['left'] as List),
      rightEar: List<AudiometryPoint>.from(result['right'] as List),
    );
    await SupabaseService().saveAudiogram(audiogram);
    return audiogram;
  }

  /// O audiograma foi medido no teste antigo (através do compressor, que subestimava a perda em
  /// agudos, e sem 3 e 6 kHz)? Oferece refazer antes do treino. Devolve o audiograma a usar.
  static Future<Audiogram> ensureCurrent(BuildContext context, Audiogram audiogram) async {
    if (!audiogram.isOutdated) return audiogram;
    final redo = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refaça o teste de audição'),
        content: const Text(
          'O teste de audição do app foi melhorado e agora mede também os sons mais agudos. '
          'Seu resultado atual foi feito na versão antiga e pode estar errado. '
          'Leva uns 10 minutos.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Depois')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Refazer agora')),
        ],
      ),
    );
    if (redo != true || !context.mounted) return audiogram;
    return await runAndSave(context) ?? audiogram;
  }
}
