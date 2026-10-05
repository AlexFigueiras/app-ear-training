import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/gamification_controller.dart';
import '../../models/audiogram.dart';
import '../../models/rehab_session.dart';
import '../../screens/digits_in_noise_screen.dart';
import '../../screens/hearing_test/hearing_test_flow.dart';
import '../../screens/phonemic_discrimination_screen.dart';
import '../../screens/progress_screen.dart';
import '../../screens/spatial_attention_screen.dart';
import '../../screens/speech_in_noise_screen.dart';
import '../../screens/widgets/technical_dashboard.dart';
import '../../services/gatekeeper_service.dart';
import '../../services/supabase_service.dart';
import '../../training/digits_in_noise.dart';
import '../../training/progress_rules.dart';
import 'account_screen.dart';
import 'calibration_screen.dart';
import 'home/daily_goal_card.dart';
import 'home/training_progress_section.dart';
import 'home_widgets.dart';

/// Tela inicial: próximo passo, meta do dia, evolução por treino e os treinos (Etapa 10 do
/// plano; achados E2/E3 da auditoria de UX).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingData = true;
  bool _hasPro = false;
  Audiogram? _audiogram;
  List<RehabSession> _rehabHistory = [];

  static const _trainingOf = {
    2: TrainingId.phonemic,
    3: TrainingId.spatial,
    4: TrainingId.cocktail,
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingData = false);
      return;
    }
    try {
      final results = await Future.wait([
        SupabaseService().getPatientHistory(user.id),
        SupabaseService().loadGamificationData(),
        SupabaseService().getRehabHistory(user.id),
      ]);
      final audiograms = results[0] as List<Audiogram>;
      final gamData = results[1] as Map<String, dynamic>?;
      final history = results[2] as List<RehabSession>;
      final hasPro = await GatekeeperService().checkAccess(3).catchError((_) => false);
      if (!mounted) return;

      final controller = context.read<GamificationController>();
      if (gamData != null) controller.fromMap(gamData);
      // Progresso do dia sempre recalculado do histórico (a sequência antiga subia a cada
      // abertura da Home; achado E3).
      final now = DateTime.now();
      controller.setDailyProgress(
        minutesToday: ProgressRules.minutesOn(history, now),
        streakDays: ProgressRules.streakDays(history, now),
        goalDaysThisWeek: ProgressRules.goalDaysThisWeek(history, now),
      );

      setState(() {
        _audiogram = audiograms.isNotEmpty ? audiograms.first : null;
        _rehabHistory = history;
        _hasPro = hasPro;
        _isLoadingData = false;
      });
    } catch (e) {
      debugPrint("[HOME] Erro ao carregar dados: $e");
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _navigateToLevel(BuildContext context, int level) async {
    final audiogram = _audiogram;
    if (audiogram == null) {
      final doTest = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Primeiro, o teste de audição"),
          content: const Text(
            "O treino é ajustado ao seu jeito de ouvir. O teste leva uns 10 minutos; use fones de ouvido num lugar silencioso.",
            style: TextStyle(fontSize: 16, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Agora não")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Fazer o teste")),
          ],
        ),
      );
      if (doTest == true && context.mounted) await _runHearingTest();
      return;
    }

    final hasAccess = await GatekeeperService().checkAccess(level);
    if (!context.mounted) return;
    if (!hasAccess) {
      showProComingSoonSheet(context);
      return;
    }
    await _open(switch (level) {
      2 => PhonemicDiscriminationScreen(audiogram: audiogram),
      3 => SpatialAttentionScreen(audiogram: audiogram),
      _ => SpeechInNoiseScreen(audiogram: audiogram),
    });
  }

  /// Abre o teste de audição e salva o resultado (HearingTestFlow, Etapa 4).
  Future<void> _runHearingTest() async {
    final audiogram = await HearingTestFlow.runAndSave(context);
    if (audiogram != null && mounted) setState(() => _audiogram = audiogram);
  }

  /// Abre uma tela e recarrega os dados da Home ao voltar.
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _loadUserData();
  }

  TrainingId _recommended(GamificationController c) => ProgressRules.recommend(
        levels: {for (final t in TrainingId.values) t: c.levelOf(t)},
        hasPro: _hasPro,
      );

  /// Próximo passo: teste de audição (sem ou antigo), medida a cada 14 dias, ou o treino
  /// recomendado enquanto a meta do dia não foi cumprida.
  Widget? _buildNextStep(GamificationController controller) {
    final audiogram = _audiogram;
    if (audiogram == null) {
      return NextStepCard(
        title: 'Comece pelo teste de audição',
        body: 'Leva uns 10 minutos e ajusta o treino ao seu jeito de ouvir. '
            'Use fones de ouvido num lugar silencioso.',
        actionLabel: 'Fazer o teste agora',
        onPressed: _runHearingTest,
      );
    }
    if (audiogram.isOutdated) {
      return NextStepCard(
        title: 'Refaça o teste de audição',
        body: 'O teste foi melhorado e agora mede também os sons mais agudos. '
            'Seu resultado atual é da versão antiga e pode estar errado. Leva uns 10 minutos.',
        actionLabel: 'Refazer o teste agora',
        onPressed: _runHearingTest,
      );
    }
    if (DinProcedure.isDue(_rehabHistory)) {
      return NextStepCard(
        title: 'Hora de medir sua audição na fala',
        body: 'A cada 14 dias, um teste de uns 4 minutos mostra se você está entendendo melhor '
            'a fala no barulho.',
        actionLabel: 'Medir agora',
        onPressed: () => _open(DigitsInNoiseScreen(audiogram: audiogram)),
      );
    }
    if (!controller.dailyGoalMet) {
      final t = _recommended(controller);
      final left = ProgressRules.minutesLeftToday(controller.minutesToday);
      return NextStepCard(
        title: 'Treino de hoje: ${t.title}',
        body: 'Faltam $left min para a meta de hoje. Uma sessão leva uns 10 minutos.',
        actionLabel: 'Começar',
        onPressed: () => _navigateToLevel(context, _trainingOf.entries.firstWhere((e) => e.value == t).key),
      );
    }
    return null;
  }

  String? _progressLine(GamificationController c, TrainingId t) {
    final level = c.levelOf(t);
    return level == null ? null : 'Nível $level de ${t.maxLevel} · ${ProgressRules.stageName(level, t.maxLevel)}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GamificationController>();
    final nextStep = _isLoadingData ? null : _buildNextStep(controller);
    final recommended = _recommended(controller);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: _isLoadingData
            ? const Center(child: CircularProgressIndicator(color: HomeColors.accent))
            : ListView(
                // Rolável: em 360×640 ou com fonte grande nada fica cortado (achados E2/G3).
                padding: const EdgeInsets.all(24.0),
                children: [
                  _header(),
                  const SizedBox(height: 20),
                  if (nextStep != null) ...[nextStep, const SizedBox(height: 20)],
                  DailyGoalCard(
                    minutesToday: controller.minutesToday,
                    streakDays: controller.streakDays,
                    goalDaysThisWeek: controller.goalDaysThisWeek,
                    points: controller.trainingPoints,
                  ),
                  const SizedBox(height: 24),
                  const Text('Sua evolução',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TrainingProgressSection(history: _rehabHistory),
                  const SizedBox(height: 12),
                  for (final level in TrainingLevel.all) ...[
                    LevelCard(
                      level: level,
                      locked: level.level > 2 && !_hasPro,
                      recommended: _audiogram != null && _trainingOf[level.level] == recommended,
                      progressLine: _progressLine(controller, _trainingOf[level.level]!),
                      onTap: () => _navigateToLevel(context, level.level),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _linkButton(Icons.insights, 'Meu progresso', () => _open(const ProgressScreen())),
                  if (_audiogram != null && !_audiogram!.isOutdated)
                    _linkButton(Icons.hearing, 'Refazer teste de audição', _runHearingTest),
                ],
              ),
      ),
    );
  }

  Widget _header() => Row(children: [
        Expanded(
          child: GestureDetector(
            // Painel técnico (QA de áudio) por toque longo, como antes.
            onLongPress: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const TechnicalDashboard(),
            ),
            child: Semantics(
              header: true,
              child: const Text('BOSYN · Treino auditivo',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalibrationScreen())),
          icon: const Icon(Icons.tune, color: HomeColors.textSecondary),
          tooltip: "Calibrar tempo de resposta",
        ),
        IconButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())),
          icon: const Icon(Icons.account_circle_outlined, color: HomeColors.textSecondary),
          tooltip: "Conta e privacidade",
        ),
      ]);

  Widget _linkButton(IconData icon, String label, VoidCallback onPressed) => Center(
        child: TextButton.icon(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: HomeColors.textSecondary),
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label, style: const TextStyle(fontSize: 16)),
        ),
      );
}
