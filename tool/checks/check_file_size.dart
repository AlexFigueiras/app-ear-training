// Módulo 06 (adaptado): checa tamanho de arquivo .dart. > 300 linhas líquidas = warn,
// > 500 = fail. Arquivos legados listados em tool/file_size_baseline.json viram warn em vez de
// fail, mas falham se crescerem além do valor registrado (catraca — só diminui).
import 'dart:convert';
import 'dart:io';

import 'check_result.dart';

const int warnThreshold = 300;
const int failThreshold = 500;
const String baselinePath = 'tool/file_size_baseline.json';
const List<String> _scanDirs = ['lib', 'tool'];

int netLines(String content) {
  var count = 0;
  var inBlockComment = false;
  for (final raw in content.split('\n')) {
    final line = raw.trim();
    if (inBlockComment) {
      if (line.contains('*/')) inBlockComment = false;
      continue;
    }
    if (line.isEmpty) continue;
    if (line.startsWith('//')) continue;
    if (line.startsWith('/*')) {
      if (!line.contains('*/')) inBlockComment = true;
      continue;
    }
    count++;
  }
  return count;
}

List<File> dartFiles() {
  final files = <File>[];
  for (final dirName in _scanDirs) {
    final dir = Directory(dirName);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity);
      }
    }
  }
  return files;
}

Future<List<CheckResult>> checkFileSize() async {
  final results = <CheckResult>[];
  final baselineFile = File(baselinePath);
  Map<String, dynamic> baseline = {};
  if (baselineFile.existsSync()) {
    final raw = await baselineFile.readAsString();
    if (raw.trim().isNotEmpty) {
      baseline = jsonDecode(raw) as Map<String, dynamic>;
    }
  }

  for (final file in dartFiles()) {
    final relPath = file.path.replaceAll('\\', '/');
    final content = await file.readAsString();
    final lines = netLines(content);

    if (lines <= warnThreshold) continue;

    final baselineLines = baseline[relPath] as int?;

    if (baselineLines != null) {
      if (lines > baselineLines) {
        results.add(CheckResult(
          name: 'check-file-size',
          status: 'fail',
          message:
              '$relPath tem $lines linhas líquidas, acima do baseline registrado ($baselineLines). '
              'O baseline só diminui — modularize antes de crescer mais.',
        ));
      } else {
        results.add(CheckResult(
          name: 'check-file-size',
          status: 'warn',
          message:
              '$relPath tem $lines linhas líquidas (débito legado, baseline: $baselineLines). Modularize quando possível.',
        ));
      }
      continue;
    }

    if (lines > failThreshold) {
      results.add(CheckResult(
        name: 'check-file-size',
        status: 'fail',
        message:
            '$relPath tem $lines linhas líquidas (> $failThreshold). Modularize, ou registre em '
            '$baselinePath se for débito legado já conhecido.',
      ));
    } else {
      results.add(CheckResult(
        name: 'check-file-size',
        status: 'warn',
        message:
            '$relPath tem $lines linhas líquidas (> $warnThreshold). Considere modularizar.',
      ));
    }
  }

  return results;
}
