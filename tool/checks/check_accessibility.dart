// Etapa 11 do plano "treino eficaz" (achados G1/G2 da auditoria de UX): trava de acessibilidade.
// O público principal tem perda auditiva relacionada à idade e muitos usam óculos; a auditoria
// achou 28 de 57 fontes abaixo de 12 px e 13 de 15 pares de cor abaixo de AA. Esta trava impede
// a regressão:
// - nenhum `fontSize` literal abaixo de 14 em lib/;
// - nenhum texto (TextStyle na mesma linha) com as cores brancas translúcidas que reprovam no
//   contraste AA sobre o fundo escuro (white10/12/24/30/38). Bordas e fundos decorativos podem
//   usá-las; texto não.
import 'dart:io';

import 'check_result.dart';

const int minFontSize = 14;

final RegExp _smallFont = RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)');
final RegExp _faintTextColor =
    RegExp(r'TextStyle\([^;]*Colors\.(white10|white12|white24|white30|white38)\b');

Future<List<CheckResult>> checkAccessibility() async {
  final results = <CheckResult>[];
  final dir = Directory('lib');
  if (!dir.existsSync()) return results;

  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final relPath = entity.path.replaceAll('\\', '/');
    final lines = await entity.readAsLines();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('//')) continue;
      for (final m in _smallFont.allMatches(line)) {
        final size = double.parse(m.group(1)!);
        if (size < minFontSize) {
          results.add(CheckResult(
            name: 'check-accessibility',
            status: 'fail',
            message: '$relPath:${i + 1} usa fontSize $size; o mínimo do app é $minFontSize '
                '(lib/ui/theme/bosyn_text.dart).',
          ));
        }
      }
      final faint = _faintTextColor.firstMatch(line);
      if (faint != null) {
        results.add(CheckResult(
          name: 'check-accessibility',
          status: 'fail',
          message: '$relPath:${i + 1} usa Colors.${faint.group(1)} em texto: contraste abaixo de AA. '
              'Use BosynText.secondary ou Colors.white70.',
        ));
      }
    }
  }
  return results;
}
