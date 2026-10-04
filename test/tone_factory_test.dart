import 'package:ear_training/audio_engine/tone_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tom começa e termina em zero (rampa) e chega à amplitude no meio', () {
    final tone = ToneFactory.sine(frequencyHz: 1000, seconds: 0.5, amplitude: 0.5);

    expect(tone.length, 24000);
    expect(tone.first.abs(), lessThan(1e-6));
    expect(tone.last.abs(), lessThan(0.01));
    // Primeiros 2 ms ainda bem abaixo da amplitude cheia (sem clique de ataque).
    expect(tone.sublist(0, 96).every((s) => s.abs() < 0.05), isTrue);
    final middle = tone.sublist(10000, 14000);
    expect(middle.reduce((a, b) => a > b ? a : b), closeTo(0.5, 0.001));
  });

  test('tom de calibração fica em -20 dBFS', () {
    final tone = ToneFactory.sine(
        frequencyHz: 1000, seconds: 0.2, amplitude: ToneFactory.calibrationAmplitude);
    expect(tone.reduce((a, b) => a > b ? a : b), closeTo(0.1, 0.001));
  });

  test('rampa de sinal muito curto não passa da metade', () {
    final tone = ToneFactory.sine(frequencyHz: 1000, seconds: 0.01, amplitude: 1.0);
    expect(tone.length, 480);
    expect(tone.first.abs(), lessThan(1e-6));
  });
}
