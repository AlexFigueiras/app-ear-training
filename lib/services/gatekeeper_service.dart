import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../monetization/pro_access.dart';

/// GATEKEEPER SERVICE: Gestor de Acesso e Monetização [GATEKEEPER]
///
/// O app só LÊ o plano. Quem escreve `subscription_status` e `subscription_expires_at` é o
/// servidor (compra conferida na Google pela Edge Function `play-subscription`); o banco ignora
/// alterações vindas do cliente (migrations 003 e 004). Um "upgrade" feito pelo próprio app
/// permitia a qualquer usuário liberar o PRO sem pagar — removido.
class GatekeeperService {
  static final GatekeeperService _instance = GatekeeperService._internal();
  factory GatekeeperService() => _instance;
  GatekeeperService._internal();

  /// Plano do usuário logado (sem login ou sem perfil = grátis).
  Future<ProAccess> loadAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return ProAccess.free;

    final profiles = Supabase.instance.client.from('profiles');
    try {
      final row = await profiles
          .select('subscription_status, subscription_expires_at')
          .eq('user_id', user.id)
          .maybeSingle();
      return ProAccess.fromProfile(row);
    } on PostgrestException catch (e) {
      // Coluna inexistente (42703 do Postgres ou PGRST204 do PostgREST): banco ainda sem a
      // migration 004. Lê só o plano.
      final missingColumn = e.code == '42703' ||
          e.code == 'PGRST204' ||
          e.message.contains('subscription_expires_at');
      if (!missingColumn) rethrow;
      debugPrint(
          '[GATEKEEPER] migration 004 pendente: lendo só subscription_status');
      final row = await profiles
          .select('subscription_status')
          .eq('user_id', user.id)
          .maybeSingle();
      return ProAccess.fromProfile(row);
    }
  }

  /// Verifica se o usuário tem permissão para acessar o nível solicitado
  Future<bool> checkAccess(int level) async {
    // Níveis 1 e 2 são gratuitos [REABILITAÇÃO BASE]
    if (level <= 2) return true;

    // Níveis 3 e 4 exigem o plano PRO válido (assinatura da Play ou PRO dado à mão)
    final access = await loadAccess();
    return access.isActiveAt(DateTime.now());
  }
}
