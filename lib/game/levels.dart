import 'dart:math';

import 'puzzle.dart';

/// What each level is made of.
///
/// Levels 1–11 are line puzzles (L + 3 lines) that start on a circle.
/// Levels 12–20 are mesh puzzles (random triangulated dots) that start
/// scattered: no regular pattern to spot, so much harder per dot.
abstract final class Levels {
  static const lineLevels = 11;
  static const count = 20;

  static bool isMesh(int level) => level > lineLevels;

  static int _linesFor(int level) => level + 3;

  /// Mesh dot counts for levels 12..20.
  static const _meshDots = [25, 30, 36, 42, 49, 56, 64, 72, 81];

  static int dots(int level) {
    if (isMesh(level)) return _meshDots[level - lineLevels - 1];
    final n = _linesFor(level);
    return n * (n - 1) ~/ 2;
  }

  static Puzzle generate(int level, Random rng) => isMesh(level)
      ? Puzzle.generateMesh(dots(level), rng)
      : Puzzle.generate(_linesFor(level), rng);

  /// First-time time limit, before the player has any solve times here.
  static Duration estimate(int level) {
    final seconds = dots(level) * (isMesh(level) ? 5 : 2);
    return Duration(seconds: max(20, (seconds / 10).ceil() * 10));
  }

  /// The time limit: the average of the recent solve times minus 10%, so it
  /// tightens as the player gets faster. [estimate] until there are any.
  static Duration limit(int level, List<Duration> recent) {
    if (recent.isEmpty) return estimate(level);
    final avgMs =
        recent.fold(0, (sum, d) => sum + d.inMilliseconds) / recent.length;
    return Duration(seconds: max(5, (avgMs * 0.9 / 1000).round()));
  }
}
