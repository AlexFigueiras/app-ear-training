import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Síntese de fala (Google Cloud TTS) via Edge Function `tts` do Supabase.
///
/// A chave do Google fica só no servidor, como secret da função (`supabase/functions/tts`):
/// dentro do app ela seria extraível do APK por qualquer pessoa. A função só atende usuário
/// autenticado — o JWT da sessão vai automaticamente no `functions.invoke`.
class GoogleTTSService {
  static const String _functionName = 'tts';

  /// Synthesizes text to speech and returns the local file path.
  /// Uses a cache to avoid redundant API calls.
  Future<String> synthesize(
    String text, {
    String languageCode = 'pt-BR',
    String voiceName = 'pt-BR-Wavenet-A', // Wavenet para alta qualidade clínica
    double speakingRate = 1.0,
    double pitch = 0.0,
  }) async {
    final String cacheKey =
        _generateCacheKey(text, languageCode, voiceName, speakingRate, pitch);
    final File cacheFile = await _getCacheFile(cacheKey);

    if (await cacheFile.exists()) {
      debugPrint('DEBUG: TTS Cache Hit para "$text"');
      return cacheFile.path;
    }

    debugPrint('DEBUG: TTS via Edge Function para "$text"');

    // Erro HTTP da função vira FunctionException (propaga como antes: synthesize lança).
    final response = await Supabase.instance.client.functions.invoke(
      _functionName,
      body: {
        'text': text,
        'languageCode': languageCode,
        'voiceName': voiceName,
        'speakingRate': speakingRate,
        'pitch': pitch,
      },
    );

    final audioBytes = response.data;
    if (audioBytes is! Uint8List || audioBytes.isEmpty) {
      throw Exception(
          'Falha ao sintetizar áudio: resposta inesperada (HTTP ${response.status}).');
    }

    await cacheFile.writeAsBytes(audioBytes, flush: true);
    return cacheFile.path;
  }

  String _generateCacheKey(
      String text, String lang, String voice, double rate, double pitch) {
    final String input = '$text|$lang|$voice|$rate|$pitch';
    return md5.convert(utf8.encode(input)).toString();
  }

  Future<File> _getCacheFile(String key) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String path = '${tempDir.path}/tts_cache_$key.wav';
    return File(path);
  }
}
