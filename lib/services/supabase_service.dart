import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_config.dart';
import '../models/audiogram.dart';
import '../models/rehab_session.dart';

/// Serviço Responsável pela Persistência e Segurança [SEGURANÇA/INFRA]
/// Aplica as regras de integridade e comunicação com o Supabase.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Valores validados no boot por AppConfig.validate() (main.dart) antes de chegar aqui.
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );

    _isInitialized = true;
    debugPrint("Supabase Iniciado com SUCESSO.");
  }

  /// Garante a linha do usuário em `profiles` e diz se o onboarding já foi concluído.
  /// No cadastro, quem cria o perfil é o trigger do banco (supabase_migration_003_security.sql);
  /// o insert aqui cobre contas criadas antes dele. `subscription_status` é forçado a 'free'
  /// pelo banco para o cliente — o app não decide o próprio plano.
  Future<bool> loadOnboardingCompleted() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('onboarding_completed')
        .eq('user_id', user.id)
        .maybeSingle();

    if (profile == null) {
      await Supabase.instance.client.from('profiles').insert({
        'user_id': user.id,
        'subscription_status': 'free',
        'created_at': DateTime.now().toIso8601String(),
      });
      return false;
    }
    return profile['onboarding_completed'] == true;
  }

  /// Salva um novo Audiograma [SEGURANÇA]
  /// Note: A política RLS deve estar ativa no banco para garantir isolation por user_id.
  Future<void> saveAudiogram(Audiogram audiogram) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception("Usuário não autenticado.");

    // Mapeamento para o Schema do PostgreSQL
    await Supabase.instance.client.from('audiograms').insert({
      'patient_id': audiogram.patientId,
      'left_ear': audiogram.leftEar.map((e) => e.toJson()).toList(),
      'right_ear': audiogram.rightEar.map((e) => e.toJson()).toList(),
      'user_id': user.id, // Vínculo explícito para RLS
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Recupera o histórico de audiogramas do paciente logado
  Future<List<Audiogram>> getPatientHistory(String patientId) async {
    final List<dynamic> response = await Supabase.instance.client
        .from('audiograms')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);

    return response.map((data) => Audiogram.fromJson(data)).toList();
  }

  /// Salva uma sessão de reabilitação [SSOT/SEGURANÇA]
  Future<void> saveRehabSession(RehabSession session) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception("Usuário não autenticado.");

    await Supabase.instance.client.from('rehab_sessions').insert({
      ...session.toJson(),
      'user_id': user.id, // Vínculo obrigatório para RLS
    });
  }

  /// Batch upload para respostas granulares clinicamente marcadas [TELEMETRIA]
  Future<void> saveStimulusResultsBatch(List<Map<String, dynamic>> payload) async {
    if (payload.isEmpty) return;
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception("Usuário não autenticado.");

    // Inject user_id em todos os itens garantindo compliance RLS
    final authorizedPayload = payload.map((e) => {
      ...e,
      'user_id': user.id,
    }).toList();

    await Supabase.instance.client.from('stimulus_results').insert(authorizedPayload);
  }

  /// Recupera o histórico de sessões de reabilitação [TELEMETRIA]
  Future<List<RehabSession>> getRehabHistory(String patientId) async {
    final List<dynamic> response = await Supabase.instance.client
        .from('rehab_sessions')
        .select()
        .eq('patient_id', patientId)
        .order('date', ascending: true);

    return response.map((data) => RehabSession.fromJson(data)).toList();
  }

  /// Salva o estado de gamificação no perfil do usuário
  Future<void> saveGamificationData(Map<String, dynamic> data) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client
        .from('profiles')
        .update({'gamification_data': data})
        .eq('user_id', user.id);
  }

  /// Carrega o estado de gamificação do perfil do usuário
  Future<Map<String, dynamic>?> loadGamificationData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final res = await Supabase.instance.client
        .from('profiles')
        .select('gamification_data')
        .eq('user_id', user.id)
        .maybeSingle();
    if (res == null) return null;
    final data = res['gamification_data'];
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  /// Recupera a evolução da latência média das últimas 5 sessões [SENIOR-FULLSTACK]
  Future<List<Map<String, dynamic>>> getLatencyEvolution() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    // Query otimizada: Agrega média de reaction_time da stimulus_results
    // limitando às últimas 5 sessões para o gráfico de tendências.
    final List<dynamic> response = await Supabase.instance.client
        .from('stimulus_results')
        .select('session_id, reaction_time_ms, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(100); // Pegamos uma amostra grande para processar no app

    if (response.isEmpty) return [];

    // Agrupamento manual por session_id (Otimizado: preserva ordem temporal)
    final Map<String, List<double>> sessionGroups = {};
    for (var row in response) {
      final id = row['session_id'] as String;
      final rt = (row['reaction_time_ms'] as num).toDouble();
      sessionGroups.putIfAbsent(id, () => []).add(rt);
    }

    final List<Map<String, dynamic>> results = [];
    sessionGroups.forEach((id, times) {
      final avg = times.reduce((a, b) => a + b) / times.length;
      results.add({'session_id': id, 'avg_latency': avg});
    });

    return results.reversed.take(5).toList(); // Últimas 5 sessões em ordem cronológica
  }
}
