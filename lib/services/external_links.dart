import 'package:flutter/services.dart';

/// Abre um endereço https fora do app (Google Play, páginas legais), pelo canal nativo
/// `bosyn/external` (MainActivity.kt) — sem pacote novo. Fora do Android (e nos testes)
/// devolve false em vez de falhar.
class ExternalLinks {
  static const _channel = MethodChannel('bosyn/external');

  const ExternalLinks();

  Future<bool> open(String url) async {
    if (!url.startsWith('https://')) return false;
    try {
      return await _channel.invokeMethod<bool>('openUrl', {'url': url}) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
