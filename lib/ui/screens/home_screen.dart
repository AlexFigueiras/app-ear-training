import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/gamification_controller.dart';
import '../../models/audiogram.dart';
import '../../models/rehab_session.dart';
import '../../screens/phonemic_discrimination_screen.dart';
import '../../screens/spatial_attention_screen.dart';
import '../../screens/speech_in_noise_screen.dart';
import '../../screens/threshold_test_screen.dart';
import '../../screens/widgets/technical_dashboard.dart';
import '../../services/gatekeeper_service.dart';
import '../../services/supabase_service.dart';
import 'account_screen.dart';
import 'calibration_screen.dart';

/// HOME SCREEN: Dashboard Central de Progressão [ORQUESTRADOR]
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingData = true;

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
      final sessionsToday = history.where((s) =>
        s.date.year == today.year &&
        s.date.month == today.month &&
        s.date.day == today.day
      ).length;
      controller.setSessionsCompletedToday(sessionsToday);

      setState(() {
        _audiogram = audiograms.isNotEmpty ? audiograms.first : null;
        _rehabHistory = history;
        _isLoadingData = false;
      });
    } catch (e) {
      debugPrint("[HOME] Erro ao carregar dados: $e");
      setState(() => _isLoadingData = false);
    }
  }

  void _calculateStreak(List<RehabSession> history, GamificationController controller) {
    if (history.isEmpty) {
      controller.updateStreak(0);
      return;
    }

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final lastSessionDate = DateTime(history.last.date.year, history.last.date.month, history.last.date.day);
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
          title: const Text("Teste Auditivo Necessário", style: TextStyle(color: Colors.white)),
          content: const Text(
            "Para personalizar seu treino, realize o teste auditivo primeiro.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Fazer Teste", style: TextStyle(color: Color(0xFF00FF41))),
            ),
          ],
        ),
      );

      if (doTest == true && context.mounted) {
        final result = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(builder: (_) => const ThresholdTestScreen()),
        );
        if (result != null && context.mounted) {
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
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
            setState(() => _audiogram = audiogram);
          }
        }
      }
      return;
    }

    final hasAccess = await GatekeeperService().checkAccess(level);
    if (!context.mounted) return;

    if (!hasAccess) {
      _showPaywall(context);
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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GamificationController>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: _isLoadingData
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF41)))
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    _buildProgressCard(controller),
                    const SizedBox(height: 20),
                    _buildDailyProgress(controller),
                    const SizedBox(height: 16),
                    const Text(
                      "EVOLUÇÃO DA ACUIDADE (ÚLTIMAS SESSÕES)",
                      style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2),
                    ),
                    const SizedBox(height: 12),
                    _buildEvolutionChart(),
                    const Spacer(),
                    _buildStartButton(context),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMainHeader(GamificationController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("BOSYN — REABILITAÇÃO NEURAL", style: TextStyle(color: Colors.white38, letterSpacing: 5, fontSize: 10)),
            const SizedBox(height: 8),
            Text("STATUS: ${controller.acuityLevel}", style: const TextStyle(color: Color(0xFF00FF41), fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
            Container(height: 2, width: 120, color: const Color(0xFF00FF41).withValues(alpha: 0.5)),
          ],
        ),
        Row(
          children: [
            if (_audiogram == null)
              IconButton(
                onPressed: () async {
                  final user = Supabase.instance.client.auth.currentUser;
                  final result = await Navigator.of(context).push<Map<String, dynamic>>(
                    MaterialPageRoute(builder: (_) => const ThresholdTestScreen()),
                  );
                  if (result != null && user != null && mounted) {
                    final leftEar = List<AudiometryPoint>.from(result['left'] as List);
                    final rightEar = List<AudiometryPoint>.from(result['right'] as List);
                    final audiogram = Audiogram(id: '', patientId: user.id, date: DateTime.now(), leftEar: leftEar, rightEar: rightEar);
                    await SupabaseService().saveAudiogram(audiogram);
                    setState(() => _audiogram = audiogram);
                  }
                },
                icon: const Icon(Icons.hearing, color: Color(0xFFFFBF00)),
                tooltip: "Realizar Teste Auditivo",
              ),
            IconButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalibrationScreen())),
              icon: const Icon(Icons.tune, color: Colors.white24),
              tooltip: "Calibrar Latência",
            ),
            IconButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())),
              icon: const Icon(Icons.account_circle_outlined, color: Colors.white38),
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
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), border: Border.all(color: Colors.white12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("XP ACUMULADO", style: TextStyle(color: Colors.white38, fontSize: 8)),
              Text(controller.totalXP.toString().padLeft(6, '0'), style: const TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'monospace')),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("STREAK", style: TextStyle(color: Colors.white38, fontSize: 8)),
              Text(
                "${controller.currentStreak} dias",
                style: const TextStyle(color: Color(0xFF00FF41), fontSize: 16, fontFamily: 'monospace'),
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
    final color = sessions >= 2 ? const Color(0xFF00FF41) : const Color(0xFF2563EB);
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
            style: TextStyle(color: color, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
          ),
          if (controller.recommendRest)
            const Text("META DIÁRIA ATINGIDA ✓", style: TextStyle(color: Color(0xFF00FF41), fontSize: 9, letterSpacing: 1)),
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
    final recent = _rehabHistory.length > 10 ? _rehabHistory.sublist(_rehabHistory.length - 10) : _rehabHistory;
    final spots = <FlSpot>[];
    for (int i = 0; i < recent.length; i++) {
      spots.add(FlSpot(i.toDouble(), recent[i].accuracy.clamp(0.0, 100.0)));
    }
    if (spots.isEmpty) spots.add(const FlSpot(0, 0));

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), border: Border.all(color: Colors.white12)),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 25),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 25,
                getTitlesWidget: (v, _) => Text("${v.toInt()}%", style: const TextStyle(color: Colors.white24, fontSize: 8)),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              belowBarData: BarAreaData(show: true, color: const Color(0xFF00FF41).withValues(alpha: 0.1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return Column(
      children: [
        _buildLevelCard(context, 2, "CALIBRAÇÃO FONÊMICA", "ACESSO LIBERADO"),
        const SizedBox(height: 12),
        _buildLevelCard(context, 3, "ESCALONAMENTO ESPACIAL", "REQUER PRO", isLocked: true),
        const SizedBox(height: 12),
        _buildLevelCard(context, 4, "AMBIENTE HOSTIL [COQUETEL]", "REQUER PRO", isLocked: true),
      ],
    );
  }

  Widget _buildLevelCard(BuildContext context, int level, String title, String subtitle, {bool isLocked = false}) {
    return InkWell(
      onTap: () => _navigateToLevel(context, level),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          border: Border.all(color: isLocked ? Colors.white10 : const Color(0xFF2563EB).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isLocked ? Colors.white38 : Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                Text(subtitle, style: TextStyle(color: isLocked ? const Color(0xFFE11D48) : const Color(0xFF00FF41), fontSize: 8)),
              ],
            ),
            Icon(isLocked ? Icons.lock_outline : Icons.play_arrow, color: isLocked ? Colors.white10 : const Color(0xFF00FF41), size: 20),
          ],
        ),
      ),
    );
  }

  // Sem compra dentro do app por enquanto: venda de recurso digital na Play exige Google Play
  // Billing com validação no servidor (ver docs/PLAY_STORE.md). Antes, este botão simulava um
  // checkout e liberava o PRO sem cobrança — removido junto com o upgrade feito pelo cliente.
  void _showPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const BeveledRectangleBorder(),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("BOSYN PRO — EM BREVE", style: TextStyle(color: Color(0xFF00FF41), fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              const SizedBox(height: 12),
              const Text(
                "Os treinos de Escalonamento Espacial e Efeito Coquetel fazem parte do plano PRO, que ainda não está à venda. Avisaremos no app quando estiver disponível.",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, shape: const BeveledRectangleBorder()),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("ENTENDI", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
