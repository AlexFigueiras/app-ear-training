import 'package:ear_training/core/auth_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validação local', () {
    test('e-mail vazio ou sem formato é recusado com orientação', () {
      expect(AuthMessages.validateEmail(''), 'Informe seu e-mail.');
      expect(
          AuthMessages.validateEmail('maria@'), contains('nome@exemplo.com'));
      expect(AuthMessages.validateEmail('maria@exemplo.com'), isNull);
    });

    test('regra de tamanho só vale para senha nova', () {
      expect(AuthMessages.validatePassword('', isNew: false),
          'Informe sua senha.');
      expect(AuthMessages.validatePassword('123', isNew: false), isNull);
      expect(AuthMessages.validatePassword('1234567', isNew: true),
          contains('8 caracteres'));
      expect(AuthMessages.validatePassword('12345678', isNew: true), isNull);
    });

    test('código de recuperação precisa de 6 números', () {
      expect(AuthMessages.validateCode('12345'), isNotNull);
      expect(AuthMessages.validateCode('12a456'), isNotNull);
      expect(AuthMessages.validateCode('123456'), isNull);
    });
  });

  group('erros do Supabase', () {
    test('senha errada aponta o campo de senha e sugere recuperação', () {
      final f = AuthMessages.fromCode('invalid_credentials');
      expect(f.field, AuthField.password);
      expect(f.message, contains('Esqueci minha senha'));
    });

    test('e-mail não confirmado oferece reenvio', () {
      final f = AuthMessages.fromCode('email_not_confirmed');
      expect(f.needsEmailConfirmation, isTrue);
    });

    test('código desconhecido nunca mostra texto técnico', () {
      final f = AuthMessages.fromCode('unexpected_failure');
      expect(f.field, AuthField.form);
      expect(f.message, isNot(contains('_')));
      expect(f.message, startsWith('Não foi possível'));
    });

    test('nenhuma mensagem fica em caixa alta', () {
      const codes = [
        'invalid_credentials',
        'email_not_confirmed',
        'user_already_exists',
        'weak_password',
        'same_password',
        'otp_expired',
        'over_request_rate_limit',
        'signup_disabled',
        null,
      ];
      for (final code in codes) {
        final m = AuthMessages.fromCode(code).message;
        expect(m, isNot(equals(m.toUpperCase())), reason: '$code');
      }
    });
  });
}
