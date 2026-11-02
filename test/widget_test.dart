import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untangle/game/game_screen.dart';
import 'package:untangle/game/puzzle.dart';
import 'package:untangle/game/sfx.dart';
import 'package:untangle/game/store.dart';
import 'package:untangle/main.dart';

void main() {
  test('generated puzzles are solvable and start tangled', () {
    final rng = Random(42);
    for (var lines = 4; lines <= 14; lines++) {
      final puzzle = Puzzle.generate(lines, rng);
      expect(puzzle.vertexCount, lines * (lines - 1) ~/ 2);
      expect(puzzle.edges.length, lines * (lines - 2));
      expect(puzzle.crossingCount, greaterThan(0));

      for (var v = 0; v < puzzle.vertexCount; v++) {
        puzzle.moveVertex(v, puzzle.solution[v]);
      }
      expect(puzzle.isSolved, isTrue, reason: '$lines lines');
    }
  });

  // Sfx is never initialized here, so it stays silent.
  Future<Store> pumpApp(WidgetTester tester, Map<String, Object> saved) async {
    SharedPreferences.setMockInitialValues(saved);
    final store = await Store.load();
    await tester.pumpWidget(UntangleApp(store: store, sfx: Sfx()));
    return store;
  }

  testWidgets('app starts on level 1', (tester) async {
    await pumpApp(tester, {});
    expect(find.text('Level 1'), findsOneWidget);
  });

  testWidgets('saved level is restored, but never past unlocked', (
    tester,
  ) async {
    await pumpApp(tester, {'level': 5, 'unlocked': 3});
    expect(find.text('Level 3'), findsOneWidget);
  });

  testWidgets('solving plays the animation and unlocks the next level', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.load();
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          store: store,
          sfx: Sfx(),
          onToggleTheme: (_) {},
          random: Random(7),
        ),
      ),
    );
    // Same seed and draw order as the screen, so this is the same puzzle.
    final puzzle = Puzzle.generate(4, Random(7));
    final board = tester.getRect(
      find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_BoardPainter',
      ),
    );
    const pad = 13.0 + 6; // dot radius for 6 dots + margin
    Offset toScreen(Offset p) =>
        board.topLeft +
        Offset(
          pad + p.dx * (board.width - 2 * pad),
          pad + p.dy * (board.height - 2 * pad),
        );

    for (var v = 0; v < puzzle.vertexCount; v++) {
      final from = toScreen(puzzle.positions[v]);
      final to = toScreen(puzzle.solution[v]);
      final gesture = await tester.startGesture(from);
      await gesture.moveTo(Offset.lerp(from, to, 0.5)!);
      await gesture.moveTo(to);
      await gesture.up();
      await tester.pump();
    }

    expect(find.text('No crossings'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Untangled!'), findsNothing); // wave still running
    await tester.pumpAndSettle();
    expect(find.text('Untangled!'), findsOneWidget);
    expect(find.text('Level 2'), findsOneWidget);
    expect(store.unlocked, 2);
  });

  testWidgets('mute toggle is saved', (tester) async {
    final store = await pumpApp(tester, {});
    await tester.tap(find.byIcon(Icons.volume_up_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.volume_off_outlined), findsOneWidget);
    expect(store.muted, isTrue);
  });
}
