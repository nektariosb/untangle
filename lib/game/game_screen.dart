import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'levels.dart';
import 'puzzle.dart';
import 'sfx.dart';
import 'store.dart';

class GameScreen extends StatefulWidget {
  final Store store;
  final Sfx sfx;
  final void Function(Brightness current) onToggleTheme;

  /// Seedable for tests, so they can rebuild the same puzzle.
  final Random? random;

  const GameScreen({
    super.key,
    required this.store,
    required this.sfx,
    required this.onToggleTheme,
    this.random,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

/// One spark of the solve burst. Speed is a fraction of the board's short side.
typedef _Spark = ({double angle, double speed, double size});

/// One finger dragging one dot, or a whole selected group. Everything moves by
/// the finger's offset since the grab, so nothing jumps under the finger.
class _Drag {
  /// The dot under the finger (the solve wave starts here).
  final int grabbed;
  final Offset fingerStart; // board coordinates
  final Map<int, Offset> start; // vertex -> board position at the grab
  final Rect allowed; // range of the offset that keeps every dot on the board

  _Drag(this.grabbed, this.fingerStart, this.start)
    : allowed = Rect.fromLTRB(
        -start.values.map((p) => p.dx).reduce(min),
        -start.values.map((p) => p.dy).reduce(min),
        1 - start.values.map((p) => p.dx).reduce(max),
        1 - start.values.map((p) => p.dy).reduce(max),
      );

  Map<int, Offset> targets(Offset finger) {
    final d = finger - fingerStart;
    final c = Offset(
      d.dx.clamp(allowed.left, allowed.right),
      d.dy.clamp(allowed.top, allowed.bottom),
    );
    return start.map((v, p) => MapEntry(v, p + c));
  }
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const _maxLevel = Levels.count;

  late final _rng = widget.random ?? Random();
  final _stopwatch = Stopwatch();

  /// The clock waits until the first dot is grabbed, so looking at (and
  /// zooming into) a new puzzle is free.
  bool _clockStarted = false;

  /// The instructions were tapped away: they stay closed until the app is
  /// restarted, also for new puzzles.
  bool _hintClosed = false;

  /// Play time from before a restore; the stopwatch adds to it.
  Duration _elapsedBefore = Duration.zero;
  Timer? _ticker;
  late final AppLifecycleListener _lifecycle;

  late int _unlocked = widget.store.unlocked.clamp(1, _maxLevel);
  late int _level = widget.store.level.clamp(1, _unlocked);
  late Puzzle _puzzle;
  int _moves = 0;
  bool _solved = false;

  /// Optional time limit, fixed when the puzzle starts (see [Levels.limit]).
  late bool _timerOn = widget.store.timerOn;

  /// Full screen shows only the exit button (no chips, no fit button).
  late bool _hideInfo = widget.store.hideInfoFullScreen;
  Duration _limit = Duration.zero;

  /// Solve animation: a green wave from the last-moved dot, then a burst.
  late final _solveAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..addListener(() => setState(() {}));
  int _solveFrom = 0;
  List<_Spark> _sparks = const [];

  /// Active pointer id -> its drag. Supports several fingers at once.
  final Map<int, _Drag> _drags = {};
  final Set<int> _movedThisDrag = {};

  Set<int> get _dragged => {for (final d in _drags.values) ...d.start.keys};

  /// Dots picked with the lasso; dragging any of them moves them all.
  Set<int> _selected = {};

  /// Holding still on empty board starts a lasso, drawn in screen coordinates.
  static const _holdDelay = Duration(milliseconds: 400);
  static const _touchSlop = 10.0;
  Timer? _holdTimer;
  int? _lassoPointer;
  List<Offset> _lasso = [];
  final Map<int, Offset> _viewStart = {};

  // Board geometry, refreshed on every layout.
  Size _boardSize = Size.zero;
  double _padding = 0;

  /// View transform: screen = base * zoom + pan. Dots keep their pixel size,
  /// so zooming in spreads a dense board out.
  static const _maxZoom = 4.0;
  double _zoom = 1;
  Offset _pan = Offset.zero;

  /// Pointers that started on empty board: one pans, two pinch.
  final Map<int, Offset> _viewPointers = {};

  /// Eases the view back to the whole board (fit button, and on solve).
  late final _viewAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..addListener(_onViewAnim);
  double _animFromZoom = 1;
  Offset _animFromPan = Offset.zero;

  bool _fullScreen = false;

  @override
  void initState() {
    super.initState();
    widget.sfx.muted = widget.store.muted;
    if (!_restoreGame()) _newPuzzle();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_solved && mounted) setState(() {});
    });
    // The OS may kill the app while it's in the background: save on the way
    // out, and don't count time spent away.
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _stopwatch.stop();
        _saveGame();
      },
      onShow: () {
        if (!_solved && _clockStarted) _stopwatch.start();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _ticker?.cancel();
    _holdTimer?.cancel();
    _solveAnim.dispose();
    _viewAnim.dispose();
    if (_fullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _newPuzzle() {
    _puzzle = Levels.generate(_level, _rng);
    _resetProgress();
    _saveGame();
  }

  void _saveGame() {
    if (_solved) return;
    widget.store.game = jsonEncode({
      'level': _level,
      'moves': _moves,
      'elapsedMs': _elapsed.inMilliseconds,
      'puzzle': _puzzle.toJson(),
    });
  }

  /// Picks up the saved puzzle if it belongs to the current level.
  bool _restoreGame() {
    final raw = widget.store.game;
    if (raw == null) return false;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['level'] != _level) return false;
      final puzzle = Puzzle.fromJson(json['puzzle'] as Map<String, dynamic>);
      if (puzzle.vertexCount != Levels.dots(_level) || puzzle.isSolved) {
        return false;
      }
      _puzzle = puzzle;
      _resetProgress();
      _moves = json['moves'] as int;
      _elapsedBefore = Duration(milliseconds: json['elapsedMs'] as int);
      if (_moves > 0 || _elapsedBefore > Duration.zero) _startClock();
      return true;
    } catch (_) {
      return false; // corrupt or from an older version: start fresh
    }
  }

