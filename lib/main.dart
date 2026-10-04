import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ear_training/core/app_config.dart';
import 'package:ear_training/core/gamification_controller.dart';
import 'package:ear_training/ui/screens/session_gate.dart';
import 'package:ear_training/ui/screens/startup_error_screen.dart';
import 'package:ear_training/services/supabase_service.dart';

import 'package:ear_training/services/event_buffer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Release não escreve no logcat: logs de treino carregam dado clínico (OWASP MASVS-STORAGE-2).
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Fail-fast [SEGURANÇA/INFRA]: build sem configuração válida para numa tela explícita.
  final configProblems = AppConfig.validate();
  if (configProblems.isNotEmpty) {
    runApp(StartupErrorApp(problems: configProblems));
    return;
  }

  try {
    await SupabaseService().initialize();
  } catch (e) {
    debugPrint("Erro na inicialização do Supabase: $e");
    runApp(const StartupErrorApp(
        problems: ['Falha ao iniciar a conexão com o servidor.']));
    return;
  }

  // RIGOR CLÍNICO: Sincronização de Telemetria Offline e Escuta de Hardware.
  // Falha aqui não impede o uso do app; o sync roda em segundo plano para não atrasar a abertura.
  try {
    final buffer = SessionEventBuffer();
    await buffer.init();
    unawaited(buffer.syncOfflineTelemetry());
  } catch (e) {
    debugPrint("Erro na inicialização da telemetria: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GamificationController()),
      ],
      child: const EarTrainingApp(),
    ),
  );
}

class EarTrainingApp extends StatelessWidget {
  const EarTrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BOSYN — Treino auditivo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        primaryColor: const Color(0xFF2563EB),
      ),
      home: const SessionGate(),
    );
  }
}
