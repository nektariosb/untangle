import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untangle/game/game_screen.dart';
import 'package:untangle/game/levels.dart';
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

  test('mesh levels are solvable, start scattered and tangled', () {
    final rng = Random(5);
    for (var level = Levels.lineLevels + 1; level <= Levels.count; level++) {
      final puzzle = Levels.generate(level, rng);
      final n = Levels.dots(level);
      expect(puzzle.vertexCount, n);
      expect(puzzle.scatter, isTrue);
      expect(puzzle.crossingCount, greaterThan(0));
      // A trimmed triangulation: denser than a tree, at most 3n - 6 lines.
      expect(puzzle.edges.length, inInclusiveRange(n + n ~/ 2, 3 * n - 6));
      expect(puzzle.neighbors.every((s) => s.length >= 2), isTrue);

      // Not on a circle: some dots well inside the board.
      final inside = puzzle.positions.where(
        (p) => (p - const Offset(0.5, 0.5)).distance < 0.3,
      );
      expect(inside, isNotEmpty);

      for (var v = 0; v < n; v++) {
        puzzle.moveVertex(v, puzzle.solution[v]);
      }
      expect(puzzle.isSolved, isTrue, reason: 'level $level');

      puzzle.scramble(rng);
      expect(puzzle.crossingCount, greaterThan(0));
    }
  });

  test('time limit: estimate first, then recent average minus 10%', () {
    expect(Levels.estimate(1), const Duration(seconds: 20));
    expect(Levels.estimate(11), const Duration(seconds: 190)); // 91 dots
    expect(Levels.limit(11, const []), Levels.estimate(11));
    expect(
      Levels.limit(3, const [Duration(seconds: 40), Duration(seconds: 60)]),
      const Duration(seconds: 45),
    );
  });

  test('store keeps the last five solve times per level', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.load();
    for (var s = 1; s <= 7; s++) {
      store.addSolveTime(4, Duration(seconds: s));
    }
    expect(store.solveTimes(4), [
      for (var s = 3; s <= 7; s++) Duration(seconds: s),
    ]);
    expect(store.solveTimes(5), isEmpty);
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

  /// Level 1 with a seeded puzzle. Returns the same puzzle (same seed and draw
  /// order as the screen) and a mapping from board to screen coordinates.
  Future<({Store store, Puzzle puzzle, Offset Function(Offset) toScreen})>
  pumpSeeded(
    WidgetTester tester, {
    Map<String, Object> saved = const {},
    bool keepHint = false,
  }) async {
    SharedPreferences.setMockInitialValues(saved);
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
    if (!keepHint) {
      // The instructions catch touches on the dots below them.
      await tester.tap(find.text('Tap here to close'));
      await tester.pump();
    }
    final board = tester.getRect(
      find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_BoardPainter',
      ),
    );
    const pad = 13.0 + 6; // dot radius for 6 dots + margin
    return (
      store: store,
      puzzle: Puzzle.generate(4, Random(7)),
      toScreen: (Offset p) =>
          board.topLeft +
          Offset(
            pad + p.dx * (board.width - 2 * pad),
            pad + p.dy * (board.height - 2 * pad),
          ),
    );
  }

  testWidgets('solving plays the animation and unlocks the next level', (
    tester,
  ) async {
    final (:store, :puzzle, :toScreen) = await pumpSeeded(tester);

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

  testWidgets('time limit counts down, then over, and is saved per level', (
    tester,
  ) async {
    // Two earlier solves at 20 s and 30 s: limit 22.5 s -> 0:23.
    final (:store, :puzzle, :toScreen) = await pumpSeeded(
      tester,
      saved: {
        'timerOn': true,
        'times1': ['20000', '30000'],
      },
    );
    expect(find.text('0:23'), findsOneWidget);

    // Switching it off in the level sheet shows plain play time again.
    await tester.tap(find.text('Level 1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Level 1: 0:23'), findsOneWidget);
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(store.timerOn, isFalse);
    expect(find.textContaining('moves · 0:00'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(store.timerOn, isTrue);
    Navigator.of(tester.element(find.text('Choose level'))).pop();
    await tester.pumpAndSettle();

    // Real time doesn't pass in tests, so fake it through a restore: a saved
    // game 30 s in, i.e. 7 s over the limit.
    final saved = jsonDecode(store.game!) as Map<String, dynamic>;
    store.game = jsonEncode({...saved, 'elapsedMs': 30000});
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(store: store, sfx: Sfx(), onToggleTheme: (_) {}),
      ),
    );
    expect(find.textContaining('+0:07'), findsOneWidget);

    for (var v = 0; v < puzzle.vertexCount; v++) {
      final g = await tester.startGesture(toScreen(puzzle.positions[v]));
      await g.moveTo(toScreen(puzzle.solution[v]));
      await g.up();
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Untangled!'), findsOneWidget);
    expect(find.text('Time limit was 0:23'), findsOneWidget);
    // (20 + 30 + 30) / 3 * 0.9 = 24 s
    expect(find.text('Next time limit: 0:24'), findsOneWidget);
    expect(store.solveTimes(1).length, 3);
  });

  testWidgets('tapping the instructions closes them without starting', (
    tester,
  ) async {
    await pumpSeeded(tester, keepHint: true);
    expect(find.text('Lines that cross'), findsOneWidget);
    await tester.tap(find.text('Tap here to close'));
    await tester.pump();
    expect(find.text('Lines that cross'), findsNothing);
    expect(find.textContaining('0 moves · 0:00'), findsOneWidget);

    // Still closed on the next puzzle.
    await tester.tap(find.byTooltip('New puzzle'));
    await tester.pumpAndSettle();
    expect(find.text('Lines that cross'), findsNothing);
  });

  testWidgets('new puzzle asks first once the player has moved a dot', (
    tester,
  ) async {
    final (store: _, :puzzle, :toScreen) = await pumpSeeded(tester);

    final from = toScreen(puzzle.positions[0]);
    final gesture = await tester.startGesture(from);
    await gesture.moveTo(from + const Offset(20, 20));
    await gesture.up();
    await tester.pump();
    expect(find.textContaining('1 moves'), findsOneWidget);

    await tester.tap(find.byTooltip('New puzzle'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 moves'), findsOneWidget);

    await tester.tap(find.byTooltip('New puzzle'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'New puzzle'));
    await tester.pumpAndSettle();
    expect(find.textContaining('0 moves'), findsOneWidget);

    // Untouched board: no question asked.
    await tester.tap(find.byTooltip('New puzzle'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('pinching empty space zooms, fit button zooms back out', (
    tester,
  ) async {
    final (store: _, puzzle: _, :toScreen) = await pumpSeeded(tester);
    // Dots start on a circle, so the centre is empty.
    final centre = toScreen(const Offset(0.5, 0.5));
    final a = await tester.startGesture(centre - const Offset(20, 0));
    final b = await tester.startGesture(centre + const Offset(20, 0));
    await a.moveTo(centre - const Offset(80, 0));
    await b.moveTo(centre + const Offset(80, 0));
    await a.up();
    await b.up();
    await tester.pump();
    expect(find.byIcon(Icons.fit_screen), findsOneWidget);
    expect(find.textContaining('0 moves'), findsOneWidget); // not a move

    await tester.tap(find.byIcon(Icons.fit_screen));
    await tester.pumpAndSettle(); // eases back out
    expect(find.byIcon(Icons.fit_screen), findsNothing);
  });

  List<Offset> savedPositions(Store store) => Puzzle.fromJson(
    (jsonDecode(store.game!) as Map<String, dynamic>)['puzzle']
        as Map<String, dynamic>,
  ).positions;

  testWidgets('a grabbed dot keeps its offset instead of jumping', (
    tester,
  ) async {
    final (:store, :puzzle, :toScreen) = await pumpSeeded(tester);
    final dot = toScreen(puzzle.positions[0]);
    // Grab 8 px off centre and move 40 px towards the middle of the board:
    // the dot moves the same 40 px, without first snapping to the finger.
    final towardsMiddle = toScreen(const Offset(0.5, 0.5)) - dot;
    final step = towardsMiddle / towardsMiddle.distance * 40;
    final grab = dot - const Offset(8, 0);
    final gesture = await tester.startGesture(grab);
    await gesture.moveTo(grab + step);
    await gesture.up();
    await tester.pump();
    final moved = toScreen(savedPositions(store)[0]) - dot;
    expect(moved.dx, closeTo(step.dx, 0.01));
    expect(moved.dy, closeTo(step.dy, 0.01));
  });

  testWidgets('hold and circle dots, then drag them as a group', (
    tester,
  ) async {
    final (:store, :puzzle, :toScreen) = await pumpSeeded(tester);
    // Hold still in an empty corner, then loop around the whole board.
    final lasso = await tester.startGesture(toScreen(const Offset(0, 0)));
    await tester.pump(const Duration(milliseconds: 500));
    for (final c in const [Offset(1, 0), Offset(1, 1), Offset(0, 1)]) {
      await lasso.moveTo(toScreen(c));
    }
    await lasso.up();
    await tester.pump();
    expect(find.text('6 dots selected'), findsOneWidget);

    final before = List.of(puzzle.positions);
    final from = toScreen(before[2]);
    final drag = await tester.startGesture(from);
    await drag.moveTo(from + const Offset(-15, 12));
    await drag.up();
    await tester.pump();
    expect(find.textContaining('1 moves'), findsOneWidget);
    final after = savedPositions(store);
    final shift = after[0] - before[0];
    expect(shift.distance, greaterThan(0));
    for (var v = 0; v < before.length; v++) {
      expect((after[v] - before[v] - shift).distance, lessThan(1e-9));
    }

    // Pushed far right, the group stops with its rightmost dot on the edge.
    final edge = await tester.startGesture(toScreen(after[2]));
    await edge.moveTo(toScreen(after[2]) + const Offset(600, 0));
    await edge.up();
    await tester.pump();
    final pushed = savedPositions(store);
    expect(pushed.map((p) => p.dx).reduce(max), closeTo(1, 1e-9));

    // Moving the group keeps it selected; the next touch elsewhere clears it.
    expect(find.text('6 dots selected'), findsOneWidget);
    final elsewhere = await tester.startGesture(toScreen(const Offset(0, 1)));
    await tester.pump();
    expect(find.text('6 dots selected'), findsNothing);
    await elsewhere.up();
  });

  testWidgets('solving while zoomed in eases out to the whole board', (
    tester,
  ) async {
    final (store: _, :puzzle, :toScreen) = await pumpSeeded(tester);
    // Solve at zoom 1 except the last dot, then zoom in and drop it.
    for (var v = 0; v < puzzle.vertexCount - 1; v++) {
      final g = await tester.startGesture(toScreen(puzzle.positions[v]));
      await g.moveTo(toScreen(puzzle.solution[v]));
      await g.up();
      await tester.pump();
    }
    // Pinch 1.1x around an empty spot from which the last dot's start and
    // target both stay on screen.
    const z = 1.1;
    final last = puzzle.vertexCount - 1;
    final boardRect = Rect.fromPoints(
      toScreen(const Offset(0, 0)),
      toScreen(const Offset(1, 1)),
    );
    late Offset anchor;
    Offset zoomed(Offset p) => anchor + (toScreen(p) - anchor) * z;
    bool usable(Offset q) {
      anchor = q;
      return puzzle.positions.every((p) => (toScreen(p) - q).distance > 45) &&
          boardRect.contains(zoomed(puzzle.positions[last])) &&
          boardRect.contains(zoomed(puzzle.solution[last]));
    }

    final spot = [
      for (var i = 2; i <= 8; i++)
        for (var j = 2; j <= 8; j++) toScreen(Offset(i / 10, j / 10)),
    ].firstWhere(usable);
    anchor = spot;
    final a = await tester.startGesture(spot - const Offset(10, 0));
    final b = await tester.startGesture(spot + const Offset(10, 0));
    await a.moveTo(spot - const Offset(11, 0));
    await b.moveTo(spot + const Offset(11, 0));
    await a.up();
    await b.up();
    await tester.pump();
    expect(find.byIcon(Icons.fit_screen), findsOneWidget);
    final g = await tester.startGesture(zoomed(puzzle.positions[last]));
    await g.moveTo(zoomed(puzzle.solution[last]));
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('Untangled!'), findsOneWidget);
    expect(find.byIcon(Icons.fit_screen), findsNothing);
  });

  testWidgets('full screen hides the bars and comes back', (tester) async {
    await pumpApp(tester, {});
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pump();
    expect(find.text('Level 1'), findsNothing);
    expect(find.byTooltip('New puzzle'), findsNothing);
    expect(find.textContaining('crossings'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fullscreen_exit));
    await tester.pump();
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.byTooltip('New puzzle'), findsOneWidget);
  });

  testWidgets('"hide info" leaves only the exit button in full screen', (
    tester,
  ) async {
    final store = await pumpApp(tester, {'timerOn': true});
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide info in full screen'));
    await tester.pumpAndSettle();
    expect(store.hideInfoFullScreen, isTrue);
    // Outside full screen nothing changes.
    expect(find.textContaining('crossings'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pump();
    expect(find.textContaining('crossings'), findsNothing);
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
  });

  testWidgets('a puzzle in progress survives an app restart', (tester) async {
    final (:store, :puzzle, :toScreen) = await pumpSeeded(tester);
    final from = toScreen(puzzle.positions[0]);
    final gesture = await tester.startGesture(from);
    await gesture.moveTo(from + const Offset(30, 10));
    await gesture.up();
    await tester.pump();
    final crossings = find.textContaining('crossings').evaluate().single;
    final crossingsText = (crossings.widget as Text).data;

    // Simulate the OS killing the app: a fresh screen on the same storage.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          store: store,
          sfx: Sfx(),
          onToggleTheme: (_) {},
          random: Random(99), // a different puzzle if it weren't restored
        ),
      ),
    );
    expect(find.textContaining('1 moves'), findsOneWidget);
    expect(find.text(crossingsText!), findsOneWidget);
    final saved = Puzzle.fromJson(
      (jsonDecode(store.game!) as Map<String, dynamic>)['puzzle']
          as Map<String, dynamic>,
    );
    expect(saved.positions[0], isNot(puzzle.positions[0])); // the moved dot
  });

  test('saved puzzle round-trips through JSON', () {
    final puzzle = Puzzle.generate(6, Random(3));
    final copy = Puzzle.fromJson(
      jsonDecode(jsonEncode(puzzle.toJson())) as Map<String, dynamic>,
    );
    expect(copy.positions, puzzle.positions);
    expect(copy.solution, puzzle.solution);
    expect(copy.edges.length, puzzle.edges.length);
    expect(copy.crossingCount, puzzle.crossingCount);
    expect(copy.scatter, isFalse);

    final mesh = Puzzle.generateMesh(25, Random(3));
    final meshCopy = Puzzle.fromJson(
      jsonDecode(jsonEncode(mesh.toJson())) as Map<String, dynamic>,
    );
    expect(meshCopy.scatter, isTrue);
    expect(meshCopy.crossingCount, mesh.crossingCount);
  });

  testWidgets('settings menu: sound, time limit and theme', (tester) async {
    final store = await pumpApp(tester, {});
    Future<void> pick(String item) async {
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
    }

    await pick('Sound');
    expect(store.muted, isTrue);
    await pick('Time limit');
    expect(store.timerOn, isTrue);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget); // HUD countdown

    final before = Theme.of(tester.element(find.text('Level 1'))).brightness;
    await pick('Dark theme');
    final after = Theme.of(tester.element(find.text('Level 1'))).brightness;
    expect(after, isNot(before));
    expect(store.themeMode, isNot(ThemeMode.system));
  });
}
