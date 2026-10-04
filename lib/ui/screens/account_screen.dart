import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/legal_documents.dart';
import '../../services/account_service.dart';
import 'legal_document_screen.dart';

/// CONTA E PRIVACIDADE [LGPD/PLAY]: política de privacidade, aviso de saúde, sair e excluir a
/// conta. Exclusão dentro do app é exigência da Google Play para apps com cadastro.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await AccountService().signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint("Logout falhou: $e");
      _showError('Não foi possível sair agora. Tente de novo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await AccountService().deleteAccount(password: password);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Sua conta e todos os seus dados foram excluídos.')),
      );
    } on AuthException catch (e) {
      _showError(
          e.code == 'invalid_credentials' ? 'Senha incorreta.' : e.message);
    } catch (e) {
      debugPrint("Exclusão de conta falhou: $e");
      _showError(
          'Não foi possível excluir a conta agora. Verifique a conexão e tente de novo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          backgroundColor: const Color(0xFFE11D48), content: Text(message)),
    );
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
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('CONTA E PRIVACIDADE',
            style: TextStyle(fontSize: 14, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('CONTA',
                style: TextStyle(
                    color: Colors.white38, fontSize: 10, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text(email,
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'monospace')),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: const Color(0xFFFFBF00)),
              ),
              child: const Text(
                LegalDocuments.healthDisclaimer,
                style:
                    TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
            _buildAction(Icons.privacy_tip_outlined, 'Política de Privacidade',
                _openPrivacyPolicy),
            _buildAction(Icons.logout, 'Sair da conta', _signOut),
            _buildAction(
              Icons.delete_forever_outlined,
              'Excluir minha conta e dados',
              _deleteAccount,
              color: const Color(0xFFE11D48),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF00FF41))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(IconData icon, String label, VoidCallback onTap,
      {Color color = Colors.white}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}

/// Confirmação forte da exclusão: explica o que será apagado e pede a senha de novo.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      title: const Text('Excluir conta e dados?',
          style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Isto apaga para sempre a sua conta, o seu teste auditivo e todo o histórico de '
            'treino. Não é possível desfazer.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration:
                const InputDecoration(labelText: 'Confirme com a sua senha'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        TextButton(
          onPressed: _passwordController.text.isEmpty
              ? null
              : () => Navigator.pop(context, _passwordController.text),
          child: const Text('Excluir definitivamente',
              style: TextStyle(color: Color(0xFFE11D48))),
        ),
      ],
    );
  }
}
