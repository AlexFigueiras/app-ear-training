import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth_messages.dart';
import '../../core/legal_documents.dart';
import 'auth_widgets.dart';
import 'legal_document_screen.dart';
import 'password_reset_screen.dart';

/// AUTH SCREEN: entrada e cadastro [SEGURANÇA/UX]
///
/// A navegação depois do login é do SessionGate (reage à sessão). O perfil é criado pelo banco
/// (trigger da migration 003) — o cliente não grava o próprio plano. Erros aparecem junto do
/// campo, em pt-BR (auditoria de UX, etapa A); confirmação de e-mail pendente oferece reenvio.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  // LGPD art. 11, I: consentimento específico e destacado para dado de saúde, nunca pré-marcado.
  bool _healthDataConsent = false;

  String? _emailError;
  String? _passwordError;
  String? _formError;
  String? _info;
  // E-mail com cadastro feito e confirmação pendente: habilita "Reenviar e-mail".
  String? _pendingConfirmation;

  void _clearMessages() {
    _emailError = null;
    _passwordError = null;
    _formError = null;
    _info = null;
  }

  void _showFeedback(AuthFeedback feedback, String email) {
    setState(() {
      switch (feedback.field) {
        case AuthField.email:
          _emailError = feedback.message;
        case AuthField.password:
          _passwordError = feedback.message;
        case AuthField.code:
        case AuthField.form:
          _formError = feedback.message;
      }
      if (feedback.needsEmailConfirmation) _pendingConfirmation = email;
    });
  }

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _clearMessages();
      _emailError = AuthMessages.validateEmail(email);
      _passwordError =
          AuthMessages.validatePassword(password, isNew: _isSignUp);
    });
    if (_emailError != null || _passwordError != null) return;

    setState(() => _isLoading = true);
    final auth = Supabase.instance.client.auth;

    try {
      if (_isSignUp) {
        // Registro com prova do consentimento (versão da política + data).
        final AuthResponse res = await auth.signUp(
          email: email,
          password: password,
          data: {
            'privacy_policy_version': LegalDocuments.privacyPolicyVersion,
            'health_data_consent_at': DateTime.now().toUtc().toIso8601String(),
          },
        );
        TextInput.finishAutofillContext();
        // Com confirmação de e-mail ativa não há sessão ainda; sem ela, o SessionGate já entra.
        if (res.session == null && mounted) {
          setState(() {
            _isSignUp = false;
            _passwordController.clear();
            _pendingConfirmation = email;
            _info =
                'Conta criada. Enviamos um link de confirmação para $email. '
                'Abra o e-mail, toque no link e depois entre aqui com sua senha.';
          });
        }
      } else {
        await auth.signInWithPassword(email: email, password: password);
        TextInput.finishAutofillContext();
      }
    } on AuthException catch (e) {
      debugPrint('Falha de autenticação: ${e.code}');
      if (mounted) _showFeedback(AuthMessages.fromCode(e.code), email);
    } catch (e) {
      debugPrint('Falha de autenticação: $e');
      if (mounted) _showFeedback(AuthMessages.offline, email);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendConfirmation() async {
    final email = _pendingConfirmation;
    if (email == null) return;
    setState(() {
      _clearMessages();
      _isLoading = true;
    });
    try {
      await Supabase.instance.client.auth
          .resend(type: OtpType.signup, email: email);
      if (mounted) {
        setState(() => _info = 'Enviamos o link de novo para $email. '
            'Se não chegar em alguns minutos, confira a pasta de spam.');
      }
    } on AuthException catch (e) {
      if (mounted) _showFeedback(AuthMessages.fromCode(e.code), email);
    } catch (_) {
      if (mounted) _showFeedback(AuthMessages.offline, email);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _clearMessages();
    });
  }

  void _openPasswordReset() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          PasswordResetScreen(initialEmail: _emailController.text.trim()),
    ));
  }

  void _openPrivacyPolicy() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const LegalDocumentScreen(
        title: 'POLÍTICA DE PRIVACIDADE',
        assetPath: LegalDocuments.privacyPolicyAsset,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_isSignUp || _healthDataConsent;
    return Scaffold(
      backgroundColor: AuthColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthHeader(
                      title: _isSignUp ? 'Criar conta' : 'Entrar',
                      subtitle: _isSignUp
                          ? 'Crie sua conta para fazer o teste auditivo e começar o treino.'
                          : 'Use o e-mail e a senha da sua conta.',
                    ),
                    const SizedBox(height: 32),
                    ..._buildMessages(),
                    AuthTextField(
                      controller: _emailController,
                      label: 'E-mail',
                      error: _emailError,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _passwordController,
                      label: 'Senha',
                      helper: _isSignUp
                          ? 'Pelo menos ${AuthMessages.minPasswordLength} caracteres.'
                          : null,
                      error: _passwordError,
                      isPassword: true,
                      autofillHints: [
                        _isSignUp
                            ? AutofillHints.newPassword
                            : AutofillHints.password
                      ],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (canSubmit && !_isLoading) _handleAuth();
                      },
                    ),
                    if (_isSignUp) ...[
                      const SizedBox(height: 16),
                      _buildConsent(),
                    ],
                    const SizedBox(height: 24),
                    AuthPrimaryButton(
                      label: _isSignUp ? 'Criar conta' : 'Entrar',
                      loading: _isLoading,
                      onPressed: canSubmit ? _handleAuth : null,
                    ),
                    if (_isSignUp && !_healthDataConsent) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Para criar a conta, marque a autorização acima.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AuthColors.textSecondary, fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (!_isSignUp)
                      AuthLinkButton(
                          label: 'Esqueci minha senha',
                          onPressed: _openPasswordReset),
                    AuthLinkButton(
                      label: _isSignUp
                          ? 'Já tem conta? Entrar'
                          : 'Primeira vez aqui? Criar conta',
                      onPressed: _toggleMode,
                    ),
                    AuthLinkButton(
                        label: 'Política de privacidade',
                        onPressed: _openPrivacyPolicy),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMessages() {
    final canResend = _pendingConfirmation != null && !_isSignUp;
    final resend = canResend
        ? [
            AuthLinkButton(
                label: 'Reenviar e-mail de confirmação',
                onPressed: _isLoading ? null : _resendConfirmation)
          ]
        : const <Widget>[];
    if (_formError != null) {
      return [
        AuthMessageBanner(message: _formError!, actions: resend),
        const SizedBox(height: 20),
      ];
    }
    if (_info != null) {
      return [
        AuthMessageBanner(message: _info!, isError: false, actions: resend),
        const SizedBox(height: 20),
      ];
    }
    return const [];
  }

  Widget _buildConsent() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFFBF00)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(LegalDocuments.healthDisclaimer,
              style: TextStyle(
                  color: AuthColors.textSecondary, fontSize: 14, height: 1.45)),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _healthDataConsent,
            onChanged: (value) =>
                setState(() => _healthDataConsent = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AuthColors.accent,
            checkColor: Colors.black,
            side: const BorderSide(color: AuthColors.fieldBorder, width: 2),
            title: const Text(
              'Li a Política de Privacidade e autorizo o tratamento dos meus dados de saúde '
              'auditiva (teste auditivo e resultados do treino) para personalizar e registrar o '
              'meu treino.',
              style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
