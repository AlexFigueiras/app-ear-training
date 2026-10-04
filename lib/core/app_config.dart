import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Configuração de build, injetada em tempo de compilação com
/// `--dart-define-from-file=.env` (ver `.env.example` e `docs/PLAY_STORE.md`).
///
/// Tudo aqui fica dentro do binário e é extraível do APK: só entram valores públicos por
/// natureza (URL do projeto e chave publishable, protegidas por RLS). Segredos ficam em Edge
/// Functions do Supabase (`supabase/functions/`) — AGENTS.md seção 7.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Chave publishable (`sb_publishable_…`). As chaves legadas `anon` serão desligadas pelo
  /// Supabase no fim de 2026; `SUPABASE_ANON_KEY` segue aceito só como nome antigo da variável.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  /// Problemas de configuração encontrados; lista vazia = configuração válida.
  /// O app recusa iniciar com qualquer problema (fail-fast, AGENTS.md seção 7).
  static List<String> validate({
    String url = supabaseUrl,
    String publishableKey = supabasePublishableKey,
    bool allowInsecureHttp = kDebugMode,
  }) {
    final problems = <String>[];

    final uri = Uri.tryParse(url);
    if (url.isEmpty) {
      problems.add('SUPABASE_URL não definida.');
    } else if (uri == null ||
        !uri.hasAuthority ||
        !(uri.isScheme('https') ||
            (allowInsecureHttp && uri.isScheme('http')))) {
      problems.add(
          'SUPABASE_URL inválida (esperado https://<projeto>.supabase.co).');
    }

    if (publishableKey.isEmpty) {
      problems.add('SUPABASE_PUBLISHABLE_KEY não definida.');
    } else if (!isPublicClientKey(publishableKey)) {
      problems.add(
          'SUPABASE_PUBLISHABLE_KEY não é uma chave pública (publishable/anon). '
          'Chaves privilegiadas nunca podem ir para o app.');
    }

    return problems;
  }

  /// Aceita só chaves feitas para cliente: `sb_publishable_…` ou JWT legado com role `anon`.
  /// Qualquer outra coisa (chave secreta, JWT com outro role) é recusada.
  static bool isPublicClientKey(String key) {
    if (key.startsWith('sb_publishable_')) return true;

    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final claims = jsonDecode(payload);
      return claims is Map && claims['role'] == 'anon';
    } on FormatException {
      return false;
    }
  }
}
