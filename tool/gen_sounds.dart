// Synthesizes the bundled sound effects into assets/sounds/.
// Run from the project root: dart run tool/gen_sounds.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const _rate = 44100;

void main() {
  Directory('assets/sounds').createSync(recursive: true);
  _writeWav('assets/sounds/grab.wav', _grab());
  _writeWav('assets/sounds/solve.wav', _solve());
}

/// A short, soft wooden tick.
List<double> _grab() {
  final n = (_rate * 0.06).round();
  return List.generate(n, (i) {
    final t = i / _rate;
    final attack = min(1.0, t / 0.002);
    final body = sin(2 * pi * 620 * t) * exp(-t / 0.012);
    final knock = sin(2 * pi * 1240 * t) * exp(-t / 0.005) * 0.4;
    return attack * (body + knock) * 0.35;
  });
}

/// Two gentle bell notes, a fifth apart.
List<double> _solve() {
  final n = (_rate * 1.8).round();
  final out = List.filled(n, 0.0);
  void bell(double freq, double start, double gain) {
    final s0 = (start * _rate).round();
    for (var i = s0; i < n; i++) {
      final t = (i - s0) / _rate;
      final attack = min(1.0, t / 0.004);
      final v =
          sin(2 * pi * freq * t) * exp(-t / 0.55) +
          sin(2 * pi * freq * 2.01 * t) * exp(-t / 0.25) * 0.3 +
          sin(2 * pi * freq * 3.03 * t) * exp(-t / 0.12) * 0.12;
      out[i] += attack * v * gain;
    }
  }

  bell(659.25, 0, 0.22); // E5
  bell(987.77, 0.14, 0.18); // B5
  // Fade the tail to silence.
  for (var i = 0; i < n; i++) {
    out[i] *= min(1.0, (n - i) / (_rate * 0.2));
  }
  return out;
}

void _writeWav(String path, List<double> samples) {
  final data = ByteData(44 + samples.length * 2);
  void str(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, _rate, Endian.little);
  data.setUint32(28, _rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(44 + i * 2, v, Endian.little);
  }
  File(path).writeAsBytesSync(data.buffer.asUint8List());
}
