import 'package:supabase_flutter/supabase_flutter.dart';

/// GATEKEEPER SERVICE: Gestor de Acesso e Monetização [GATEKEEPER]
///
/// O app só LÊ o plano. Quem escreve `subscription_status` é o servidor (confirmação de
/// compra validada lá); o banco ignora alterações vindas do cliente
/// (supabase_migration_003_security.sql). Um "upgrade" feito pelo próprio app permitia a
/// qualquer usuário liberar o PRO sem pagar — removido.
class GatekeeperService {
  static final GatekeeperService _instance = GatekeeperService._internal();
  factory GatekeeperService() => _instance;
  GatekeeperService._internal();

  /// Verifica se o usuário tem permissão para acessar o nível solicitado
  Future<bool> checkAccess(int level) async {
    // Níveis 1 e 2 são gratuitos [REABILITAÇÃO BASE]
    if (level <= 2) return true;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    // Consulta Status de Assinatura no Perfil (sem perfil = plano gratuito)
    final res = await Supabase.instance.client
        .from('profiles')
        .select('subscription_status')
        .eq('user_id', user.id)
        .maybeSingle();

    final status = res?['subscription_status'] as String? ?? 'free';

    // Níveis 3 e 4 exigem status 'pro' ou 'elite'
    return status != 'free';
  }
}
