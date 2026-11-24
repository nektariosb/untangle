import 'dart:math';
import 'dart:ui';

class Edge {
  final int a;
  final int b;
  const Edge(this.a, this.b);
}

/// A planar graph whose vertices have been scrambled.
///
/// Positions are normalized to the unit square; the board maps them to pixels.
class Puzzle {
  final List<Offset> positions;
  final List<Offset> solution;
  final List<Edge> edges;
  final List<Set<int>> neighbors;

  /// Scrambles scatter the dots over the board instead of placing them on a
  /// circle (mesh levels), which hides the structure better.
  final bool scatter;

  List<bool> crossing = [];
  int crossingCount = 0;

  Puzzle._(
    this.positions,
    this.solution,
    this.edges,
    this.neighbors, {
    this.scatter = false,
  }) {
    recompute();
  }

  int get vertexCount => positions.length;
  bool get isSolved => crossingCount == 0;

  /// Builds a guaranteed-solvable puzzle: draw [lineCount] random lines,
  /// make every pairwise intersection a vertex, and connect consecutive
  /// intersections along each line. The result is planar by construction.
  factory Puzzle.generate(int lineCount, Random rng) {
    final points = <Offset>[];
    final dirs = <Offset>[];
    while (dirs.length < lineCount) {
      final angle = rng.nextDouble() * pi;
      final d = Offset(cos(angle), sin(angle));
      // Near-parallel lines would create intersections far away or not at all.
      if (dirs.any((o) => _cross(o, d).abs() < 0.08)) continue;
      dirs.add(d);
      points.add(Offset(rng.nextDouble(), rng.nextDouble()));
    }

    final vertexOf = <int, int>{};
    final solution = <Offset>[];
    final alongLine = List.generate(lineCount, (_) => <(double, int)>[]);

    for (var i = 0; i < lineCount; i++) {
      for (var j = i + 1; j < lineCount; j++) {
        final denom = _cross(dirs[i], dirs[j]);
        final diff = points[j] - points[i];
        final ti = _cross(diff, dirs[j]) / denom;
        final tj = _cross(diff, dirs[i]) / denom;
        final id = solution.length;
        vertexOf[i * lineCount + j] = id;
        solution.add(points[i] + dirs[i] * ti);
        alongLine[i].add((ti, id));
        alongLine[j].add((tj, id));
      }
    }

    final edges = <Edge>[];
    for (final list in alongLine) {
      list.sort((x, y) => x.$1.compareTo(y.$1));
      for (var k = 0; k + 1 < list.length; k++) {
        edges.add(Edge(list[k].$2, list[k + 1].$2));
      }
    }

    final puzzle = Puzzle._(
      List.of(solution),
      _normalize(solution),
      edges,
      _neighborsOf(solution.length, edges),
    );
    puzzle.scramble(rng);
    return puzzle;
  }

  /// Builds a harder, irregular puzzle: [dotCount] random, well-spaced dots,
  /// joined shortest-first by every line that crosses no earlier one (a
  /// greedy triangulation, planar by construction). About a fifth of the
  /// lines are then removed, never leaving a dot with fewer than two.
  /// Scrambles scatter the dots.
  factory Puzzle.generateMesh(int dotCount, Random rng) {
    final solution = _spreadPoints(dotCount, 0.65, rng);

    final pairs = <(double, int, int)>[
      for (var i = 0; i < dotCount; i++)
        for (var j = i + 1; j < dotCount; j++)
          ((solution[i] - solution[j]).distanceSquared, i, j),
    ]..sort((x, y) => x.$1.compareTo(y.$1));

    final edges = <Edge>[];
    for (final (_, i, j) in pairs) {
      final crosses = edges.any(
        (e) =>
            e.a != i &&
            e.a != j &&
            e.b != i &&
            e.b != j &&
            _segmentsIntersect(
              solution[i],
              solution[j],
              solution[e.a],
              solution[e.b],
            ),
      );
      if (!crosses) edges.add(Edge(i, j));
    }

    final degree = List.filled(dotCount, 0);
    for (final e in edges) {
      degree[e.a]++;
      degree[e.b]++;
    }
    edges.shuffle(rng);
    var toRemove = edges.length ~/ 5;
    edges.removeWhere((e) {
      if (toRemove == 0 || degree[e.a] <= 2 || degree[e.b] <= 2) return false;
      degree[e.a]--;
      degree[e.b]--;
      toRemove--;
      return true;
    });

    final puzzle = Puzzle._(
      List.of(solution),
      solution,
      edges,
      _neighborsOf(dotCount, edges),
      scatter: true,
    );
    puzzle.scramble(rng);
    return puzzle;
  }

  /// [n] random points in the unit square, kept about `spacing / sqrt(n)`
  /// apart so dots don't sit on top of each other. Relaxes the spacing if
  /// the square fills up.
  static List<Offset> _spreadPoints(int n, double spacing, Random rng) {
    var minDist = spacing / sqrt(n);
    final pts = <Offset>[];
    var misses = 0;
    while (pts.length < n) {
      final p = Offset(rng.nextDouble(), rng.nextDouble());
      if (pts.every((q) => (q - p).distance >= minDist)) {
        pts.add(p);
        misses = 0;
      } else if (++misses > 500) {
        minDist *= 0.9;
        misses = 0;
      }
    }
    return pts;
  }

