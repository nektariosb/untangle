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
}
