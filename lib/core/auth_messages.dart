/// Mensagens de entrada e cadastro em pt-BR [UX/AUTH].
///
/// Cada erro diz o que aconteceu e como resolver, e aponta o campo afetado para a tela
/// mostrar a mensagem junto dele (auditoria de UX, achado A1). Código puro: sem Flutter nem
/// Supabase, para ser testado isolado (test/auth_messages_test.dart).
enum AuthField { email, password, code, form }

class AuthFeedback {
  final AuthField field;
  final String message;

  /// Verdadeiro quando a conta existe mas falta confirmar o e-mail: a tela oferece reenviar.
  final bool needsEmailConfirmation;

  const AuthFeedback(this.field, this.message,
      {this.needsEmailConfirmation = false});
}

class AuthMessages {
  const AuthMessages._();

  static const int minPasswordLength = 8;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? validateEmail(String email) {
    if (email.isEmpty) return 'Informe seu e-mail.';
    if (!_emailPattern.hasMatch(email)) {
      return 'Confira o e-mail. Ele precisa ter o formato nome@exemplo.com.';
    }
    return null;
  }

  /// No login só exige preenchimento: a regra de tamanho vale para senhas novas.
  static String? validatePassword(String password, {required bool isNew}) {
    if (password.isEmpty) return 'Informe sua senha.';
    if (isNew && password.length < minPasswordLength) {
      return 'A senha precisa ter pelo menos $minPasswordLength caracteres.';
    }
    return null;
  }

  static String? validateCode(String code) {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return 'Digite os 6 números do código que enviamos por e-mail.';
    }
    return null;
  }

  /// Traduz o `code` de erro do Supabase Auth. Código desconhecido vira mensagem genérica:
  /// a mensagem técnica em inglês nunca chega à tela.
  static AuthFeedback fromCode(String? code) {
    switch (code) {
      case 'invalid_credentials':
        return const AuthFeedback(AuthField.password,
            'E-mail ou senha incorretos. Confira e tente de novo, ou toque em "Esqueci minha senha".');
      case 'email_not_confirmed':
        return const AuthFeedback(AuthField.form,
            'Falta confirmar seu e-mail. Abra a mensagem que enviamos e toque no link de confirmação.',
            needsEmailConfirmation: true);
      case 'user_already_exists':
      case 'email_exists':
        return const AuthFeedback(AuthField.email,
            'Este e-mail já tem conta. Toque em "Já tem conta? Entrar".');
      case 'weak_password':
        return const AuthFeedback(AuthField.password,
            'Essa senha é fácil de adivinhar. Use pelo menos 8 caracteres, misturando letras e números.');
      case 'same_password':
        return const AuthFeedback(AuthField.password,
            'A nova senha precisa ser diferente da anterior.');
      case 'email_address_invalid':
      case 'validation_failed':
        return const AuthFeedback(AuthField.email,
            'Confira o e-mail. Ele precisa ter o formato nome@exemplo.com.');
      case 'otp_expired':
        return const AuthFeedback(AuthField.code,
            'Código incorreto ou vencido. Confira os números ou peça um novo código.');
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return const AuthFeedback(AuthField.form,
            'Foram muitas tentativas seguidas. Aguarde alguns minutos e tente de novo.');
      case 'signup_disabled':
        return const AuthFeedback(AuthField.form,
            'Novos cadastros estão pausados no momento. Tente mais tarde.');
      default:
        return const AuthFeedback(AuthField.form,
            'Não foi possível concluir agora. Tente de novo em instantes.');
    }
  }

  static const AuthFeedback offline = AuthFeedback(AuthField.form,
      'Sem conexão com o servidor. Verifique a internet e tente de novo.');
}
