// Contrato compartilhado pelos checks de tool/verify_rules.dart.
class CheckResult {
  final String name;
  final String
      status; // 'warn' ou 'fail' — ausência de resultado para um arquivo = pass
  final String message;

  CheckResult(
      {required this.name, required this.status, required this.message});
}
