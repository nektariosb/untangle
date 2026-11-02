// Renders Play Store graphics into docs/store/.
// Run from the project root: flutter test tool/gen_store_test.dart
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:untangle/game/puzzle.dart';

const _board = Color(0xFF1C2114);
const _line = Color(0xFF6F7B4E);
const _crossing = Color(0xFFD9774B);
const _dot = Color(0xFFE6DDB8);
const _solved = Color(0xFFB5D96A);

final _seed = int.tryParse(Platform.environment['STORE_SEED'] ?? '') ?? 4;
final _out = Platform.environment['STORE_OUT'] ?? 'docs/store';

/// Draws [pts] (unit square) into [rect] with the board's line/dot style.
void _paintBoard(
  Canvas canvas,
  Rect rect,
  Puzzle puzzle,
  List<Offset> pts, {
  required bool solved,
}) {
  Offset at(Offset p) =>
      rect.topLeft + Offset(p.dx * rect.width, p.dy * rect.height);
  final line = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 5;
  for (var i = 0; i < puzzle.edges.length; i++) {
    final e = puzzle.edges[i];
    line.color = solved ? _solved : (puzzle.crossing[i] ? _crossing : _line);
    canvas.drawLine(at(pts[e.a]), at(pts[e.b]), line);
  }
  for (final p in pts) {
    canvas.drawCircle(at(p), 11, Paint()..color = solved ? _solved : _dot);
  }
}

/// Spreads the solved layout out like a player tidying it: springs on edges,
/// repulsion between dots, and any step that creates a crossing is undone.
List<Offset> _tidy(Puzzle puzzle) {
  final pts = puzzle.positions..setAll(0, puzzle.solution);
  final n = pts.length;
  const k = 0.3;
  for (var iter = 0; iter < 600; iter++) {
    final step = 0.02 * (1 - iter / 600) + 0.002;
    for (var v = 0; v < n; v++) {
      var force = Offset.zero;
      for (var u = 0; u < n; u++) {
        if (u == v) continue;
        final d = pts[v] - pts[u];
        final dist = max(d.distance, 1e-3);
        force += d / dist * (k * k / dist);
      }
      for (final u in puzzle.neighbors[v]) {
        final d = pts[u] - pts[v];
        force += d / max(d.distance, 1e-3) * (d.distance * d.distance / k);
      }
      force += (const Offset(0.5, 0.5) - pts[v]) * 0.5;
      if (force.distance < 1e-9) continue;
      final old = pts[v];
      final moved = old + force / force.distance * step;
      pts[v] = Offset(moved.dx.clamp(0.0, 1.0), moved.dy.clamp(0.0, 1.0));
      puzzle.recompute();
      if (puzzle.crossingCount > 0) pts[v] = old;
    }
  }
  puzzle.recompute();
  // Fit to the unit square (an affine map keeps it crossing-free).
  final xs = pts.map((p) => p.dx), ys = pts.map((p) => p.dy);
  final minX = xs.reduce(min), maxX = xs.reduce(max);
  final minY = ys.reduce(min), maxY = ys.reduce(max);
  return [
    for (final p in pts)
      Offset((p.dx - minX) / (maxX - minX), (p.dy - minY) / (maxY - minY)),
  ];
}

Future<void> _save(
  String path,
  int width,
  int height,
  void Function(Canvas) paint,
) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(width, height);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('generate store graphics', (tester) async {
    await tester.runAsync(() async {
      // 512×512 icon, downscaled from the launcher icon.
      final codec = await ui.instantiateImageCodec(
        File('assets/icon/icon.png').readAsBytesSync(),
        targetWidth: 512,
        targetHeight: 512,
      );
      final icon = (await codec.getNextFrame()).image;
      await _save('$_out/icon_512.png', 512, 512, (canvas) {
        canvas.drawImage(icon, Offset.zero, Paint());
      });

      final puzzle = Puzzle.generate(5, Random(_seed));
      final tangled = List.of(puzzle.positions);
      final tidy = _tidy(puzzle);
      puzzle
        ..positions.setAll(0, tangled)
        ..recompute();

      await _save('$_out/feature_graphic.png', 1024, 500, (canvas) {
        canvas.drawColor(_board, BlendMode.src);
        const side = 360.0;
        _paintBoard(
          canvas,
          const Rect.fromLTWH(70, 70, side, side),
          puzzle,
          tangled,
          solved: false,
        );
        // Chevron between the two boards.
        final arrow = Paint()
          ..color = _line
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawPath(
          Path()
            ..moveTo(498, 222)
            ..lineTo(526, 250)
            ..lineTo(498, 278),
          arrow,
        );
        _paintBoard(
          canvas,
          const Rect.fromLTWH(1024 - 70 - side, 70, side, side),
          puzzle,
          tidy,
          solved: true,
        );
      });
    });
  });
}
