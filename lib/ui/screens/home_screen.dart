import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/gamification_controller.dart';
import '../../models/audiogram.dart';
import '../../models/rehab_session.dart';
import '../../screens/digits_in_noise_screen.dart';
import '../../screens/phonemic_discrimination_screen.dart';
import '../../screens/progress_screen.dart';
import '../../training/digits_in_noise.dart';
import '../../screens/spatial_attention_screen.dart';
import '../../screens/speech_in_noise_screen.dart';
import '../../screens/hearing_test/hearing_test_flow.dart';
import '../../screens/widgets/technical_dashboard.dart';
import '../../services/gatekeeper_service.dart';
import '../../services/supabase_service.dart';
import 'account_screen.dart';
import 'calibration_screen.dart';
import 'home_widgets.dart';

/// HOME SCREEN: Dashboard Central de Progressão [ORQUESTRADOR]
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
      // Carrega audiograma, gamificação e histórico em paralelo
      final results = await Future.wait([
        SupabaseService().getPatientHistory(user.id),
        SupabaseService().loadGamificationData(),
        SupabaseService().getRehabHistory(user.id),
      ]);

      final audiograms = results[0] as List<Audiogram>;
      final hasPro =
          await GatekeeperService().checkAccess(3).catchError((_) => false);
      final gamData = results[1] as Map<String, dynamic>?;
      final history = results[2] as List<RehabSession>;

      if (!mounted) return;
      final controller = context.read<GamificationController>();

      // Restaura estado de gamificação persistido
      if (gamData != null) {
        controller.fromMap(gamData);
      }

      // Calcula streak real com base no histórico de sessões
      _calculateStreak(history, controller);

      // Conta sessões de hoje para exibir progresso diário
      final today = DateTime.now();
      final sessionsToday = history
          .where((s) =>
              s.date.year == today.year &&
              s.date.month == today.month &&
              s.date.day == today.day)
          .length;
      controller.setSessionsCompletedToday(sessionsToday);

      setState(() {
        _audiogram = audiograms.isNotEmpty ? audiograms.first : null;
        _rehabHistory = history;
        _hasPro = hasPro;
        _isLoadingData = false;
      });
    } catch (e) {
      debugPrint("[HOME] Erro ao carregar dados: $e");
      setState(() => _isLoadingData = false);
    }
  }

  void _calculateStreak(
      List<RehabSession> history, GamificationController controller) {
    if (history.isEmpty) {
      controller.updateStreak(0);
      return;
    }

    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final lastSessionDate = DateTime(
        history.last.date.year, history.last.date.month, history.last.date.day);
    final diff = today.difference(lastSessionDate).inDays;

    if (diff > 1) {
      // Mais de 1 dia sem treinar → reinicia streak
      controller.updateStreak(0);
    } else if (diff == 1) {
      // Treinou ontem → incrementa streak
      controller.updateStreak(controller.currentStreak + 1);
    }
    // diff == 0 → treinou hoje → mantém streak atual
  }

  Future<void> _navigateToLevel(BuildContext context, int level) async {
    // Se não tiver audiograma, conduz ao teste primeiro
    if (_audiogram == null) {
      final doTest = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          title: const Text("Primeiro, o teste de audição",
              style: TextStyle(color: Colors.white)),
          content: const Text(
            "O treino é ajustado ao seu jeito de ouvir. O teste leva uns 10 minutos; use fones de ouvido num lugar silencioso.",
            style: TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Agora não")),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Fazer o teste",
                  style: TextStyle(color: Color(0xFF00FF41))),
            ),
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

    Widget screen;
    switch (level) {
      case 2:
        screen = PhonemicDiscriminationScreen(audiogram: _audiogram!);
        break;
      case 3:
        screen = SpatialAttentionScreen(audiogram: _audiogram!);
        break;
      case 4:
      default:
        screen = SpeechInNoiseScreen(audiogram: _audiogram!);
        break;
    }

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    // Recarrega dados após retornar do treino
    if (mounted) _loadUserData();
  }

  /// Abre o teste de audição e salva o resultado (HearingTestFlow, Etapa 4 do plano). Usado
  /// pelo cartão de próximo passo, pelo aviso antes do primeiro treino e por "Refazer teste".
  Future<void> _runHearingTest() async {
    final audiogram = await HearingTestFlow.runAndSave(context);
    if (audiogram != null && mounted) setState(() => _audiogram = audiogram);
  }

  /// Abre uma tela e recarrega os dados da Home ao voltar.
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _loadUserData();
  }

  /// Cartão de próximo passo: sem audiograma, com audiograma do teste antigo, ou hora de medir
  /// a audição na fala (teste de dígitos, a cada 14 dias).

  Widget? _buildNextStep() {
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
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GamificationController>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: _isLoadingData
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00FF41)))
            : ListView(
                // Rolável: em 360×640 ou com fonte grande nada fica cortado (achados E2/G3).
                padding: const EdgeInsets.all(24.0),
                children: [
                  GestureDetector(
                    onLongPress: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const TechnicalDashboard(),
                      );
                    },
                    child: _buildMainHeader(controller),
                  ),
                  const SizedBox(height: 20),
                  if (_buildNextStep() case final nextStep?) ...[
                    nextStep,
                    const SizedBox(height: 20),
                  ],
                  _buildProgressCard(controller),
                  const SizedBox(height: 20),
                  _buildDailyProgress(controller),
                  const SizedBox(height: 16),
                  const Text(
                    "ACERTOS NAS ÚLTIMAS SESSÕES",
                    style: TextStyle(
                        color: Colors.white24, fontSize: 10, letterSpacing: 2),
                  ),
                  const SizedBox(height: 12),
                  if (_rehabHistory.isEmpty)
                    const EmptyProgressNote()
                  else
                    _buildEvolutionChart(),
                  const SizedBox(height: 24),
                  for (final level in TrainingLevel.all) ...[
                    LevelCard(
                      level: level,
                      locked: level.level > 2 && !_hasPro,
                      onTap: () => _navigateToLevel(context, level.level),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: HomeColors.textSecondary),
                      onPressed: () => _open(const ProgressScreen()),
                      icon: const Icon(Icons.insights),
                      label: const Text('Meu progresso',
                          style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  if (_audiogram != null && !_audiogram!.isOutdated)
                    Center(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            foregroundColor: HomeColors.textSecondary),
                        onPressed: _runHearingTest,
                        icon: const Icon(Icons.hearing),
                        label: const Text('Refazer teste de audição',
                            style: TextStyle(fontSize: 15)),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildMainHeader(GamificationController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("BOSYN — TREINO AUDITIVO",
                  style: TextStyle(
                      color: Colors.white38, letterSpacing: 5, fontSize: 10)),
              const SizedBox(height: 8),
              Text("STATUS: ${controller.acuityLevel}",
                  style: const TextStyle(
                      color: Color(0xFF00FF41),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace')),
              Container(
                  height: 2,
                  width: 120,
                  color: const Color(0xFF00FF41).withValues(alpha: 0.5)),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CalibrationScreen())),
              icon: const Icon(Icons.tune, color: Colors.white24),
              tooltip: "Calibrar Latência",
            ),
            IconButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AccountScreen())),
              icon: const Icon(Icons.account_circle_outlined,
                  color: Colors.white38),
              tooltip: "Conta e Privacidade",
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressCard(GamificationController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: Colors.white12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("XP ACUMULADO",
                  style: TextStyle(color: Colors.white38, fontSize: 8)),
              Text(controller.totalXP.toString().padLeft(6, '0'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontFamily: 'monospace')),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("STREAK",
                  style: TextStyle(color: Colors.white38, fontSize: 8)),
              Text(
                "${controller.currentStreak} dias",
                style: const TextStyle(
                    color: Color(0xFF00FF41),
                    fontSize: 16,
                    fontFamily: 'monospace'),
              ),
            ],
          ),
          const Icon(Icons.show_chart, color: Color(0xFF2563EB), size: 36),
        ],
      ),
    );
  }

  Widget _buildDailyProgress(GamificationController controller) {
    final sessions = controller.sessionsCompletedToday;
    final color =
        sessions >= 2 ? const Color(0xFF00FF41) : const Color(0xFF2563EB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "SESSÕES HOJE: $sessions / 2",
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold),
          ),
          if (controller.recommendRest)
            const Text("META DIÁRIA ATINGIDA ✓",
                style: TextStyle(
                    color: Color(0xFF00FF41), fontSize: 9, letterSpacing: 1)),
          if (!controller.recommendRest)
            Text(
              "${2 - sessions} sessão(ões) restante(s)",
              style: const TextStyle(color: Colors.white24, fontSize: 9),
            ),
        ],
      ),
    );
  }

  Widget _buildEvolutionChart() {
    final recent = _rehabHistory.length > 10
        ? _rehabHistory.sublist(_rehabHistory.length - 10)
        : _rehabHistory;
    final spots = <FlSpot>[];
    for (int i = 0; i < recent.length; i++) {
      spots.add(FlSpot(i.toDouble(), recent[i].accuracy.clamp(0.0, 100.0)));
    }
    if (spots.isEmpty) spots.add(const FlSpot(0, 0));

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: Colors.white12)),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(
              show: true, drawVerticalLine: false, horizontalInterval: 25),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 25,
                getTitlesWidget: (v, _) => Text("${v.toInt()}%",
                    style: const TextStyle(color: Colors.white24, fontSize: 8)),
              ),
            ),
            bottomTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (spots.length - 1).toDouble().clamp(1, double.infinity),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF00FF41),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF00FF41).withValues(alpha: 0.1)),
            ),
          ],
        ),
      ),
    );
  }
}
