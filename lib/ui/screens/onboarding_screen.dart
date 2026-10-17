import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../audio_engine/audio_engine.dart';
import '../../core/legal_documents.dart';
import '../../screens/hearing_test/hearing_test_flow.dart';
import '../../services/supabase_service.dart';
import 'home_screen.dart';

/// SCREEN: Onboarding e Teste Auditivo Inicial [ORQUESTRADOR]
///
/// Linguagem comum, texto de pelo menos 16 px, botões com nome acessível e um check de som que
/// pergunta se a pessoa ouviu (auditoria de UX, etapa B).
class OnboardingScreen extends StatelessWidget {
  /// Chamado ao concluir (o SessionGate troca para a Home). Sem ele, navega direto para a Home.
  final VoidCallback? onCompleted;

  const OnboardingScreen({super.key, this.onCompleted});

  static const _accent = Color(0xFF00FF41);
  static const _textSecondary = Color(0xFFB0B0B0);

  /// [runTest] = false quando o usuário escolhe "Fazer o teste depois": conclui o onboarding sem
  /// abrir o teste auditivo (a Home oferece o teste depois, antes do primeiro treino).
  Future<void> _completeOnboarding(BuildContext context,
      {required bool runTest}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    var postponed = !runTest;

    // Verifica se já tem audiograma. Se não tiver, conduz ao teste.
    final existing =
        runTest ? await SupabaseService().getPatientHistory(user.id) : const [];
    if (runTest && existing.isEmpty && context.mounted) {
      // Voltou sem terminar: equivale a adiar; a Home pede o teste antes do primeiro treino.
      final saved = await HearingTestFlow.runAndSave(context);
      if (saved == null) postponed = true;
    }

    await Supabase.instance.client
        .from('profiles')
        .update({'onboarding_completed': true}).eq('user_id', user.id);

    if (postponed) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'Tudo bem. Você pode fazer o teste de audição quando quiser, pela tela inicial.',
            style: TextStyle(fontSize: 15)),
      ));
    }

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
          title: 'Antes de começar',
          body: LegalDocuments.healthDisclaimer,
          decoration: _pageDecoration(),
        ),
        PageViewModel(
          title: 'Como funciona',
          body:
              'Você vai ouvir palavras parecidas, como "sala" e "fala", e escolher a que ouviu. '
              'O treino ensina a aproveitar melhor os sons que você ainda ouve. Ele não recupera '
              'a audição perdida. Treine um pouco todos os dias.',
          decoration: _pageDecoration(),
        ),
        PageViewModel(
          title: 'Prepare o fone',
          body:
              'Coloque os fones de ouvido e procure um lugar silencioso. Toque no botão abaixo '
              'e ajuste o volume do celular até ouvir o som com clareza, sem incomodar.',
          footer: const _SoundCheck(),
          decoration: _pageDecoration(),
        ),
        PageViewModel(
          title: 'Teste de audição',
          body:
              'Leva uns 10 minutos. Você vai ouvir bipes, um ouvido de cada vez. Toque em '
              '"Ouvi" sempre que escutar, mesmo quando o som for bem fraquinho.\n\n'
              'O resultado ajusta o treino ao seu jeito de ouvir. É uma estimativa feita com o '
              'seu fone, não um exame.',
          decoration: _pageDecoration(),
        ),
      ],
      onDone: () => _completeOnboarding(context, runTest: true),
      onSkip: () => _completeOnboarding(context, runTest: false),
      showSkipButton: true,
      skip: const Text('Fazer o teste depois',
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSecondary, fontSize: 15)),
      skipSemantic: 'Fazer o teste de audição depois',
      skipStyle: _buttonStyle(),
      next: const Icon(Icons.arrow_forward, color: _accent, size: 28),
      nextSemantic: 'Próximo',
      nextStyle: _buttonStyle(),
      done: const Text('Começar o teste',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: _accent, fontWeight: FontWeight.bold, fontSize: 16)),
      doneSemantic: 'Começar o teste de audição',
      doneStyle: _buttonStyle(),
      dotsDecorator: const DotsDecorator(
        size: Size(10, 10),
        color: Color(0xFF707070), // 3,9:1 sobre o fundo (WCAG 1.4.11)
        activeColor: _accent,
        activeSize: Size(22, 10),
        activeShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(25))),
      ),
    );
  }

  static ButtonStyle _buttonStyle() =>
      TextButton.styleFrom(minimumSize: const Size(48, 48));

  PageDecoration _pageDecoration() {
    return const PageDecoration(
      titleTextStyle: TextStyle(
        color: _accent,
        fontSize: 26,
        fontWeight: FontWeight.w800,
      ),
      bodyTextStyle: TextStyle(color: Colors.white, fontSize: 17, height: 1.5),
      pageColor: Color(0xFF0A0A0A),
      imagePadding: EdgeInsets.zero,
    );
  }
}

/// Check de som: toca o tom de 1 kHz e pergunta se a pessoa ouviu, com orientação se não ouviu.
class _SoundCheck extends StatefulWidget {
  const _SoundCheck();

  @override
  State<_SoundCheck> createState() => _SoundCheckState();
}

enum _CheckState { idle, playing, asking, heard, notHeard }

class _SoundCheckState extends State<_SoundCheck> {
  _CheckState _state = _CheckState.idle;

  Future<void> _play() async {
    setState(() => _state = _CheckState.playing);
    try {
      final duration = await AudioRehabEngine()
          .playCalibrationTone(frequencyHz: 1000.0, durationSeconds: 2.0);
      await Future.delayed(duration);
    } catch (e) {
      debugPrint('Falha ao tocar o som de teste: $e');
    }
    if (mounted) setState(() => _state = _CheckState.asking);
  }

  @override
  Widget build(BuildContext context) {
    final playing = _state == _CheckState.playing;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: OnboardingScreen._accent,
              side: const BorderSide(color: OnboardingScreen._accent),
              minimumSize: const Size(48, 56),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: playing ? null : _play,
            icon: const Icon(Icons.volume_up),
            label: Text(
                playing
                    ? 'Tocando…'
                    : _state == _CheckState.idle
                        ? 'Tocar som de teste'
                        : 'Tocar de novo',
                style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 16),
          Semantics(liveRegion: true, child: _buildFeedback()),
        ],
      ),
    );
  }

  Widget _buildFeedback() {
    switch (_state) {
      case _CheckState.idle:
      case _CheckState.playing:
        return const SizedBox.shrink();
      case _CheckState.asking:
        return Column(
          children: [
            const Text('Você ouviu o som?',
                style: TextStyle(color: Colors.white, fontSize: 17)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                _answer('Ouvi bem', _CheckState.heard),
                _answer('Não ouvi', _CheckState.notHeard),
              ],
            ),
          ],
        );
      case _CheckState.heard:
        return const Text(
          'Ótimo. Mantenha esse volume e avance.',
          textAlign: TextAlign.center,
          style: TextStyle(color: OnboardingScreen._accent, fontSize: 16),
        );
      case _CheckState.notHeard:
        return const Text(
          'Confira se o fone está conectado e bem colocado, aumente o volume do celular e '
          'toque de novo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFFFBF00), fontSize: 16, height: 1.4),
        );
    }
  }

  Widget _answer(String label, _CheckState next) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF1A1A1A),
        minimumSize: const Size(120, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => setState(() => _state = next),
      child: Text(label, style: const TextStyle(fontSize: 16)),
    );
  }
}
