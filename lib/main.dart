import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ear_training/core/gamification_controller.dart';
import 'package:ear_training/core/spatial_controller.dart';
import 'package:ear_training/ui/screens/home_screen.dart';
import 'package:ear_training/ui/screens/auth_screen.dart';
import 'package:ear_training/ui/screens/onboarding_screen.dart';
import 'package:ear_training/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:ear_training/services/event_buffer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialização de Variáveis de Ambiente e Persistência [SEGURANÇA/INFRA]
  try {
    await dotenv.load(fileName: ".env");
    await SupabaseService().initialize();
    
    // RIGOR CLÍNICO: Sincronização de Telemetria Offline e Escuta de Hardware
    final buffer = SessionEventBuffer();
    await buffer.init();
    await buffer.syncOfflineTelemetry();
  } catch (e) {
    debugPrint("Erro na inicialização: $e");
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GamificationController()),
        ChangeNotifierProvider(create: (_) => SpatialController()),
      ],
      child: const EarTrainingApp(),
    ),
  );
}

class EarTrainingApp extends StatelessWidget {
  const EarTrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return _buildMaterialApp(const AuthScreen());

      return FutureBuilder(
        future: Supabase.instance.client
            .from('profiles')
            .select('onboarding_completed')
            .eq('user_id', session.user.id)
            .maybeSingle(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildMaterialApp(const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF00FF41)))));
          }
          final isCompleted = snapshot.data?['onboarding_completed'] ?? false;
          return _buildMaterialApp(isCompleted ? const HomeScreen() : const OnboardingScreen());
        },
      );
    } catch (_) {
      return _buildMaterialApp(const AuthScreen());
    }
  }

  Widget _buildMaterialApp(Widget home) {
    return MaterialApp(
      title: 'BOSYN - Auditory Rehabilitation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        primaryColor: const Color(0xFF2563EB),
      ),
      home: home,
    );
  }
}
