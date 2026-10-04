// Trava de regressão da configuração de release (Google Play + segurança). Cada regra aqui
// corresponde a um problema real já encontrado neste repo — ver docs/DECISIONS.md
// (2026-10-04, prontidão para a Play Store).
import 'dart:io';

import 'check_result.dart';

const String _pubspecPath = 'pubspec.yaml';
const String _gradlePath = 'android/app/build.gradle.kts';
const String _manifestPath = 'android/app/src/main/AndroidManifest.xml';

final RegExp _envAsset = RegExp(r'^\s*-\s*\.env\b', multiLine: true);
final RegExp _exampleAppId =
    RegExp(r'''(applicationId|namespace)\s*=\s*"com\.example''');
final RegExp _releaseDebugSigning = RegExp(
  r'''release\s*\{[^}]*signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)''',
);

Future<List<CheckResult>> checkReleaseConfig() async {
  final results = <CheckResult>[];

  void fail(String message) => results.add(CheckResult(
      name: 'check-release-config', status: 'fail', message: message));

  String? read(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      fail('$path não encontrado.');
      return null;
    }
    return file.readAsStringSync();
  }

  final pubspec = read(_pubspecPath);
  if (pubspec != null && _envAsset.hasMatch(pubspec)) {
    fail(
        '$_pubspecPath empacota .env como asset: tudo nele vai para dentro do APK. Use '
        '--dart-define-from-file=.env (lib/core/app_config.dart).');
  }

  final gradle = read(_gradlePath);
  if (gradle != null) {
    if (_exampleAppId.hasMatch(gradle)) {
      fail(
          '$_gradlePath usa o pacote com.example: a Play Store recusa esse prefixo.');
    }
    if (_releaseDebugSigning.hasMatch(gradle)) {
      fail(
          '$_gradlePath assina o release sempre com a chave debug: a Play Console recusa.');
    }
  }

  final manifest = read(_manifestPath);
  if (manifest != null && !manifest.contains('android:allowBackup="false"')) {
    fail(
        '$_manifestPath sem android:allowBackup="false": sessão e dado clínico iriam para '
        'backup em nuvem.');
  }

  return results;
}
