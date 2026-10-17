import 'dart:convert';

import 'package:ear_training/core/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

String _fakeJwt(Map<String, dynamic> claims) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part(claims)}.assinatura';
}

void main() {
  group('AppConfig.isPublicClientKey', () {
    test('aceita chave publishable', () {
      expect(AppConfig.isPublicClientKey('sb_publishable_abc123'), isTrue);
    });

    test('aceita JWT legado com role anon', () {
      expect(AppConfig.isPublicClientKey(_fakeJwt({'role': 'anon'})), isTrue);
    });

    test('recusa chave secreta e JWT de outro role', () {
      expect(AppConfig.isPublicClientKey('sb_secret_abc123'), isFalse);
      expect(AppConfig.isPublicClientKey(_fakeJwt({'role': 'service_role'})),
          isFalse);
      expect(AppConfig.isPublicClientKey(_fakeJwt({'role': 'authenticated'})),
          isFalse);
    });

    test('recusa valores que não são chave', () {
      expect(AppConfig.isPublicClientKey('abc'), isFalse);
      expect(AppConfig.isPublicClientKey('a.b.c'), isFalse);
    });
  });

  group('AppConfig.validate', () {
    test('configuração válida não tem problemas', () {
      final problems = AppConfig.validate(
        url: 'https://abc.supabase.co',
        publishableKey: 'sb_publishable_x',
        allowInsecureHttp: false,
      );
      expect(problems, isEmpty);
    });

    test('valores ausentes são reportados', () {
      final problems = AppConfig.validate(
          url: '', publishableKey: '', allowInsecureHttp: false);
      expect(problems, hasLength(2));
    });

    test('http só é aceito em debug (Supabase local)', () {
      const url = 'http://10.0.2.2:54321';
      expect(
        AppConfig.validate(
            url: url,
            publishableKey: 'sb_publishable_x',
            allowInsecureHttp: false),
        hasLength(1),
      );
      expect(
        AppConfig.validate(
            url: url,
            publishableKey: 'sb_publishable_x',
            allowInsecureHttp: true),
        isEmpty,
      );
    });

    test('chave privilegiada impede o boot', () {
      final problems = AppConfig.validate(
        url: 'https://abc.supabase.co',
        publishableKey: 'sb_secret_x',
        allowInsecureHttp: false,
      );
      expect(problems, hasLength(1));
    });
  });
}
