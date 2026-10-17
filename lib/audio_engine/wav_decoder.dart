import 'dart:math' as math;
import 'dart:typed_data';

/// Áudio PCM decodificado: amostras mono em ponto flutuante (-1..1) na taxa [sampleRate].
class DecodedAudio {
  final Float32List samples;
  final int sampleRate;

  const DecodedAudio(this.samples, this.sampleRate);

  Duration get duration =>
      Duration(microseconds: samples.length * 1000000 ~/ sampleRate);
}

/// Decodificador de WAV PCM 16 bits e reamostrador para a taxa do motor (48 kHz).
///
/// Por que existe: o Google TTS devolve LINEAR16 na taxa nativa da voz (24 kHz no WaveNet) e o
/// motor toca a 48 kHz. O código antigo pulava 44 bytes fixos e tocava as amostras como se fossem
/// 48 kHz: a voz saía uma oitava acima e com o dobro da velocidade. Aqui o cabeçalho é lido
/// de verdade (chunks RIFF em qualquer ordem) e a taxa é convertida.
class WavDecoder {
  const WavDecoder._();

  static const int engineSampleRate = 48000;

  /// Decodifica [bytes] e devolve mono na taxa [targetRate].
  /// Bytes sem cabeçalho RIFF são tratados como PCM 16 bits mono na taxa [rawSampleRate].
  static DecodedAudio decodeToRate(Uint8List bytes,
      {int targetRate = engineSampleRate, int rawSampleRate = 24000}) {
    final decoded = decode(bytes, rawSampleRate: rawSampleRate);
    if (decoded.sampleRate == targetRate) return decoded;
    return DecodedAudio(
        resample(decoded.samples, decoded.sampleRate, targetRate), targetRate);
  }

  static DecodedAudio decode(Uint8List bytes, {int rawSampleRate = 24000}) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 12 || _tag(bytes, 0) != 'RIFF' || _tag(bytes, 8) != 'WAVE') {
      return DecodedAudio(_pcm16ToMono(data, 0, bytes.length, 1), rawSampleRate);
    }

    int? channels, sampleRate, bitsPerSample, format;
    int offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = _tag(bytes, offset);
      final size = data.getUint32(offset + 4, Endian.little);
      final body = offset + 8;
      final end = math.min(body + size, bytes.length);

      if (id == 'fmt ' && size >= 16) {
        format = data.getUint16(body, Endian.little);
        channels = data.getUint16(body + 2, Endian.little);
        sampleRate = data.getUint32(body + 4, Endian.little);
        bitsPerSample = data.getUint16(body + 14, Endian.little);
      } else if (id == 'data') {
        if (channels == null || sampleRate == null) {
          throw const FormatException('WAV sem chunk "fmt " antes de "data".');
        }
        if (format != 1 || bitsPerSample != 16) {
          throw FormatException(
              'WAV não suportado (formato $format, $bitsPerSample bits); esperado PCM 16 bits.');
        }
        return DecodedAudio(_pcm16ToMono(data, body, end, channels), sampleRate);
      }
      offset = body + size + (size.isOdd ? 1 : 0); // chunks são alinhados em 2 bytes
    }
    throw const FormatException('WAV sem chunk "data".');
  }

  /// Reamostragem por sinc janelado (Blackman), com corte na menor das duas Nyquists.
  /// Qualidade suficiente para fala; custo ~32 multiplicações por amostra de saída.
  static Float32List resample(Float32List input, int fromRate, int toRate,
      {int halfTaps = 16}) {
    if (fromRate == toRate || input.isEmpty) return Float32List.fromList(input);
    final ratio = toRate / fromRate;
    final cutoff = math.min(1.0, ratio); // em unidades da taxa de entrada
    final outLength = (input.length * ratio).floor();
    final out = Float32List(outLength);
    final step = fromRate / toRate;

    for (var n = 0; n < outLength; n++) {
      final t = n * step;
      final center = t.floor();
      var acc = 0.0;
      for (var k = center - halfTaps + 1; k <= center + halfTaps; k++) {
        if (k < 0 || k >= input.length) continue;
        final x = t - k;
        final w = _blackman(x / halfTaps);
        acc += input[k] * cutoff * _sinc(cutoff * x) * w;
      }
      out[n] = acc;
    }
    return out;
  }

  static double _sinc(double x) {
    if (x.abs() < 1e-9) return 1.0;
    final px = math.pi * x;
    return math.sin(px) / px;
  }

  /// Janela de Blackman centrada em 0, para u em [-1, 1].
  static double _blackman(double u) {
    if (u.abs() >= 1.0) return 0.0;
    final a = math.pi * (u + 1.0); // 0..2π
    return 0.42 - 0.5 * math.cos(a) + 0.08 * math.cos(2 * a);
  }

  static Float32List _pcm16ToMono(ByteData data, int start, int end, int channels) {
    final frameBytes = 2 * channels;
    final frames = (end - start) ~/ frameBytes;
    final out = Float32List(frames);
    for (var i = 0; i < frames; i++) {
      var sum = 0;
      for (var c = 0; c < channels; c++) {
        sum += data.getInt16(start + i * frameBytes + c * 2, Endian.little);
      }
      out[i] = sum / (channels * 32768.0);
    }
    return out;
  }

  static String _tag(Uint8List bytes, int offset) =>
      String.fromCharCodes(bytes.sublist(offset, offset + 4));
}