  void _resetProgress() {
    _elapsedBefore = Duration.zero;
    _viewAnim.stop();
    _zoom = 1;
    _pan = Offset.zero;
    _selected = {};
    _endLasso();
    _drags.clear();
    _movedThisDrag.clear();
    _moves = 0;
    _solved = false;
    _limit = Levels.limit(_level, widget.store.solveTimes(_level));
    _solveAnim.reset();
    _stopwatch
      ..stop()
      ..reset();
    _clockStarted = false;
  }

  void _startClock() {
    _clockStarted = true;
    _stopwatch.start();
  }

  void _goToLevel(int level) {
    setState(() {
      _level = level.clamp(1, _unlocked);
      _newPuzzle();
    });
    widget.store.level = _level;
  }

  double get _dotRadius {
    final n = _puzzle.vertexCount;
    return n <= 15 ? 13 : (n <= 36 ? 11 : 9);
  }

  Offset _toScreen(Offset p) =>
      Offset(
            _padding + p.dx * (_boardSize.width - 2 * _padding),
            _padding + p.dy * (_boardSize.height - 2 * _padding),
          ) *
          _zoom +
      _pan;

  Offset _toBoard(Offset s) {
    final u = (s - _pan) / _zoom;
    return Offset(
      (u.dx - _padding) / (_boardSize.width - 2 * _padding),
      (u.dy - _padding) / (_boardSize.height - 2 * _padding),
    );
  }

  /// Keeps the zoomed board covering the whole viewport.
  Offset _clampPan(Offset pan, double zoom) => Offset(
    pan.dx.clamp(_boardSize.width * (1 - zoom), 0.0),
    pan.dy.clamp(_boardSize.height * (1 - zoom), 0.0),
  );

