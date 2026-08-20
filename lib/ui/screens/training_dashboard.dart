import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/gamification_controller.dart';
import '../../core/phoneme_map.dart';
import '../../core/spatial_controller.dart';
import '../../services/audio_service_manager.dart';
import '../widgets/industrial_button.dart';
import '../widgets/neural_energy_bar.dart';
import '../widgets/snr_meter.dart';
import '../widgets/sonar_display.dart';
import 'mission_report_screen.dart';

/// TRAINING DASHBOARD: Cockpit Industrial de Elite [ORQUESTRADOR]
class TrainingDashboard extends StatefulWidget {
  const TrainingDashboard({super.key});

  @override
  State<TrainingDashboard> createState() => _TrainingDashboardState();
}

class _TrainingDashboardState extends State<TrainingDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  int _currentLevel = 2;
  bool _isTrainingActive = false;

  // Estado do Exercício
  Map<String, dynamic>? _currentStimulus;
  double _extraBoost = 0.0;
  double _targetPanning = 0.0;
  bool _isCorrectPulse = false;
  int _sessionXP = 0; // Tracking local da sessão
  final List<bool> _level4History = []; // Rastreador de regressão [INTELIGÊNCIA]

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _radarController.dispose();
    AudioServiceManager().forceStopAll();
    super.dispose();
  }

  void _finishSession() {
    final gamification = context.read<GamificationController>();
    debugPrint("SESSÃO SINCRONIZADA: XP=$_sessionXP | SNR=${gamification.currentSNR}");

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MissionReportScreen(
          sessionXP: _sessionXP,
          noiseThreshold: gamification.maxNoiseThreshold,
        ),
      ),
    );
  }

  void _startExercise() {
    if (context.read<GamificationController>().neuralEnergy <= 0) {
      _finishSession();
      return;
    }
    if (_currentLevel == 2) {
      _startLevel2();
    } else if (_currentLevel == 3) {
      _startLevel3();
    } else {
      _startLevel4();
    }
  }

  void _startLevel2() {
    final controller = context.read<GamificationController>();
    final phoneme = controller.getSmartPhoneme([]);

    setState(() {
      _currentStimulus = phoneme;
      _isTrainingActive = true;
      _extraBoost = 0.0;
      _targetPanning = 0.0;
    });
    _playLevel2Stimulus();
  }

  void _startLevel3() {
    final stimuli = PHONEME_REHAB_DATA['level_2'] as List;
    setState(() {
      _currentStimulus = stimuli[math.Random().nextInt(stimuli.length)];
      const options = [-1.0, 0.0, 1.0];
      _targetPanning = options[math.Random().nextInt(3)];
      _isTrainingActive = true;
    });
    _playLevel3Stimulus();
  }

  void _startLevel4() {
    final controller = context.read<GamificationController>();
    const environments = ['RESTAURANTE', 'TRÂNSITO', 'VENTO'];

    setState(() {
      _currentStimulus = controller.getSmartPhoneme([]);
      _isTrainingActive = true;
    });

    AudioServiceManager().engine.playCocktailStimulus(
      text: _currentStimulus!['target'],
      snrDb: controller.currentSNR,
      noiseEnvironment: environments[math.Random().nextInt(3)],
      freqBand: (_currentStimulus!['freq_band'] as num).toDouble(),
    );
  }

  void _handleN2Choice(String choice) {
    if (_currentStimulus == null) return;
    final controller = context.read<GamificationController>();
    bool isCorrect = choice == _currentStimulus!['target'];

    if (isCorrect) {
      setState(() {
        _isCorrectPulse = true;
        _sessionXP += 25;
        controller.addAcuityXP(1.0, [_currentStimulus!['target'][0].toLowerCase()]);
        _radarController.forward(from: 0).then((_) => _isCorrectPulse = false);
      });
      Future.delayed(const Duration(seconds: 2), _startLevel2);
    } else {
      controller.consumeEnergy();
      if (controller.neuralEnergy <= 0) _finishSession();
      setState(() => _extraBoost += 3.0);
      _playLevel2Stimulus();
    }
  }

  void _handleN3Choice(double pannedAngle) {
    final spatialController = context.read<SpatialController>();
    final gamification = context.read<GamificationController>();

    spatialController.processSpatialResponse(
      targetPanning: _targetPanning,
      selectedPanning: pannedAngle,
      phoneme: _currentStimulus?['target'] ?? "N/A",
    );

    if (spatialController.lastAngularError < 0.1) {
      gamification.addAcuityXP(1.5, ['spatial']);
      Future.delayed(const Duration(seconds: 2), _startLevel3);
    } else {
      gamification.consumeEnergy();
      Future.delayed(const Duration(seconds: 1), _playLevel3Stimulus);
    }
  }

  void _handleN4Choice(String choice) {
    if (_currentStimulus == null) return;
    final gamification = context.read<GamificationController>();
    bool isCorrect = choice == _currentStimulus!['target'];

    _level4History.add(isCorrect);
    if (_level4History.length > 5) _level4History.removeAt(0);

    if (_level4History.length == 5) {
      int successCount = _level4History.where((val) => val).length;
      if (successCount < 3) {
        debugPrint("REGRESSÃO CLÍNICA DETECTADA (<50%). RECALIBRANDO NO NÍVEL 2.");
        setState(() {
          _currentLevel = 2;
          _level4History.clear();
        });
        _startLevel2();
        return;
      }
    }

    gamification.addAcuityXP(isCorrect ? 1.0 : 0.0, ['cocktail']);

    if (isCorrect) {
      setState(() {
        _isCorrectPulse = true;
        _sessionXP += 50;
      });
      _radarController.forward(from: 0).then((_) => _isCorrectPulse = false);
      Future.delayed(const Duration(seconds: 2), _startLevel4);
    } else {
      gamification.consumeEnergy();
      if (gamification.neuralEnergy <= 0) _finishSession();
      Future.delayed(const Duration(seconds: 1), _startLevel4);
    }
  }

  Future<void> _playLevel2Stimulus() async {
    if (_currentStimulus == null) return;
    await AudioServiceManager().engine.playPhonemicStimulus(
      text: _currentStimulus!['target'],
      freqBand: (_currentStimulus!['freq_band'] as num).toDouble(),
      extraBoostDb: _extraBoost,
    );
  }

  Future<void> _playLevel3Stimulus() async {
    if (_currentStimulus == null) return;
    await AudioServiceManager().engine.playSpatialStimulus(
      text: _currentStimulus!['target'],
      panning: _targetPanning,
      freqBand: (_currentStimulus!['freq_band'] as num).toDouble(),
    );
    _radarController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 15),
              _buildLevelSelector(),
              const SizedBox(height: 15),
              const NeuralEnergyBar(),
              const SizedBox(height: 20),
              if (_currentLevel == 4) const SNRMeter(),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: _isTrainingActive
                      ? (_currentLevel == 2
                          ? _buildLevel2UI()
                          : (_currentLevel == 3 ? _buildLevel3UI() : _buildLevel4UI()))
                      : _buildStandbyPanel(),
                ),
              ),
              const SizedBox(height: 20),
              _buildControlPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _levelTab(2, "CALIBRAR"),
          const SizedBox(width: 8),
          _levelTab(3, "ESPAÇO"),
          const SizedBox(width: 8),
          _levelTab(4, "COQUETEL"),
        ],
      ),
    );
  }

  Widget _levelTab(int level, String label) {
    bool isSelected = _currentLevel == level;
    return InkWell(
      onTap: () => setState(() {
        _currentLevel = level;
        _isTrainingActive = false;
        AudioServiceManager().forceStopAll();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? const Color(0xFF00FF41) : Colors.white12),
          color: isSelected ? const Color(0xFF00FF41).withOpacity(0.05) : Colors.transparent,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF00FF41) : Colors.white38,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevel2UI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SonarDisplay(
          animationController: _radarController,
          freqBand: _currentStimulus?['freq_band'] ?? 0,
          isPulse: _isCorrectPulse,
        ),
        const SizedBox(height: 40),
        Row(
          children: [
            IndustrialButton(
              label: _currentStimulus!['target'],
              onTap: () => _handleN2Choice(_currentStimulus!['target']),
            ),
            const SizedBox(width: 15),
            IndustrialButton(
              label: _currentStimulus!['distractor'],
              onTap: () => _handleN2Choice(_currentStimulus!['distractor']),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLevel3UI() {
    return Consumer<SpatialController>(
      builder: (context, spatial, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SonarDisplay(
              animationController: _radarController,
              freqBand: _currentStimulus?['freq_band'] ?? 0,
              isPulse: true,
              angle: _targetPanning,
            ),
            const SizedBox(height: 20),
            Text(
              spatial.statusMessage,
              style: const TextStyle(color: Color(0xFF00FF41), fontFamily: 'monospace', fontSize: 10),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                IndustrialButton(label: "90° L", onTap: () => _handleN3Choice(-1.0)),
                const SizedBox(width: 10),
                IndustrialButton(label: "00° C", onTap: () => _handleN3Choice(0.0)),
                const SizedBox(width: 10),
                IndustrialButton(label: "90° R", onTap: () => _handleN3Choice(1.0)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLevel4UI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SonarDisplay(
          animationController: _radarController,
          freqBand: _currentStimulus?['freq_band'] ?? 0,
          isPulse: _isCorrectPulse,
        ),
        const SizedBox(height: 40),
        Row(
          children: [
            IndustrialButton(
              label: _currentStimulus!['target'],
              onTap: () => _handleN4Choice(_currentStimulus!['target']),
            ),
            const SizedBox(width: 15),
            IndustrialButton(
              label: _currentStimulus!['distractor'],
              onTap: () => _handleN4Choice(_currentStimulus!['distractor']),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildPanicButton(),
      ],
    );
  }

  Widget _buildPanicButton() {
    return TextButton(
      onPressed: () {
        context.read<GamificationController>().resetSNR();
        AudioServiceManager().forceStopAll();
        _startLevel4();
      },
      child: const Text(
        "RECALIBRAR AMBIENTE [RESET SNR]",
        style: TextStyle(
          color: Color(0xFFFFBF00),
          fontSize: 10,
          fontFamily: 'monospace',
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<GamificationController>(
      builder: (context, controller, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("SYSTEM TELEMETRY", style: TextStyle(color: Colors.white38, fontSize: 10)),
                Text(controller.acuityLevel, style: const TextStyle(color: Color(0xFF00FF41), fontSize: 20, fontFamily: 'monospace')),
              ],
            ),
            _buildStatCard("XP", controller.totalXP.toString()),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), border: Border.all(color: const Color(0xFF333333))),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8)),
          Text(value, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildStandbyPanel() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.radar, color: Colors.white10, size: 80),
        SizedBox(height: 20),
        Text("RADAR EM STANDBY", style: TextStyle(color: Colors.white24, fontFamily: 'monospace', letterSpacing: 5)),
      ],
    );
  }

  Widget _buildControlPanel() {
    final gamification = context.watch<GamificationController>();
    final canStart = gamification.hasEnergy;
    final restRemaining = gamification.remainingRestTime;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!canStart)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              "FADIGA NEURAL DETECTADA. REPOUSO: ${restRemaining.inHours}h ${restRemaining.inMinutes % 60}m",
              style: const TextStyle(color: Color(0xFFE11D48), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isTrainingActive
                  ? const Color(0xFFE11D48)
                  : (canStart ? const Color(0xFF2563EB) : Colors.white10),
              shape: const BeveledRectangleBorder(),
            ),
            onPressed: (!canStart && !_isTrainingActive)
                ? null
                : () => _isTrainingActive ? setState(() => _isTrainingActive = false) : _startExercise(),
            child: Text(_isTrainingActive ? "ABORTAR" : "INICIAR PROTOCOLO N$_currentLevel"),
          ),
        ),
      ],
    );
  }
}
