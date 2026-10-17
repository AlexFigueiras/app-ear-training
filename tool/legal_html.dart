// Gera as páginas públicas da política de privacidade e da exclusão de conta a partir dos
// mesmos arquivos que o app mostra (docs/legal/*.md) — fonte única, sem cópia para divergir
// (lib/core/legal_documents.dart). As páginas vão para o site do desenvolvedor
// (https://alexfigueiras.github.io), cujos endereços estão na Play Console.
// Dart puro, zero dependência nova (AGENTS.md seção 2, item 4).
//
// Uso:
//   dart tool/legal_html.dart             → build/site/ (aceita [PREENCHER], para revisar)
//   dart tool/legal_html.dart --publicar  → recusa se ainda houver [PREENCHER]
import 'dart:io';

/// Página publicada → arquivo de origem.
const Map<String, String> pages = {
  'politica-bosyn.html': 'docs/legal/politica-de-privacidade.md',
  'exclusao-de-conta-bosyn.html': 'docs/legal/exclusao-de-conta.md',
};

void main(List<String> args) {
  final publish = args.contains('--publicar');
  final out = Directory('build/site')..createSync(recursive: true);

  var pending = 0;
  for (final entry in pages.entries) {
    final markdown = File(entry.value).readAsStringSync();
    final blanks = '[PREENCHER'.allMatches(markdown).length;
    if (blanks > 0) {
      pending += blanks;
      stderr.writeln('⚠️  ${entry.value}: $blanks campo(s) [PREENCHER].');
    }
    File('${out.path}/${entry.key}').writeAsStringSync(markdownToPage(markdown));
    stdout.writeln('✅ ${out.path}/${entry.key}');
  }

  if (publish && pending > 0) {
    stderr.writeln(
        '\n❌ Não publique ainda: preencha os $pending campo(s) [PREENCHER] e gere de novo.');
    exit(1);
  }
}

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

final RegExp _url = RegExp(r'https://[^\s)<>"]+[^\s)<>".,;:]');
final RegExp _email = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');

/// Texto de uma linha: escapa HTML e transforma endereços e e-mails em links.
String inline(String text) {
  final escaped = _escape(text);
  final withUrls = escaped.replaceAllMapped(
      _url, (m) => '<a href="${m[0]}" rel="noopener">${m[0]}</a>');
  return withUrls.replaceAllMapped(_email, (m) {
    final before = withUrls.substring(0, m.start);
    // Não mexe em e-mail que já está dentro de um link.
    if (before.lastIndexOf('<a ') > before.lastIndexOf('</a>')) return m[0]!;
    return '<a href="mailto:${m[0]}">${m[0]}</a>';
  });
}

/// O mesmo subconjunto de Markdown que o app entende (legal_document_screen.dart):
/// "# título", "## seção", "- item" e parágrafos.
String markdownToPage(String markdown) {
  final body = StringBuffer();
  var title = 'BOSYN';
  var inList = false;

  void closeList() {
    if (inList) body.writeln('</ul>');
    inList = false;
  }

  for (final raw in markdown.split('\n')) {
    final line = raw.trimRight();
    if (line.startsWith('# ')) {
      closeList();
      title = line.substring(2);
      body.writeln('<h1>${inline(title)}</h1>');
    } else if (line.startsWith('## ')) {
      closeList();
      body.writeln('<h2>${inline(line.substring(3))}</h2>');
    } else if (line.startsWith('- ')) {
      if (!inList) body.writeln('<ul>');
      inList = true;
      body.writeln('<li>${inline(line.substring(2))}</li>');
    } else if (line.isEmpty) {
      closeList();
    } else {
      closeList();
      body.writeln('<p>${inline(line)}</p>');
    }
  }
  closeList();

  return '''<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_escape(title)}</title>
<style>
  :root{--bg:#fbf7f1;--fg:#20202a;--muted:#5f5f6e;--accent:#1f4fd1;--line:#e3ded6}
  @media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#0d0d0f;--fg:#f2f2f5;--muted:#b8b8c0;--accent:#8fb0ff;--line:#2c2c33}}
  :root[data-theme="dark"]{--bg:#0d0d0f;--fg:#f2f2f5;--muted:#b8b8c0;--accent:#8fb0ff;--line:#2c2c33}
  html,body{background:var(--bg)}
  body{color:var(--fg);font:17px/1.65 system-ui,-apple-system,"Segoe UI",sans-serif;margin:0;padding:0 16px}
  main{max-width:680px;margin:0 auto;padding:40px 0 64px}
  h1{font-size:clamp(26px,6vw,34px);line-height:1.15;margin:0 0 12px}
  h2{font-size:20px;margin:28px 0 8px;padding-top:20px;border-top:1px solid var(--line)}
  p,li{max-width:65ch}
  ul{padding-left:22px}
  a{color:var(--accent);font-weight:600;overflow-wrap:anywhere}
</style>
</head>
<body>
<main>
$body</main>
</body>
</html>
''';
}
