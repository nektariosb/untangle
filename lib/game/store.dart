import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saved settings and progress. Writes are fire-and-forget.
class Store {
  final SharedPreferences _prefs;

  Store(this._prefs);

  static Future<Store> load() async =>
      Store(await SharedPreferences.getInstance());

  ThemeMode get themeMode =>
      ThemeMode.values.asNameMap()[_prefs.getString('themeMode')] ??
      ThemeMode.system;
  set themeMode(ThemeMode mode) => _prefs.setString('themeMode', mode.name);

  int get level => _prefs.getInt('level') ?? 1;
  set level(int level) => _prefs.setInt('level', level);

  /// Highest level the player may pick. Beating level L unlocks L + 1.
  int get unlocked => _prefs.getInt('unlocked') ?? 1;
  set unlocked(int level) => _prefs.setInt('unlocked', level);

  bool get muted => _prefs.getBool('muted') ?? false;
  set muted(bool muted) => _prefs.setBool('muted', muted);

  /// Optional time limit per puzzle (off by default).
  bool get timerOn => _prefs.getBool('timerOn') ?? false;
  set timerOn(bool on) => _prefs.setBool('timerOn', on);

  /// Full screen shows only its exit button.
  bool get hideInfoFullScreen => _prefs.getBool('hideInfoFullScreen') ?? false;
  set hideInfoFullScreen(bool on) => _prefs.setBool('hideInfoFullScreen', on);

  static const recentSolves = 5;

  /// The last few solve times on [level], oldest first. Recorded whether the
  /// timer is on or not, so the limit is ready when it's switched on.
  List<Duration> solveTimes(int level) => [
    for (final ms in _prefs.getStringList('times$level') ?? const <String>[])
      if (int.tryParse(ms) case final ms?) Duration(milliseconds: ms),
  ];

  void addSolveTime(int level, Duration time) {
    final times = [...solveTimes(level), time];
    _prefs.setStringList('times$level', [
      for (final t in times.skip(max(0, times.length - recentSolves)))
        '${t.inMilliseconds}',
    ]);
  }

  /// The puzzle in progress as JSON, so it survives the app being killed in
  /// the background. Null when there is none (e.g. just solved).
  String? get game => _prefs.getString('game');
  set game(String? json) =>
      json == null ? _prefs.remove('game') : _prefs.setString('game', json);
}