  void _moveView(int pointer, Offset to) {
    final from = _viewPointers[pointer]!;
    _viewPointers[pointer] = to;
    if (pointer == _lassoPointer) {
      if ((to - _lasso.last).distance > 3) setState(() => _lasso.add(to));
      return;
    }
    if ((to - _viewStart[pointer]!).distance > _touchSlop) _holdTimer?.cancel();
    // Leave the view alone while a dot is dragged or a lasso is drawn.
    if (_drags.isNotEmpty || _lassoPointer != null) return;
    _viewAnim.stop();
    final other = _viewPointers.entries
        .where((e) => e.key != pointer)
        .firstOrNull
        ?.value;
    var zoom = _zoom;
    var pan = _pan;
    if (other == null) {
      if (_zoom == 1) return;
      pan += to - from;
    } else {
      final oldDist = (from - other).distance;
      if (oldDist < 1) return;
      zoom = (_zoom * (to - other).distance / oldDist).clamp(1.0, _maxZoom);
      // Keep the board point under the fingers' midpoint under it.
      final anchor = ((from + other) / 2 - pan) / _zoom;
      pan = (to + other) / 2 - anchor * zoom;
    }
    setState(() {
      _zoom = zoom;
      _pan = _clampPan(pan, zoom);
    });
  }

  void _resetView() {
    if (_zoom == 1) return;
    _animFromZoom = _zoom;
    _animFromPan = _pan;
    _viewAnim.forward(from: 0);
  }

  void _onViewAnim() {
    final t = Curves.easeInOutCubic.transform(_viewAnim.value);
    setState(() {
      _zoom = 1 + (_animFromZoom - 1) * (1 - t);
      _pan = _animFromPan * (1 - t);
    });
  }

