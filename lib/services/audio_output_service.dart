import 'package:flutter/services.dart';

/// Volume de mídia do Android (passos inteiros, ex.: 10 de 15).
class MediaVolume {
  final int current;
  final int max;

  const MediaVolume(this.current, this.max);

  @override
  bool operator ==(Object other) => other is MediaVolume && other.current == current && other.max == max;

  @override
  int get hashCode => Object.hash(current, max);
}

enum OutputRoute { wired, bluetooth, speaker, unknown }

/// Saída de áudio do aparelho, via canal nativo `bosyn/audio_output` (MainActivity.kt).
///
/// O teste auditivo precisa de fone e de volume fixo do começo ao fim: um nível relativo só
/// vale se o volume não mudar entre as frequências. Fora do Android (e nos testes) devolve
/// null/[OutputRoute.unknown] em vez de falhar.
class AudioOutputService {
  static const _channel = MethodChannel('bosyn/audio_output');

  const AudioOutputService();

  Future<MediaVolume?> mediaVolume() async {
    try {
      final map = await _channel.invokeMapMethod<String, int>('mediaVolume');
      if (map == null) return null;
      return MediaVolume(map['current'] ?? 0, map['max'] ?? 0);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<OutputRoute> outputRoute() async {
    try {
      final route = await _channel.invokeMethod<String>('outputRoute');
      return OutputRoute.values.firstWhere((r) => r.name == route, orElse: () => OutputRoute.unknown);
    } on MissingPluginException {
      return OutputRoute.unknown;
    } on PlatformException {
      return OutputRoute.unknown;
    }
  }
}
