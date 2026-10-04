import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Exibe um documento legal empacotado no app (Markdown simples: `#`, `##` e listas `-`).
/// A Google Play exige a política de privacidade acessível dentro do app, além da URL.
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String assetPath;

  const LegalDocumentScreen(
      {super.key, required this.title, required this.assetPath});

  static const _bodyStyle =
      TextStyle(color: Colors.white70, fontSize: 13, height: 1.5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title:
            Text(title, style: const TextStyle(fontSize: 14, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Não foi possível abrir o documento.'));
          }
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00FF41)));
          }
          return SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                for (final line in snapshot.data!.split('\n')) _buildLine(line)
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLine(String raw) {
    final line = raw.trimRight();
    if (line.isEmpty) return const SizedBox(height: 8);

    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          line.substring(2),
          style: const TextStyle(
              color: Color(0xFF00FF41),
              fontSize: 20,
              fontWeight: FontWeight.w900),
        ),
      );
    }
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(
          line.substring(3),
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
      );
    }
    if (line.startsWith('- ')) {
      return Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  ', style: _bodyStyle),
            Expanded(
                child: SelectableText(line.substring(2), style: _bodyStyle)),
          ],
        ),
      );
    }
    return SelectableText(line, style: _bodyStyle);
  }
}
