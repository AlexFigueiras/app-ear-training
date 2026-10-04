import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

/// Raiz autenticada do app [ORQUESTRADOR]: login → onboarding → home.
/// Reage a login, logout e exclusão de conta sem navegação manual. Só reconsulta o perfil
/// quando o usuário muda — refresh de token não recria a Home.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final StreamSubscription<AuthState> _authSub;
  String? _userId;
  Future<bool>? _onboardingCompleted;

  @override
  void initState() {
    super.initState();
    _applyUser(Supabase.instance.client.auth.currentUser?.id);
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      final userId = state.session?.user.id;
      if (userId != _userId) setState(() => _applyUser(userId));
    });
  }

  void _applyUser(String? userId) {
    _userId = userId;
    _onboardingCompleted =
        userId == null ? null : SupabaseService().loadOnboardingCompleted();
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return const AuthScreen();

    return FutureBuilder<bool>(
      future: _onboardingCompleted,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: Color(0xFF00FF41))),
          );
        }
        // Erro de rede: a Home trata o próprio carregamento; não forçar o onboarding de novo.
        if (snapshot.hasError || snapshot.data == true) {
          return const HomeScreen();
        }
        return OnboardingScreen(
          onCompleted: () =>
              setState(() => _onboardingCompleted = Future.value(true)),
        );
      },
    );
  }
}
