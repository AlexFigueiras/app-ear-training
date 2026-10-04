import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../audio_engine/audio_engine.dart';
import '../../core/legal_documents.dart';
import '../../models/audiogram.dart';
import '../../screens/threshold_test_screen.dart';
import '../../services/supabase_service.dart';
import 'home_screen.dart';

/// SCREEN: Onboarding e Teste Auditivo Inicial [ORQUESTRADOR]
class OnboardingScreen extends StatelessWidget {
  /// Chamado ao concluir (o SessionGate troca para a Home). Sem ele, navega direto para a Home.
  final VoidCallback? onCompleted;

  const OnboardingScreen({super.key, this.onCompleted});

  /// [runTest] = false quando o usuário escolhe "Pular teste": conclui o onboarding sem abrir o
  /// teste auditivo (a Home oferece o teste depois, antes do primeiro treino).
  Future<void> _completeOnboarding(BuildContext context, {required bool runTest}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Verifica se já tem audiograma. Se não tiver, conduz ao teste.
    final existing = runTest ? await SupabaseService().getPatientHistory(user.id) : const [];
    if (runTest && existing.isEmpty && context.mounted) {
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const ThresholdTestScreen()),
      );

      if (result != null) {
        final leftEar = List<AudiometryPoint>.from(result['left'] as List);
        final rightEar = List<AudiometryPoint>.from(result['right'] as List);
        final audiogram = Audiogram(
          id: '',
          patientId: user.id,
          date: DateTime.now(),
          leftEar: leftEar,
          rightEar: rightEar,
        );
        await SupabaseService().saveAudiogram(audiogram);
      }
    }

    await Supabase.instance.client
        .from('profiles')
        .update({'onboarding_completed': true})
        .eq('user_id', user.id);

    if (onCompleted != null) {
      onCompleted!();
    } else if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      globalBackgroundColor: const Color(0xFF0A0A0A),
      pages: [
        // Aviso de saúde antes de qualquer teste (política Health Content da Google Play).
        PageViewModel(
          title: "ANTES DE COMEÇAR",
          body: LegalDocuments.healthDisclaimer,
          decoration: _pageDecoration(),
        ),
        PageViewModel(
          title: "COMO FUNCIONA",
          body: "Você vai ouvir palavras parecidas, como \"sala\" e \"fala\", e escolher a que ouviu. "
              "O treino ensina a aproveitar melhor os sons que você ainda ouve. Ele não recupera "
              "a audição perdida. Treine um pouco todos os dias.",
          decoration: _pageDecoration(),
        ),
        PageViewModel(
          title: "CHECK DE HARDWARE",
          body: "Use fones de ouvido. Ajuste o volume até o tom de calibração estar confortável e nítido — nem alto demais, nem inaudível.",
          footer: _buildCalibrationControl(),
          decoration: _pageDecoration(),
        ),
        PageViewModel(
          title: "TESTE AUDITIVO",
          body: "Ao clicar em 'INICIAR', você será guiado por um breve teste de limiar auditivo. Isso permite ao sistema personalizar seu treino com base na sua perda específica.",
          decoration: _pageDecoration(),
        ),
      ],
      onDone: () => _completeOnboarding(context, runTest: true),
      onSkip: () => _completeOnboarding(context, runTest: false),
      showSkipButton: true,
      skip: const Text("PULAR TESTE", style: TextStyle(color: Colors.white24, fontSize: 10)),
      next: const Icon(Icons.arrow_forward, color: Color(0xFF00FF41)),
      done: const Text("INICIAR TESTE AUDITIVO", style: TextStyle(color: Color(0xFF00FF41), fontWeight: FontWeight.bold, fontSize: 10)),
      dotsDecorator: const DotsDecorator(
        size: Size(10, 10),
        color: Colors.white12,
        activeColor: Color(0xFF00FF41),
        activeSize: Size(22, 10),
        activeShape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(25))),
      ),
    );
  }

  Widget _buildCalibrationControl() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: const Color(0xFF00FF41),
              side: const BorderSide(color: Color(0xFF00FF41)),
              shape: const BeveledRectangleBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            onPressed: () => AudioRehabEngine().playCalibrationTone(frequencyHz: 1000.0, durationSeconds: 2.0),
            icon: const Icon(Icons.volume_up),
            label: const Text("TESTAR TOM (1kHz)", style: TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  PageDecoration _pageDecoration() {
    return const PageDecoration(
      titleTextStyle: TextStyle(
        color: Color(0xFF00FF41),
        fontSize: 24,
        fontWeight: FontWeight.w900,
        fontFamily: 'monospace',
        letterSpacing: 2,
      ),
      bodyTextStyle: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'monospace'),
      pageColor: Color(0xFF0A0A0A),
      imagePadding: EdgeInsets.zero,
    );
  }
}