  /// Flat number lists, so a saved game stays small.
  Map<String, Object> toJson() => {
    'positions': [
      for (final p in positions) ...[p.dx, p.dy],
    ],
    'solution': [
      for (final p in solution) ...[p.dx, p.dy],
    ],
    'edges': [
      for (final e in edges) ...[e.a, e.b],
    ],
    'scatter': scatter,
  };

  /// Throws [FormatException] (or a cast error) on malformed data.
  factory Puzzle.fromJson(Map<String, dynamic> json) {
    List<Offset> points(Object? raw) {
      final l = (raw as List).cast<num>();
      return [
        for (var i = 0; i + 1 < l.length; i += 2)
          Offset(l[i].toDouble(), l[i + 1].toDouble()),
      ];
    }

    final positions = points(json['positions']);
    final solution = points(json['solution']);
    final flat = (json['edges'] as List).cast<int>();
    final n = positions.length;
    final edges = [
      for (var i = 0; i + 1 < flat.length; i += 2) Edge(flat[i], flat[i + 1]),
    ];
    if (n == 0 ||
        solution.length != n ||
        edges.any((e) => e.a < 0 || e.b < 0 || e.a >= n || e.b >= n)) {
      throw const FormatException('Bad saved puzzle');
    }
    return Puzzle._(
      positions,
      solution,
      edges,
      _neighborsOf(n, edges),
      scatter: json['scatter'] == true, // absent in older saves
    );
  }

  static List<Set<int>> _neighborsOf(int n, List<Edge> edges) {
    final neighbors = List.generate(n, (_) => <int>{});
    for (final e in edges) {
      neighbors[e.a].add(e.b);
      neighbors[e.b].add(e.a);
    }
    return neighbors;
  }

  /// Places the vertices on a circle in random order, or scatters them over
  /// the board when [scatter] is set (always tangled).
  void scramble(Random rng) {
    if (scatter) {
      do {
        positions.setAll(0, _spreadPoints(vertexCount, 0.5, rng));
        recompute();
      } while (crossingCount == 0);
      return;
    }
    final order = List.generate(vertexCount, (i) => i);
    do {
      order.shuffle(rng);
      final offset = rng.nextDouble() * 2 * pi;
      for (var k = 0; k < order.length; k++) {
        final angle = offset + 2 * pi * k / order.length;
        positions[order[k]] = Offset(
          0.5 + 0.45 * cos(angle),
          0.5 + 0.45 * sin(angle),
        );
      }
      recompute();
    } while (crossingCount == 0);
  }

  void moveVertex(int v, Offset p) => moveVertices({v: p});

  /// Moves several vertices with a single crossing recompute.
  void moveVertices(Map<int, Offset> moves) {
    moves.forEach((v, p) {
      positions[v] = Offset(p.dx.clamp(0.0, 1.0), p.dy.clamp(0.0, 1.0));
    });
    recompute();
  }

  void recompute() {
    crossing = List.filled(edges.length, false);
    var count = 0;
    for (var i = 0; i < edges.length; i++) {
      final e = edges[i];
      for (var j = i + 1; j < edges.length; j++) {
        final f = edges[j];
        if (e.a == f.a || e.a == f.b || e.b == f.a || e.b == f.b) continue;
        if (_segmentsIntersect(
          positions[e.a],
          positions[e.b],
          positions[f.a],
          positions[f.b],
        )) {
          crossing[i] = true;
          crossing[j] = true;
          count++;
        }
      }
    }
    crossingCount = count;
  }

  static double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;

  static double _orient(Offset a, Offset b, Offset c) => _cross(b - a, c - a);

  static bool _onSegment(Offset a, Offset b, Offset p) =>
      p.dx >= min(a.dx, b.dx) - _eps &&
      p.dx <= max(a.dx, b.dx) + _eps &&
      p.dy >= min(a.dy, b.dy) - _eps &&
      p.dy <= max(a.dy, b.dy) + _eps;

  static const _eps = 1e-9;

  static bool _segmentsIntersect(Offset p1, Offset p2, Offset p3, Offset p4) {
    final d1 = _orient(p3, p4, p1);
    final d2 = _orient(p3, p4, p2);
    final d3 = _orient(p1, p2, p3);
    final d4 = _orient(p1, p2, p4);
    if (((d1 > _eps && d2 < -_eps) || (d1 < -_eps && d2 > _eps)) &&
        ((d3 > _eps && d4 < -_eps) || (d3 < -_eps && d4 > _eps))) {
      return true;
    }
    // Touching / collinear overlap counts as a crossing, so a dot can't be
    // parked on top of another line.
    if (d1.abs() <= _eps && _onSegment(p3, p4, p1)) return true;
    if (d2.abs() <= _eps && _onSegment(p3, p4, p2)) return true;
    if (d3.abs() <= _eps && _onSegment(p1, p2, p3)) return true;
    if (d4.abs() <= _eps && _onSegment(p1, p2, p4)) return true;
    return false;
  }

  /// Scales the line-arrangement layout into the unit square (kept for hints
  /// and tests).
  static List<Offset> _normalize(List<Offset> pts) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      minX = min(minX, p.dx);
      minY = min(minY, p.dy);
      maxX = max(maxX, p.dx);
      maxY = max(maxY, p.dy);
    }
    final w = max(maxX - minX, 1e-9), h = max(maxY - minY, 1e-9);
    return [for (final p in pts) Offset((p.dx - minX) / w, (p.dy - minY) / h)];
  }
}
