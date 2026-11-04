import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untangle/game/game_screen.dart';
import 'package:untangle/game/puzzle.dart';
import 'package:untangle/game/sfx.dart';
import 'package:untangle/game/store.dart';

/// Every screen of the game at phone, landscape, tablet and desktop-web sizes,
/// with normal and large system fonts. Any overflow (the yellow/black stripes)
/// is reported by Flutter as an error and fails the test.
void main() {
  const sizes = {
    'small phone': Size(320, 568),
    'phone': Size(360, 740),
    'tall phone': Size(412, 915),
    'small phone landscape': Size(568, 320),
    'phone landscape': Size(915, 412),
    'tablet': Size(800, 1280),
    'tablet landscape': Size(1280, 800),
    'desktop web': Size(1920, 1080),
  };
  const textScales = [1.0, 1.3, 2.0];

  // The test font draws every glyph as a 1em square, about twice as wide as
  // real text. Load Roboto (shipped with the Flutter SDK) for real widths.
  setUpAll(() async {
    final root =
        Platform.environment['FLUTTER_ROOT'] ??
        File(Platform.resolvedExecutable)
            .parent
            .parent
            .parent
            .parent
            .parent
            .parent
            .parent
            .path; // bin/cache/artifacts/engine/<platform>/
    final fonts = '$root/bin/cache/artifacts/material_fonts';
    final loader = FontLoader('Roboto');
    for (final w in ['regular', 'medium', 'bold']) {
      final bytes = File('$fonts/roboto-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('$fonts/materialicons-regular.otf').readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
  });

  void setScreen(WidgetTester tester, Size size, double textScale) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    // Status bar and gesture bar, as on a phone with a notch.
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<Puzzle> pumpGame(
    WidgetTester tester, {
    required int level,
    required int seed,
  }) async {
    SharedPreferences.setMockInitialValues({'level': level, 'unlocked': level});
    final store = await Store.load();
    await tester.pumpWidget(const SizedBox()); // a fresh screen state
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          store: store,
          sfx: Sfx(),
          onToggleTheme: (_) {},
          random: Random(seed),
        ),
      ),
    );
    return Puzzle.generate(level + 3, Random(seed));
  }

  Offset Function(Offset) boardMapping(WidgetTester tester, double pad) {
    final board = tester.getRect(
      find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_BoardPainter',
      ),
    );
    return (p) =>
        board.topLeft +
        Offset(
          pad + p.dx * (board.width - 2 * pad),
          pad + p.dy * (board.height - 2 * pad),
        );
  }

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    for (final scale in textScales) {
      testWidgets('$name ${size.width.toInt()}x${size.height.toInt()}, '
          'text x$scale', (tester) async {
        setScreen(tester, size, scale);

        // Biggest level: thousands of crossings, longest chip text, and the
        // two-line hint.
        final big = await pumpGame(tester, level: 11, seed: 3);
        expect(find.text('Level 11'), findsOneWidget);
        final toScreen = boardMapping(tester, 9 + 6);
        final boardHeight =
            (toScreen(const Offset(0, 1)) - toScreen(Offset.zero)).dy;
        expect(
          boardHeight,
          greaterThan(size.height * 0.4),
          reason: 'bars leave too little board',
        );

        // Level picker sheet.
        await tester.tap(find.text('Level 11'));
        await tester.pumpAndSettle();
        expect(find.text('Choose level'), findsOneWidget);
        await tester.tapAt(const Offset(4, 30)); // scrim
        await tester.pumpAndSettle();

        // A move, then the confirm dialog.
        final from = toScreen(big.positions[0]);
        final g = await tester.startGesture(from);
        await g.moveTo(from + const Offset(10, 10));
        await g.up();
        await tester.pump();
        await tester.tap(find.byIcon(Icons.casino_outlined));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Keep playing'));
        await tester.pumpAndSettle();

        // Full screen with a lasso selection chip and the fit button.
        await tester.tap(find.byIcon(Icons.fullscreen));
        await tester.pump();
        final full = boardMapping(tester, 9 + 6);
        final lasso = await tester.startGesture(full(const Offset(0, 1)));
        await tester.pump(const Duration(milliseconds: 500));
        for (final c in const [Offset(0, 0), Offset(1, 0), Offset(1, 1)]) {
          await lasso.moveTo(full(c));
        }
        await lasso.up();
        await tester.pump();
        expect(find.textContaining('dots selected'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.fullscreen_exit));
        await tester.pump();

        // Solved card on level 1.
        final small = await pumpGame(tester, level: 1, seed: 7);
        final map = boardMapping(tester, 13 + 6);
        for (var v = 0; v < small.vertexCount; v++) {
          final g = await tester.startGesture(map(small.positions[v]));
          await g.moveTo(map(small.solution[v]));
          await g.up();
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.text('Untangled!'), findsOneWidget);
      });
    }
  }
}
