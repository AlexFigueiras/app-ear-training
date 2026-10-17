import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/gamification_controller.dart';
import 'event_buffer.dart';

/// Ciclo de vida da conta no aparelho [SEGURANÇA/LGPD]: sair e excluir a conta.
/// Nos dois casos, nada do usuário fica para trás no aparelho: telemetria pendente e estado em
/// memória são apagados antes de a sessão acabar.
class AccountService {
  static final AccountService _instance = AccountService._internal();
  factory AccountService() => _instance;
  AccountService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> signOut() async {
    final buffer = SessionEventBuffer();
    try {
      // Última chance de subir a telemetria do usuário antes de apagá-la do aparelho.
      await buffer.flush();
      await buffer.syncOfflineTelemetry();
    } catch (e) {
      debugPrint("Logout: telemetria pendente não sincronizada: $e");
    }
    await _clearLocalUserData();
    await _endLocalSession();
  }

  /// Exclui a conta e todos os dados dela (Google Play: exclusão dentro do app; LGPD art. 18).
  /// Exige a senha de novo antes (OWASP MASVS-AUTH-3): uma sessão esquecida aberta no aparelho
  /// não basta para apagar a conta de alguém. Quem apaga é a Edge Function `delete-account`
  /// (a chave privilegiada nunca vem para o app).
  Future<void> deleteAccount({required String password}) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) {
      throw const AuthException('Sessão expirada. Entre novamente.');
    }

    await _client.auth.signInWithPassword(email: email, password: password);
    await _client.functions.invoke('delete-account');

    await _clearLocalUserData();
    await _endLocalSession();
  }

  Future<void> _clearLocalUserData() async {
    await SessionEventBuffer().purgeLocalData();
    GamificationController().resetForNewUser();
  }

  /// O signOut remove a sessão local primeiro e só depois avisa o servidor; uma falha de rede
  /// nesse aviso não pode prender o usuário logado no aparelho.
  Future<void> _endLocalSession() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint(
          "Logout: sessão local encerrada; aviso ao servidor falhou: $e");
    }
  }
}
