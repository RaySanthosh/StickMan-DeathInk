import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import 'save_service.dart';

/// Thin wrapper over flame_audio that respects the sound setting and never
/// lets audio failures crash the game.
class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  static const _files = [
    'jump.wav',
    'death.wav',
    'checkpoint.wav',
    'win.wav',
    'click.wav',
  ];

  Future<void> init() async {
    try {
      await FlameAudio.audioCache.loadAll(_files);
    } catch (e) {
      debugPrint('Audio preload failed: $e');
    }
  }

  void _play(String file, {double volume = 1.0}) {
    if (!SaveService.instance.soundOn) return;
    _playAsync(file, volume);
  }

  Future<void> _playAsync(String file, double volume) async {
    try {
      await FlameAudio.play(file, volume: volume);
    } catch (e) {
      debugPrint('Audio play failed: $e');
    }
  }

  void jump() => _play('jump.wav', volume: 0.5);
  void death() => _play('death.wav', volume: 0.8);
  void checkpoint() => _play('checkpoint.wav', volume: 0.7);
  void win() => _play('win.wav', volume: 0.8);
  void click() => _play('click.wav', volume: 0.6);
}
