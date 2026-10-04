import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ear_training/audio_engine/wav_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta um WAV PCM 16 bits. [extraChunk] (id de 4 letras + conteúdo) entra entre "fmt " e
/// "data", como o "LIST" que alguns encoders colocam.
Uint8List _wav(List<List<double>> frames,
    {required int sampleRate, int format = 1, MapEntry<String, List<int>>? extraChunk}) {
  final channels = frames.first.length;
  final dataBytes = frames.length * channels * 2;
  final extraBytes = extraChunk == null
      ? 0
      : 8 + extraChunk.value.length + (extraChunk.value.length.isOdd ? 1 : 0);
  final b = BytesBuilder();
  void tag(String s) => b.add(s.codeUnits);
  void u32(int v) => b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) => b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());

  tag('RIFF');
  u32(4 + 24 + extraBytes + 8 + dataBytes);
  tag('WAVE');
  tag('fmt ');
  u32(16);
  u16(format);
  u16(channels);
  u32(sampleRate);
  u32(sampleRate * channels * 2);
  u16(channels * 2);
  u16(16);
  if (extraChunk != null) {
    tag(extraChunk.key);
    u32(extraChunk.value.length);
    b.add(extraChunk.value);
    if (extraChunk.value.length.isOdd) b.addByte(0);
  }
  tag('data');
  u32(dataBytes);
  final pcm = ByteData(dataBytes);
  var o = 0;
  for (final frame in frames) {
    for (final s in frame) {
      pcm.setInt16(o, (s * 32767).round(), Endian.little);
      o += 2;
    }
  }
  b.add(pcm.buffer.asUint8List());
  return b.toBytes();
}

List<List<double>> _sine(double freq, int rate, double seconds, double amp) => [
      for (var i = 0; i < (rate * seconds).round(); i++)
        [amp * math.sin(2 * math.pi * freq * i / rate)]
    ];

/// Frequência estimada por cruzamentos de zero no trecho central (longe das bordas).
double _frequency(Float32List s, int rate) {
  final from = s.length ~/ 4, to = 3 * s.length ~/ 4;
  var crossings = 0;
  for (var i = from + 1; i < to; i++) {
    if ((s[i - 1] < 0) != (s[i] < 0)) crossings++;
  }
  return crossings / 2 / ((to - from) / rate);
}

void main() {
  test('WAV de 24 kHz (padrão do WaveNet) vira 48 kHz sem mudar altura nem duração', () {
    final bytes = _wav(_sine(1000, 24000, 0.5, 0.5), sampleRate: 24000);

    final out = WavDecoder.decodeToRate(bytes);

    expect(out.sampleRate, 48000);
    expect(out.samples.length, 24000); // 0,5 s a 48 kHz
    expect(out.duration.inMilliseconds, 500);
    expect(_frequency(out.samples, 48000), closeTo(1000, 10));
    final mid = out.samples.sublist(8000, 16000);
    expect(mid.reduce(math.max), closeTo(0.5, 0.02));
  });

  test('WAV já em 48 kHz passa sem reamostrar', () {
    final out = WavDecoder.decodeToRate(_wav(_sine(440, 48000, 0.1, 0.3), sampleRate: 48000));
    expect(out.samples.length, 4800);
    expect(_frequency(out.samples, 48000), closeTo(440, 15));
  });

  test('chunk extra (tamanho ímpar) entre "fmt " e "data" é pulado', () {
    final bytes = _wav(_sine(1000, 24000, 0.2, 0.5),
        sampleRate: 24000, extraChunk: const MapEntry('LIST', [1, 2, 3]));
    final out = WavDecoder.decode(bytes);
    expect(out.sampleRate, 24000);
    expect(out.samples.length, 4800);
  });

  test('estéreo é convertido para mono pela média dos canais', () {
    final frames = List.generate(100, (_) => [0.5, 0.25]);
    final out = WavDecoder.decode(_wav(frames, sampleRate: 48000));
    expect(out.samples.every((s) => (s - 0.375).abs() < 0.001), isTrue);
  });

  test('bytes sem cabeçalho RIFF são lidos como PCM cru na taxa informada', () {
    final raw = Uint8List(400); // 200 amostras de silêncio
    final out = WavDecoder.decode(raw, rawSampleRate: 24000);
    expect(out.sampleRate, 24000);
    expect(out.samples.length, 200);
  });

  test('formato que não é PCM 16 bits falha com mensagem clara', () {
    final bytes = _wav(_sine(1000, 24000, 0.01, 0.5), sampleRate: 24000, format: 3);
    expect(() => WavDecoder.decode(bytes), throwsFormatException);
  });
}
