// Renders the app icon and splash images into assets/icon/.
// Run from the project root: flutter test tool/gen_icon_test.dart
// Then: dart run flutter_launcher_icons && dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _darkBoard = Color(0xFF1C2114);

/// A small untangled graph: a triangle with a center dot being dragged.
void _paintGraph(
  Canvas canvas,
  double size, {
  required double scale,
  required Color edge,
  required Color spoke,
  required Color dot,
  required Color center,
}) {
  final c = Offset(size / 2, size / 2);
  Offset at(double x, double y) => c + Offset(x - 0.5, y - 0.5) * size * scale;
  final outer = [at(0.5, 0.14), at(0.12, 0.8), at(0.88, 0.8)];
  final mid = at(0.5, 0.58);
  final line = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = size * scale * 0.045;

  line.color = edge;
  for (var i = 0; i < 3; i++) {
    canvas.drawLine(outer[i], outer[(i + 1) % 3], line);
  }
  line
    ..color = spoke
    ..strokeWidth = size * scale * 0.06;
  for (final p in outer) {
    canvas.drawLine(mid, p, line);
  }

  final r = size * scale * 0.075;
  for (final p in outer) {
    canvas.drawCircle(p, r, Paint()..color = dot);
  }
  canvas.drawCircle(
    mid,
    r * 1.9,
    Paint()
      ..color = center.withValues(alpha: 0.3)
      ..maskFilter = ui.MaskFilter.blur(BlurStyle.normal, r * 0.6),
  );
  canvas.drawCircle(mid, r * 1.3, Paint()..color = center);
}

void _darkGraph(Canvas canvas, double size, double scale) => _paintGraph(
  canvas,
  size,
  scale: scale,
  edge: const Color(0xFF8E9B5E),
  spoke: const Color(0xFFC8E25A),
  dot: const Color(0xFFE6DDB8),
  center: Colors.white,
);

Future<void> _save(String path, void Function(Canvas, double) paint) async {
  const size = 1024.0;
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('generate icon images', (tester) async {
    await tester.runAsync(() async {
      // Full-bleed square: Play Store, iOS, web, legacy Android.
      await _save('assets/icon/icon.png', (canvas, size) {
        canvas.drawColor(_darkBoard, BlendMode.src);
        _darkGraph(canvas, size, 0.72);
      });
      // Adaptive foreground: keep inside the central safe zone.
      await _save('assets/icon/foreground.png', (canvas, size) {
        _darkGraph(canvas, size, 0.6);
      });
      // Splash images (Android 12 masks them to a circle).
      await _save('assets/icon/splash_dark.png', (canvas, size) {
        _darkGraph(canvas, size, 0.55);
      });
      await _save('assets/icon/splash_light.png', (canvas, size) {
        _paintGraph(
          canvas,
          size,
          scale: 0.55,
          edge: const Color(0xFFA3AA86),
          spoke: const Color(0xFF9DC02E),
          dot: const Color(0xFF55611F),
          center: const Color(0xFF1F2314),
        );
      });
    });
  });
}
