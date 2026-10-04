import 'package:flutter/material.dart';

/// Peças visuais da entrada e da recuperação de senha [UX/A11Y].
///
/// Contraste conferido contra o fundo #0A0A0A (WCAG 1.4.3): texto secundário 9:1, erro 7:1,
/// borda de campo 4:1 sobre #1A1A1A (1.4.11). Nada abaixo de 14 px (auditoria de UX, A4/G2).
class AuthColors {
  const AuthColors._();
  static const background = Color(0xFF0A0A0A);
  static const field = Color(0xFF1A1A1A);
  static const fieldBorder = Color(0xFF7A7A7A);
  static const accent = Color(0xFF00FF41);
  static const textSecondary = Color(0xFFB0B0B0);
  static const error = Color(0xFFF87171);
  static const primaryButton = Color(0xFF2563EB);
}

/// Cabeçalho: marca pequena e o título da tarefa em linguagem comum.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('BOSYN',
            style: TextStyle(
                color: AuthColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 3)),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(title,
              style: const TextStyle(
                  color: AuthColors.accent,
                  fontSize: 30,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        Text(subtitle,
            style: const TextStyle(
                color: AuthColors.textSecondary, fontSize: 16, height: 1.4)),
      ],
    );
  }
}

/// Campo com rótulo acessível (o leitor de tela anuncia o nome), erro junto do campo,
/// preenchimento automático e, para senha, o botão de mostrar/ocultar.
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? error;
  final bool isPassword;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.error,
    this.isPassword = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
        borderSide: BorderSide(color: AuthColors.fieldBorder));
    return TextField(
      controller: widget.controller,
      obscureText: widget.isPassword && _obscured,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      autocorrect: false,
      enableSuggestions: !widget.isPassword,
      style: const TextStyle(color: Colors.white, fontSize: 17),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle:
            const TextStyle(color: AuthColors.textSecondary, fontSize: 16),
        floatingLabelStyle:
            const TextStyle(color: AuthColors.accent, fontSize: 16),
        helperText: widget.helper,
        helperMaxLines: 2,
        helperStyle:
            const TextStyle(color: AuthColors.textSecondary, fontSize: 14),
        errorText: widget.error,
        errorMaxLines: 3,
        errorStyle: const TextStyle(color: AuthColors.error, fontSize: 14),
        filled: true,
        fillColor: AuthColors.field,
        enabledBorder: border,
        border: border,
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AuthColors.accent, width: 2)),
        errorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AuthColors.error)),
        focusedErrorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AuthColors.error, width: 2)),
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: () => setState(() => _obscured = !_obscured),
                tooltip: _obscured ? 'Mostrar senha' : 'Ocultar senha',
                icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off,
                    color: AuthColors.textSecondary),
              )
            : null,
      ),
    );
  }
}

/// Mensagem do formulário (erro ou aviso), anunciada pelo leitor de tela ao aparecer
/// (WCAG 4.1.3), com ações opcionais logo abaixo.
class AuthMessageBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final List<Widget> actions;

  const AuthMessageBanner(
      {super.key,
      required this.message,
      this.isError = true,
      this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AuthColors.error : AuthColors.accent;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AuthColors.field,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(isError ? Icons.error_outline : Icons.mark_email_read,
                    color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(message,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, height: 1.4)),
                ),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

/// Botão principal largo, com indicador de carregamento acessível.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const AuthPrimaryButton(
      {super.key, required this.label, required this.loading, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthColors.primaryButton,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF2A2A2A),
          disabledForegroundColor: AuthColors.textSecondary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                    semanticsLabel: 'Aguarde'))
            : Text(label,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Link de texto com área de toque de pelo menos 48 dp.
class AuthLinkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AuthLinkButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
          minimumSize: const Size(48, 48), foregroundColor: AuthColors.accent),
      onPressed: onPressed,
      child: Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 15, decoration: TextDecoration.underline)),
    );
  }
}
