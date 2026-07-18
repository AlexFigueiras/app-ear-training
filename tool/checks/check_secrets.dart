// Módulo 06 (adaptado): detecta segredos em código-fonte. Diferente do kit original (que só
// varria "código cliente" via heurística 'use client'), aqui TODO o app é cliente — o check
// varre lib/ inteiro (o que de fato vai para o build). tool/ fica de fora: é código de
// governança que nunca embarca no app e cujos próprios checks citam os padrões como literais.
// Ver AGENTS.md seção 7 (leis de segurança).
import 'dart:io';

import 'check_result.dart';

List<File> _libDartFiles() {
  final files = <File>[];
  final dir = Directory('lib');
  if (!dir.existsSync()) return files;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      files.add(entity);
    }
  }
  return files;
}

const List<String> _forbiddenPatterns = [
  'SERVICE_ROLE_KEY',
  'service_role',
  '-----BEGIN',
  'sk_live_',
  'AKIA',
];

final RegExp _genericSecretPattern = RegExp(
  r'''(?:api[_-]?key|secret|token|password)\s*[:=]\s*["'][A-Za-z0-9_\-\.]{16,}["']''',
  caseSensitive: false,
);

int _lineOf(String content, int offset) {
  return '\n'.allMatches(content.substring(0, offset)).length + 1;
}

Future<List<CheckResult>> checkSecrets() async {
  final results = <CheckResult>[];

  for (final file in _libDartFiles()) {
    final relPath = file.path.replaceAll('\\', '/');
    final content = await file.readAsString();

    for (final pattern in _forbiddenPatterns) {
      if (content.contains(pattern)) {
        results.add(CheckResult(
          name: 'check-secrets',
          status: 'fail',
          message:
              '$relPath contém o padrão proibido "$pattern" — credencial privilegiada não pode '
              'estar em código cliente (AGENTS.md seção 7, lei 2).',
        ));
      }
    }

    for (final match in _genericSecretPattern.allMatches(content)) {
      results.add(CheckResult(
        name: 'check-secrets',
        status: 'fail',
        message:
            '$relPath:${_lineOf(content, match.start)} — possível segredo hard-coded ("${match.group(0)}").',
      ));
    }
  }

  return results;
}
