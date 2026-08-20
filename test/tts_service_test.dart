import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_training/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoogleTTSService Offline Resilience Tests', () {
    test('Synthesizes valid WAV file offline with autonomous fallback', () async {
      // Instancia sem API key para forçar o fallback autônomo offline
      final tts = GoogleTTSService('');
      final path = await tts.synthesize('Selo');

      expect(path, isNotEmpty);
      final file = File(path);
      expect(await file.exists(), isTrue);

      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(44));

      // Verifica Header RIFF / WAVE
      final header = String.fromCharCodes(bytes.sublist(0, 4));
      final format = String.fromCharCodes(bytes.sublist(8, 12));
      expect(header, 'RIFF');
      expect(format, 'WAVE');

      // Limpeza
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('Cache hit returns existing file without regeneration', () async {
      final tts = GoogleTTSService('');
      final path1 = await tts.synthesize('TesteCache');
      final file1 = File(path1);
      final modified1 = await file1.lastModified();

      final path2 = await tts.synthesize('TesteCache');
      final file2 = File(path2);
      final modified2 = await file2.lastModified();

      expect(path1, path2);
      expect(modified1, modified2);

      // Limpeza
      if (await file1.exists()) {
        await file1.delete();
      }
    });
  });
}