  void _startLasso(int pointer) {
    if (!_viewPointers.containsKey(pointer) || _viewPointers.length > 1) return;
    if (_drags.isNotEmpty || _solved) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _lassoPointer = pointer;
      _lasso = [_viewPointers[pointer]!];
    });
  }

  /// Selects the dots inside the drawn loop.
  void _finishLasso() {
    final path = Path()..addPolygon(_lasso, true);
    final picked = _lasso.length < 3
        ? <int>{}
        : {
            for (var v = 0; v < _puzzle.vertexCount; v++)
              if (path.contains(_toScreen(_puzzle.positions[v]))) v,
          };
    setState(() {
      _selected = picked;
      _endLasso();
    });
    if (picked.isNotEmpty) HapticFeedback.selectionClick();
  }

  void _endLasso() {
    _holdTimer?.cancel();
    _lassoPointer = null;
    _lasso = [];
  }

  void _setFullScreen(bool on) {
    setState(() => _fullScreen = on);
    SystemChrome.setEnabledSystemUIMode(
      on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  int? _hitTest(Offset local) {
    final touchRadius = max(_dotRadius * 2.2, 26.0);
    final dragged = _dragged;
    int? best;
    var bestDist = touchRadius;
    for (var v = 0; v < _puzzle.vertexCount; v++) {
      if (dragged.contains(v)) continue;
      final d = (_toScreen(_puzzle.positions[v]) - local).distance;
      if (d < bestDist) {
        bestDist = d;
        best = v;
      }
    }
    return best;
  }

  void _onPointerDown(PointerDownEvent e) {
    final v = _solved ? null : _hitTest(e.localPosition);
    // Any touch that isn't on the selection ends it.
    if (_selected.isNotEmpty && !_selected.contains(v)) {
      setState(() => _selected = {});
    }
    if (v == null) {
      _viewPointers[e.pointer] = e.localPosition;
      _viewStart[e.pointer] = e.localPosition;
      _holdTimer?.cancel();
      if (_viewPointers.length == 1 && _lassoPointer == null) {
        final id = e.pointer;
        _holdTimer = Timer(_holdDelay, () => _startLasso(id));
      }
      return;
    }
    _holdTimer?.cancel(); // a dot was grabbed: no lasso now
    if (!_clockStarted) _startClock();
    final group = _selected.contains(v) ? _selected : {v};
    setState(() {
      _viewAnim.stop();
      _drags[e.pointer] = _Drag(v, _toBoard(e.localPosition), {
        for (final u in group) u: _puzzle.positions[u],
      });
    });
    HapticFeedback.selectionClick();
    widget.sfx.grab();
  }

  void _toggleMute() {
    setState(() => widget.sfx.muted = !widget.sfx.muted);
    widget.store.muted = widget.sfx.muted;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_viewPointers.containsKey(e.pointer)) {
      _moveView(e.pointer, e.localPosition);
      return;
    }
    final drag = _drags[e.pointer];
    if (drag == null) return;
    setState(() {
      _puzzle.moveVertices(drag.targets(_toBoard(e.localPosition)));
      _movedThisDrag.add(e.pointer);
    });
  }

  void _onPointerEnd(PointerEvent e) {
    _viewStart.remove(e.pointer);
    if (_viewPointers.remove(e.pointer) != null) {
      if (e.pointer == _lassoPointer) return _finishLasso();
      _holdTimer?.cancel();
      return;
    }
    final drag = _drags[e.pointer];
    if (drag == null) return;
    final v = drag.grabbed;
    setState(() {
      _drags.remove(e.pointer);
      final moved = _movedThisDrag.remove(e.pointer);
      if (moved) _moves++;
      // Only declare victory once every finger is lifted.
      if (_drags.isEmpty && _puzzle.isSolved) {
        _solved = true;
        _stopwatch.stop();
        HapticFeedback.heavyImpact();
        widget.sfx.solve();
        _solveFrom = v;
        _sparks = [
          for (var i = 0; i < 28; i++)
            (
              angle: 2 * pi * (i + _rng.nextDouble() * 0.8) / 28,
              speed: 0.08 + _rng.nextDouble() * 0.14,
              size: 1.5 + _rng.nextDouble() * 2,
            ),
        ];
        _solveAnim.forward(from: 0);
        _selected = {};
        _resetView(); // show the whole untangled board
        widget.store.game = null;
        widget.store.addSolveTime(_level, _elapsed);
        if (_level == _unlocked && _level < _maxLevel) {
          widget.store.unlocked = ++_unlocked;
        }
      } else if (moved) {
        _saveGame();
      }
    });
  }

  Duration get _elapsed => _elapsedBefore + _stopwatch.elapsed;

  String get _timeText => _clock(_elapsed);

  static String _clock(Duration d) {
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  bool get _overTime => _timerOn && _elapsed > _limit;

  /// With the limit on: time left counting down, then the time over it
  /// ("+0:12"). Shown next to a timer icon.
  String get _countdownText {
    if (_overTime) return '+${_clock(_elapsed - _limit)}';
    // Round up, so it shows 0:01 until the limit is actually reached.
    return _clock(_limit - _elapsed + const Duration(milliseconds: 999));
  }

  /// Timer icon + countdown, terracotta once over the limit.
  Widget _buildCountdown(BuildContext context, TextStyle? style) {
    final color = _overTime
        ? BoardColors.of(context).crossingEdge
        : style?.color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer_outlined,
          size: (style?.fontSize ?? 14) * 1.25,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          _countdownText,
          maxLines: 1,
          style: style?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _setTimerOn(bool on) {
    setState(() => _timerOn = on);
    widget.store.timerOn = on;
  }

  void _setHideInfo(bool on) {
    setState(() => _hideInfo = on);
    widget.store.hideInfoFullScreen = on;
  }

  @override
  Widget build(BuildContext context) {
    final colors = BoardColors.of(context);
    return PopScope(
      // Back leaves full screen first.
      canPop: !_fullScreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setFullScreen(false);
      },
      child: Scaffold(
        body: SafeArea(
          // Huge system text would squeeze the board away; the bars stay
          // readable at 1.3x. Dialogs and the level sheet still scale fully.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Column(
              children: [
                if (!_fullScreen) _buildHud(context),
                Expanded(
                  child: Padding(
                    padding: _fullScreen
                        ? const EdgeInsets.all(4)
                        : const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        color: colors.board,
                        child: _buildBoard(context, colors),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoard(BuildContext context, BoardColors colors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _boardSize = constraints.biggest;
        _padding = _dotRadius + 6;
        _pan = _clampPan(_pan, _zoom); // after a resize
        final clean = _fullScreen && _hideInfo;
        return Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerEnd,
              onPointerCancel: _onPointerEnd,
              child: CustomPaint(
                painter: _BoardPainter(
                  puzzle: _puzzle,
                  toScreen: _toScreen,
                  dotRadius: _dotRadius,
                  dragged: _dragged,
                  selected: _selected,
                  lasso: _lasso,
                  solveT: _solved ? _solveAnim.value : null,
                  solveFrom: _solveFrom,
                  sparks: _sparks,
                  colors: colors,
                ),
              ),
            ),
            if (_moves == 0 &&
                _drags.isEmpty &&
                !_solved &&
                !_fullScreen &&
                !_hintClosed)
              _buildHint(context, colors),
            // Crossings in the board's corner (the HUD has no room for it).
            // The chips let touches through to dots underneath.
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  if (_fullScreen && _timerOn && !_solved && !clean) ...[
                    IgnorePointer(child: _buildTimerChip(context)),
                    const SizedBox(width: 4),
                  ],
                  if (!clean) IgnorePointer(child: _buildCrossingsChip()),
                  if (_fullScreen) ...[
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      tooltip: 'Exit full screen',
                      icon: const Icon(Icons.fullscreen_exit),
                      onPressed: () => _setFullScreen(false),
                    ),
                  ],
                ],
              ),
            ),
            if (_selected.isNotEmpty && !_solved && !clean)
              Positioned(
                top: 8,
                left: 8,
                child: InputChip(
                  label: Text('${_selected.length} dots selected'),
                  onDeleted: () => setState(() => _selected = {}),
                  deleteButtonTooltipMessage: 'Clear selection',
                ),
              ),
            if (_zoom > 1 && !clean)
              Positioned(
                right: 8,
                bottom: 8,
                child: IconButton.filledTonal(
                  tooltip: 'Fit board',
                  icon: const Icon(Icons.fit_screen),
                  onPressed: _resetView,
                ),
              ),
            if (_solved && _solveAnim.value >= 0.7)
              _buildSolvedOverlay(context),
          ],
        );
      },
    );
  }

  Widget _buildCrossingsChip() {
    final crossings = _puzzle.crossingCount;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: crossings == 0
            ? const Color(0xFF5B6E1C)
            : const Color(0xFFB5523A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        crossings == 0 ? 'No crossings' : '$crossings crossings',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// The countdown in full screen, where the HUD is hidden.
  Widget _buildTimerChip(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _buildCountdown(
        context,
        TextStyle(color: theme.colorScheme.onSurface),
      ),
    );
  }

  Widget _buildHud(BuildContext context) {
    final theme = Theme.of(context);
    // Narrow phones: slightly smaller icon buttons so the level stays readable.
    final density = MediaQuery.sizeOf(context).width < 380
        ? VisualDensity.compact
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _showLevelPicker,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Level $_level',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                    Builder(
                      builder: (context) {
                        final style = theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        );
                        final info = Text(
                          // Dot counts are in the level sheet.
                          _timerOn
                              ? '$_moves moves'
                              : '$_moves moves · $_timeText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style,
                        );
                        if (!_timerOn) return info;
                        // Countdown first, so it's never the part cut off.
                        return Row(
                          children: [
                            _buildCountdown(
                              context,
                              theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(child: info),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton.filledTonal(
            visualDensity: density,
            tooltip: 'New puzzle',
            icon: const Icon(Icons.casino_outlined),
            onPressed: () =>
                _confirmThen('New puzzle', () => setState(_newPuzzle)),
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: density,
            tooltip: 'Full screen',
            icon: const Icon(Icons.fullscreen),
            onPressed: () => _setFullScreen(true),
          ),
          _buildSettingsMenu(context, density),
        ],
      ),
    );
  }

  /// Theme, sound and time limit, behind one ⚙ button.
  Widget _buildSettingsMenu(BuildContext context, VisualDensity? density) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String>(
      tooltip: 'Settings',
      icon: const Icon(Icons.settings_outlined),
      style: IconButton.styleFrom(visualDensity: density),
      onSelected: (item) => switch (item) {
        'theme' => widget.onToggleTheme(Theme.of(context).brightness),
        'sound' => _toggleMute(),
        'timer' => _setTimerOn(!_timerOn),
        _ => _setHideInfo(!_hideInfo),
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: 'theme',
          checked: dark,
          child: const Text('Dark theme'),
        ),
        CheckedPopupMenuItem(
          value: 'sound',
          checked: !widget.sfx.muted,
          child: const Text('Sound'),
        ),
        CheckedPopupMenuItem(
          value: 'timer',
          checked: _timerOn,
          child: const Text('Time limit'),
        ),
        CheckedPopupMenuItem(
          value: 'clean',
          checked: _hideInfo,
          child: const Text('Hide info in full screen'),
        ),
      ],
    );
  }

  /// Explains the goal until the first move is made, or until tapped. A tap
  /// closes it without starting the clock, so the whole board can be studied.
  Widget _buildHint(BuildContext context, BoardColors colors) {
    final theme = Theme.of(context);
    // Below the crossings chip in the corner. Wraps to the board's width,
    // and shrinks to fit a short board (phone landscape).
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 52, 12, 12),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topCenter,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: _hintCard(theme, colors),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hintCard(ThemeData theme, BoardColors colors) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _hintClosed = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hintRow(
              theme,
              _lineSwatch(colors.crossingEdge),
              'Lines that cross',
            ),
            _hintRow(theme, _lineSwatch(colors.edge), 'Lines that don’t cross'),
            _hintRow(
              theme,
              const Icon(Icons.touch_app_outlined, size: 18),
              'Drag the dots until no crossing lines are left',
            ),
            _hintRow(
              theme,
              const Icon(Icons.gesture, size: 18),
              'Hold empty space, then circle dots to move them together',
            ),
            if (_puzzle.vertexCount > 28)
              _hintRow(
                theme,
                const Icon(Icons.pinch_outlined, size: 18),
                'Pinch empty space to zoom',
              ),
            _hintRow(
              theme,
              const Icon(Icons.close, size: 18),
              'Tap here to close',
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineSwatch(Color color) => Container(
    width: 22,
    height: 4,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _hintRow(ThemeData theme, Widget lead, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 22, child: Center(child: lead)),
        const SizedBox(width: 10),
        Flexible(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
    ),
  );

  /// Runs [action] right away on an untouched or solved board; otherwise asks
  /// first, so a stray tap near the board edge can't wipe the player's work.
  Future<void> _confirmThen(String verb, VoidCallback action) async {
    if (_moves == 0 || _solved) {
      action();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$verb?'),
        content: const Text('Your progress on this puzzle will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(verb),
          ),
        ],
      ),
    );
    if (ok == true && mounted) action();
  }

  void _showLevelPicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      builder: (context) {
        final theme = Theme.of(context);
        Widget levelChips(int from, int to) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var l = from; l <= to; l++)
              ChoiceChip(
                selected: l == _level,
                avatar: l > _unlocked
                    ? const Icon(Icons.lock_outline, size: 16)
                    : null,
                label: Text('$l  ·  ${Levels.dots(l)} dots'),
                onSelected: l > _unlocked
                    ? null
                    : (_) {
                        Navigator.pop(context);
                        _goToLevel(l);
                      },
              ),
          ],
        );
        final sectionStyle = theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // At the top, so it's seen without scrolling. The sheet
                // doesn't rebuild with the screen, so the switch keeps its
                // own state.
                StatefulBuilder(
                  builder: (context, setSheetState) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.timer_outlined),
                    title: const Text('Time limit'),
                    subtitle: Text(
                      'Level $_level: ${_clock(_limit)}. '
                      'It gets shorter as you get faster.',
                    ),
                    value: _timerOn,
                    onChanged: (on) {
                      _setTimerOn(on);
                      setSheetState(() {});
                    },
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),
                Text('Choose level', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Text('Lines', style: sectionStyle),
                const SizedBox(height: 8),
                levelChips(1, Levels.lineLevels),
                const SizedBox(height: 16),
                Text('Mesh · harder, scattered start', style: sectionStyle),
                const SizedBox(height: 8),
                levelChips(Levels.lineLevels + 1, _maxLevel),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSolvedOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final isLastLevel = _level >= _maxLevel;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(20),
          // Shrinks to fit a short board (phone landscape, large text).
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Card(
              elevation: 6,
              color: theme.colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Untangled!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: BoardColors.of(context).solved,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_moves moves in $_timeText',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (_timerOn) ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final color = _overTime
                              ? BoardColors.of(context).crossingEdge
                              : BoardColors.of(context).solved;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _overTime
                                    ? Icons.timer_off_outlined
                                    : Icons.check_circle_outline,
                                size: 18,
                                color: color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _overTime
                                    ? 'Time limit was ${_clock(_limit)}'
                                    : 'You beat the time limit '
                                          '(${_clock(_limit)})',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Next time limit: ${_clock(Levels.limit(_level, widget.store.solveTimes(_level)))}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _goToLevel(_level),
                          icon: const Icon(Icons.replay),
                          label: const Text('Same level'),
                        ),
                        if (!isLastLevel)
                          FilledButton.icon(
                            onPressed: () => _goToLevel(_level + 1),
                            icon: const Icon(Icons.arrow_forward),
                            label: Text('Level ${_level + 1}'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Board palette for the current theme brightness.
class BoardColors {
  final Color board;
  final Color edge;
  final Color crossingEdge;
  final Color solved;
  final Color dot;
  final Color dragged;
  final Color connected;

  const BoardColors({
    required this.board,
    required this.edge,
    required this.crossingEdge,
    required this.solved,
    required this.dot,
    required this.dragged,
    required this.connected,
  });

  static const dark = BoardColors(
    board: Color(0xFF1C2114),
    edge: Color(0xFF6F7B4E),
    crossingEdge: Color(0xFFD9774B),
    solved: Color(0xFFB5D96A),
    dot: Color(0xFFE6DDB8),
    dragged: Colors.white,
    connected: Color(0xFFC8E25A),
  );

  static const light = BoardColors(
    board: Color(0xFFFAFBF3),
    edge: Color(0xFFA3AA86),
    crossingEdge: Color(0xFFC0533A),
    solved: Color(0xFF5E8A1E),
    dot: Color(0xFF55611F),
    dragged: Color(0xFF1F2314),
    connected: Color(0xFF9DC02E),
  );

  static BoardColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class _BoardPainter extends CustomPainter {
  final Puzzle puzzle;
  final Offset Function(Offset) toScreen;
  final double dotRadius;
  final Set<int> dragged;
  final Set<int> selected;

  /// Loop being drawn, in screen coordinates (empty when none).
  final List<Offset> lasso;

  /// Solve animation progress 0..1, or null while unsolved.
  final double? solveT;
  final int solveFrom;
  final List<_Spark> sparks;
  final BoardColors colors;

  _BoardPainter({
    required this.puzzle,
    required this.toScreen,
    required this.dotRadius,
    required this.dragged,
    required this.selected,
    required this.lasso,
    required this.solveT,
    required this.solveFrom,
    required this.sparks,
    required this.colors,
  });

  static const _waveBand = 60.0;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [for (final p in puzzle.positions) toScreen(p)];
    final connected = <int>{for (final v in dragged) ...puzzle.neighbors[v]}
      ..removeAll(dragged);

    // How far the solve wave has reached into a point at distance d: 0..1.
    final t = solveT;
    final origin = pts[solveFrom.clamp(0, pts.length - 1)];
    var waveRadius = 0.0;
    if (t != null) {
      final reach = pts.fold(0.0, (m, p) => max(m, (p - origin).distance));
      final w = Curves.easeInOutSine.transform((t / 0.55).clamp(0.0, 1.0));
      waveRadius = w * (reach + _waveBand);
    }
    double waved(Offset p) =>
        ((waveRadius - (p - origin).distance) / _waveBand).clamp(0.0, 1.0);

    final edgePaint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < puzzle.edges.length; i++) {
      final e = puzzle.edges[i];
      final touchesDragged = dragged.contains(e.a) || dragged.contains(e.b);
      edgePaint
        ..color = t != null
            ? Color.lerp(
                colors.edge,
                colors.solved,
                waved((pts[e.a] + pts[e.b]) / 2),
              )!
            : puzzle.crossing[i]
            ? colors.crossingEdge
            : touchesDragged
            ? colors.connected
            : colors.edge
        ..strokeWidth = touchesDragged ? 4 : 2.5;
      canvas.drawLine(pts[e.a], pts[e.b], edgePaint);
    }

    if (lasso.length > 1) {
      final path = Path()..addPolygon(lasso, false);
      canvas.drawPath(
        Path()..addPolygon(lasso, true),
        Paint()..color = colors.dragged.withValues(alpha: 0.08),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = colors.dragged.withValues(alpha: 0.6),
      );
    }
    final selectRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = colors.dragged.withValues(alpha: 0.55);

    final fill = Paint();
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = colors.board;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final glow = Paint()
      ..color = colors.dragged.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    for (var v = 0; v < pts.length; v++) {
      final isDragged = dragged.contains(v);
      final isConnected = connected.contains(v);
      final k = t != null ? waved(pts[v]) : 0.0;
      final r =
          (isDragged
              ? dotRadius * 1.35
              : isConnected
              ? dotRadius * 1.15
              : dotRadius) *
          (1 + 0.3 * sin(pi * k));
      if (isDragged) canvas.drawCircle(pts[v], r + 6, glow);
      fill.color = t != null
          ? Color.lerp(colors.dot, colors.solved, k)!
          : isDragged
          ? colors.dragged
          : isConnected
          ? colors.connected
          : colors.dot;
      canvas.drawCircle(pts[v], r, fill);
      canvas.drawCircle(pts[v], r, outline);
      if (isConnected && t == null) {
        ring.color = colors.connected.withValues(alpha: 0.45);
        canvas.drawCircle(pts[v], r + 4, ring);
      } else if (selected.contains(v) && !isDragged && t == null) {
        canvas.drawCircle(pts[v], r + 4, selectRing);
      }
    }

    // Soft burst from the last-moved dot once the wave is under way.
    final p = t == null ? 0.0 : ((t - 0.35) / 0.65).clamp(0.0, 1.0);
    if (p > 0 && p < 1) {
      final spread = Curves.easeOutCubic.transform(p) * size.shortestSide;
      final spark = Paint()
        ..color = colors.solved.withValues(alpha: 0.75 * pow(1 - p, 1.5))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      for (final s in sparks) {
        final dir = Offset(cos(s.angle), sin(s.angle));
        canvas.drawCircle(origin + dir * s.speed * spread, s.size, spark);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
