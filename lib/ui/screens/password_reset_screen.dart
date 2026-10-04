import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth_messages.dart';
import 'auth_widgets.dart';

/// "Esqueci minha senha" por código de 6 dígitos [UX/AUTH].
///
/// Código em vez de link: o app não tem deep link, e o código funciona mesmo quando o e-mail é
/// aberto em outro aparelho. Exige que o modelo "Reset Password" do Supabase inclua
/// `{{ .Token }}` (docs/PLAY_STORE.md). Ao validar o código o Supabase abre a sessão; o
/// SessionGate troca a tela de baixo para a Home e esta tela sai por cima ao terminar.
class PasswordResetScreen extends StatefulWidget {
  final String initialEmail;

  const PasswordResetScreen({super.key, this.initialEmail = ''});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail);
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _codeSent = false;
  bool _codeVerified = false;
  bool _isLoading = false;
  String? _emailError;
  String? _codeError;
  String? _passwordError;
  String? _formError;
  String? _info;

  void _clearMessages() {
    _emailError = null;
    _codeError = null;
    _passwordError = null;
    _formError = null;
    _info = null;
  }

  void _showFeedback(AuthFeedback feedback) {
    setState(() {
      switch (feedback.field) {
        case AuthField.email:
          _emailError = feedback.message;
        case AuthField.code:
          _codeError = feedback.message;
        case AuthField.password:
          _passwordError = feedback.message;
        case AuthField.form:
          _formError = feedback.message;
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
    } on AuthException catch (e) {
      debugPrint('Falha na recuperação de senha: ${e.code}');
      if (mounted) _showFeedback(AuthMessages.fromCode(e.code));
    } catch (e) {
      debugPrint('Falha na recuperação de senha: $e');
      if (mounted) _showFeedback(AuthMessages.offline);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    setState(() {
      _clearMessages();
      _emailError = AuthMessages.validateEmail(email);
    });
    if (_emailError != null) return;
    await _run(() async {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _info =
            'Se houver uma conta com $email, você vai receber um código de 6 números. '
            'Se não chegar em alguns minutos, confira a pasta de spam.';
      });
    });
  }

  Future<void> _saveNewPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _clearMessages();
      if (!_codeVerified) _codeError = AuthMessages.validateCode(code);
      _passwordError = AuthMessages.validatePassword(password, isNew: true);
    });
    if (_codeError != null || _passwordError != null) return;

    await _run(() async {
      final auth = Supabase.instance.client.auth;
      // O código só vale uma vez: depois de validado, novas tentativas só trocam a senha.
      if (!_codeVerified) {
        await auth.verifyOTP(email: email, token: code, type: OtpType.recovery);
        _codeVerified = true;
      }
      await auth.updateUser(UserAttributes(password: password));
      TextInput.finishAutofillContext();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(
          content: Text('Senha alterada. Você já está conectado.',
              style: TextStyle(fontSize: 15))));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.background,
      appBar: AppBar(
        backgroundColor: AuthColors.background,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthHeader(
                      title: 'Nova senha',
                      subtitle: _codeSent
                          ? 'Digite o código que chegou no seu e-mail e escolha uma nova senha.'
                          : 'Informe o e-mail da sua conta. Vamos enviar um código para criar uma nova senha.',
                    ),
                    const SizedBox(height: 32),
                    if (_formError != null || _info != null) ...[
                      AuthMessageBanner(
                          message: _formError ?? _info!,
                          isError: _formError != null),
                      const SizedBox(height: 20),
                    ],
                    AuthTextField(
                      controller: _emailController,
                      label: 'E-mail',
                      error: _emailError,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: _codeSent
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_codeSent && !_isLoading) _sendCode();
                      },
                    ),
                    if (_codeSent) ..._buildCodeStep(),
                    const SizedBox(height: 24),
                    AuthPrimaryButton(
                      label: _codeSent ? 'Salvar nova senha' : 'Enviar código',
                      loading: _isLoading,
                      onPressed: _codeSent ? _saveNewPassword : _sendCode,
                    ),
                    if (_codeSent && !_codeVerified) ...[
                      const SizedBox(height: 8),
                      AuthLinkButton(
                          label: 'Enviar outro código',
                          onPressed: _isLoading ? null : _sendCode),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCodeStep() {
    return [
      if (!_codeVerified) ...[
        const SizedBox(height: 16),
        AuthTextField(
          controller: _codeController,
          label: 'Código de 6 números',
          error: _codeError,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
        ),
      ],
      const SizedBox(height: 16),
      AuthTextField(
        controller: _passwordController,
        label: 'Nova senha',
        helper: 'Pelo menos ${AuthMessages.minPasswordLength} caracteres.',
        error: _passwordError,
        isPassword: true,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          if (!_isLoading) _saveNewPassword();
        },
      ),
    ];
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
