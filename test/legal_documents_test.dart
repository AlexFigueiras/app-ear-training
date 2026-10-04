import 'dart:io';

import 'package:ear_training/core/legal_documents.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('política empacotada existe e declara a versão gravada no consentimento',
      () {
    final policy = File(LegalDocuments.privacyPolicyAsset);
    expect(policy.existsSync(), isTrue);
    expect(policy.readAsStringSync(),
        contains('Versão ${LegalDocuments.privacyPolicyVersion}'));
  });

  test(
      'a política está declarada como asset no pubspec (exibida dentro do app)',
      () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- ${LegalDocuments.privacyPolicyAsset}'),
    );
  });
}
