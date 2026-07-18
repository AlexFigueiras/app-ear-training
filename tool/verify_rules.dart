// verify-rules (módulo 06 adaptado) — runner central, Dart puro, zero dependência nova.
// Roda os checks e retorna exit 0 (passou) ou exit 1 (alguma falha). Usado pelo pre-commit
// (.githooks/pre-commit) e pelo CI (.github/workflows/ci.yml) — nunca uma versão divergente.
import 'dart:io';

import 'checks/check_file_size.dart';
import 'checks/check_result.dart';
import 'checks/check_secrets.dart';

Future<void> main() async {
  final checkRunners = <String, Future<List<CheckResult>> Function()>{
    'check-file-size': checkFileSize,
    'check-secrets': checkSecrets,
  };

  final allResults = <CheckResult>[];
  for (final entry in checkRunners.entries) {
    allResults.addAll(await entry.value());
  }

  final warnings = allResults.where((r) => r.status == 'warn').toList();
  final failures = allResults.where((r) => r.status == 'fail').toList();

  for (final w in warnings) {
    stderr.writeln('⚠️  ${w.name}: ${w.message}');
  }
  for (final f in failures) {
    stderr.writeln('❌ ${f.name}: ${f.message}');
  }

  if (failures.isNotEmpty) {
    stderr.writeln('\n${failures.length} verificação(ões) falharam.');
    exit(1);
  }

  stdout.writeln(
      '✅ Todas as verificações passaram (${checkRunners.length} checks, ${warnings.length} aviso(s)).');
  exit(0);
}
