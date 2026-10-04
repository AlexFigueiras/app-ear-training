import 'package:flutter/material.dart';

/// Tela de falha na partida [FAIL-FAST]: configuração inválida ou servidor indisponível.
/// Mostra o problema de forma explícita em vez de o app quebrar adiante sem contexto.
class StartupErrorApp extends StatelessWidget {
  final List<String> problems;

  const StartupErrorApp({super.key, required this.problems});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BOSYN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFE11D48), size: 48),
                const SizedBox(height: 24),
                const Text(
                  'NÃO FOI POSSÍVEL INICIAR O BOSYN',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                for (final problem in problems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('• $problem',
                        style: const TextStyle(color: Colors.white70)),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Verifique sua conexão e tente novamente. Se o problema continuar, '
                  'atualize o app pela Google Play.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
