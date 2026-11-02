import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Subtle sound effects. Silent until [init] succeeds (e.g. in tests).
class Sfx {
  AudioPool? _grab;
  AudioPool? _solve;
  bool muted = false;

  /// Game sounds: mix with the user's music, respect the silent switch.
  static final _context = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(_context);
      _grab = await AudioPool.create(
        source: AssetSource('sounds/grab.wav'),
        maxPlayers: 4,
        audioContext: _context,
        playerMode: PlayerMode.lowLatency,
      );
      _solve = await AudioPool.create(
        source: AssetSource('sounds/solve.wav'),
        maxPlayers: 1,
        audioContext: _context,
      );
    } catch (e) {
      debugPrint('Sound disabled: $e');
    }
  }

  void grab() => _play(_grab, 0.5, const Duration(milliseconds: 150));

  void solve() => _play(_solve, 0.6, const Duration(seconds: 2));

  /// Low-latency players never report completion, so each clip is stopped
  /// after [length] to hand its player back to the pool.
  Future<void> _play(AudioPool? pool, double volume, Duration length) async {
    if (muted || pool == null) return;
    try {
      final stop = await pool.start(volume: volume);
      await Future<void>.delayed(length);
      await stop();
    } catch (e) {
      debugPrint('Sound failed: $e');
    }
  }
}
