import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/legal_html.dart' show inline, markdownToPage, pages;

void main() {
  test('converte o mesmo Markdown que o app mostra em página com título e seções', () {
    final html = markdownToPage('# Política\n\nTexto <com> & símbolos.\n\n## 1. Seção\n\n- um\n- dois\n\nFim.');
    expect(html, contains('<title>Política</title>'));
    expect(html, contains('<h1>Política</h1>'));
    expect(html, contains('<p>Texto &lt;com&gt; &amp; símbolos.</p>'));
    expect(html, contains('<h2>1. Seção</h2>'));
    expect(html, contains('<ul>\n<li>um</li>\n<li>dois</li>\n</ul>'));
    expect(html, contains('lang="pt-BR"'));
  });

  test('endereços e e-mails viram links, sem link dentro de link', () {
    expect(inline('Veja https://policies.google.com/privacy.'),
        'Veja <a href="https://policies.google.com/privacy" rel="noopener">https://policies.google.com/privacy</a>.');
    expect(inline('Escreva para contato@bosyn.com.br'),
        'Escreva para <a href="mailto:contato@bosyn.com.br">contato@bosyn.com.br</a>');
  });

  test('as páginas publicadas saem dos arquivos que o app usa', () {
    for (final source in pages.values) {
      expect(File(source).existsSync(), isTrue, reason: source);
    }
    expect(pages.values, contains('docs/legal/politica-de-privacidade.md'));
  });
}
