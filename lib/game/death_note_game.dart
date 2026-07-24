import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../services/audio_service.dart';
import '../services/firebase_service.dart';
import '../services/save_service.dart';
import '../theme.dart';
import 'level.dart';
import 'levels_data.dart';
import 'player.dart';
import 'scoring.dart';

class DeathNoteGame extends FlameGame with KeyboardEvents {
  DeathNoteGame({
    required this.levelIndex,
    required this.onDeathOverlay,
    required this.onCompleteOverlay,
  }) : super(
          camera: CameraComponent.withFixedResolution(width: 960, height: 540),
        );

  final int levelIndex;
  final void Function(String cause) onDeathOverlay;
  final void Function(LevelResult result) onCompleteOverlay;

  late Level level;
  late Player player;
  final audio = AudioService.instance;
  final _rng = math.Random();

  // input state (driven by HUD buttons and keyboard)
  bool moveLeft = false;
  bool moveRight = false;
  bool jumpHeld = false; // climbs ropes
  bool slideHeld = false; // descends ropes
  bool _jumpPressed = false;
  bool _slidePressed = false;

  int deaths = 0;
  String lastDeathKind = 'general'; // 'spike' | 'dart' | 'fall' | 'general'
  final clock = Stopwatch();
  Checkpoint? _checkpoint;
  bool _finished = false;
  double _shakeTime = 0;

  // ---- death-cause pools, written to the Note ----
  static const spikeCauses = [
    'Acupuncture went too far.',
    'Sat on the pointy end of life.',
    'Found out spikes are not stairs.',
    'Hugged a porcupine fence.',
  ];
  static const sawCauses = [
    'Cut short. Literally.',
    'Split decision.',
    'Tried to high-five a saw blade.',
    'Became two smaller stickmen.',
  ];
  static const crusherCauses = [
    'Flattened like a fresh page.',
    'Squished. Again.',
    'Now available in 2D. Even more 2D.',
    'Looked up at the wrong moment.',
  ];
  static const laserCauses = [
    'Toasted by red ink.',
    'Walked into the highlighter of doom.',
    'Underestimated the power of light.',
    'Crossed the red line.',
  ];
  static const popSpikeCauses = [
    'The floor had trust issues.',
    'Stepped on a suspiciously dotted tile.',
    'Surprise! It was pointy.',
    'The ground bit back.',
  ];
  static const dartCauses = [
    'The pen is mightier than the stickman.',
    'Caught a dart with the wrong body part.',
    'Never trust a friendly inkwell.',
    'Quilled in action.',
  ];
  static const voidCauses = [
    'Fell off the page.',
    'Gravity: 1 — Stickman: 0.',
    'Went to explore the margin. Forever.',
    'Discovered the page has no footer.',
  ];
  static const barbCauses = [
    'Forgot to duck.',
    'Head-first into the fine print.',
    'Should have slid. Did not slide.',
  ];
  static const railSawCauses = [
    'Traced by the cutting edge.',
    'Followed the dotted line. Badly.',
    'Edge case: the edge won.',
  ];
  static const fakeFloorCauses = [
    'The floor was a lie.',
    'Trusted the wrong tile.',
    'Terms and conditions applied. Underfoot.',
  ];

  @override
  Color backgroundColor() => InkPalette.paperShade;

  @override
  Future<void> onLoad() async {
    level = Level(levels[levelIndex]);
    await world.add(level);
    player = Player();
    await world.add(player);
    await level.loaded;
    player.reset(level.spawn);

    camera.follow(player, snap: true);
    camera.setBounds(
      Rectangle.fromLTRB(0, 0, level.pixelWidth, level.pixelHeight),
      considerViewport: true,
    );
    clock.start();
  }

  bool consumeJumpPressed() {
    final was = _jumpPressed;
    _jumpPressed = false;
    return was;
  }

  void pressJump() => _jumpPressed = true;

  bool consumeSlidePressed() {
    final was = _slidePressed;
    _slidePressed = false;
    return was;
  }

  void pressSlide() => _slidePressed = true;

  /// A fake floor just crumbled — void deaths in the next moments get
  /// attributed to it in the Note.
  void floorBetrayal() => _betrayal = 2.0;
  double _betrayal = 0;

  void shake([double duration = 0.3]) => _shakeTime = duration;

  @override
  void update(double dt) {
    // Clamp dt so a large gap (e.g. returning from background) can't spike
    // physics, shake, or trap timers by a single huge step.
    if (dt > 1 / 30) dt = 1 / 30;
    super.update(dt);
    if (_betrayal > 0) _betrayal -= dt;
    if (_shakeTime > 0) {
      _shakeTime -= dt;
      final magnitude = 6 * (_shakeTime / 0.3).clamp(0.0, 1.0);
      // jitter the viewfinder; the follow behavior re-centers it next frame
      camera.viewfinder.position += Vector2(
        (_rng.nextDouble() - 0.5) * 2 * magnitude,
        (_rng.nextDouble() - 0.5) * 2 * magnitude,
      );
    }
  }

  void killPlayer(List<String> causes) {
    if (_finished || !player.alive) return;
    player.alive = false;
    deaths++;
    clock.stop();
    if (identical(causes, voidCauses) && _betrayal > 0) {
      causes = fakeFloorCauses; // fell through a crumbled fake floor
    }
    // classify for the taunt pools (spike/dart/fall get flavoured roasts)
    lastDeathKind = identical(causes, dartCauses)
        ? 'dart'
        : (identical(causes, voidCauses) || identical(causes, fakeFloorCauses))
            ? 'fall'
            : (identical(causes, spikeCauses) ||
                    identical(causes, popSpikeCauses) ||
                    identical(causes, barbCauses) ||
                    identical(causes, sawCauses) ||
                    identical(causes, railSawCauses))
                ? 'spike'
                : 'general';
    final cause = causes.isEmpty
        ? 'Died mysteriously.'
        : causes[_rng.nextInt(causes.length)];
    SaveService.instance.recordDeath(levelIndex, cause);
    audio.death();
    shake();
    world.add(InkSplat(position: player.center));
    onDeathOverlay(cause);
  }

  void respawn() {
    _jumpPressed = false; // drop any presses buffered while dead
    _slidePressed = false;
    level.reshuffle(math.Random()); // new trap patterns every attempt
    for (final checkpoint in level.checkpoints) {
      // keep flags the player already reached
      checkpoint.activated = checkpoint == _checkpoint ||
          (_checkpoint != null &&
              checkpoint.position.x <= _checkpoint!.position.x);
    }
    player.reset(_checkpoint?.respawnPoint ?? level.spawn);
    clock.start();
  }

  void setCheckpoint(Checkpoint checkpoint) {
    _checkpoint = checkpoint;
    audio.checkpoint();
  }

  Future<void> completeLevel() async {
    if (_finished) return;
    _finished = true;
    clock.stop();
    final timeMs = clock.elapsedMilliseconds;
    final stars = starRating(
      timeMs: timeMs,
      deaths: deaths,
      parSeconds: levels[levelIndex].parSeconds * 0.8, // tighter 3-star bar
    );
    final improved = await SaveService.instance.recordResult(
      level: levelIndex,
      timeMs: timeMs,
      deaths: deaths,
      stars: stars,
      levelCount: levels.length,
    );
    FirebaseService.instance.submitScore(
        level: levelIndex, timeMs: timeMs, deaths: deaths, improved: improved);
    audio.win();
    onCompleteOverlay(LevelResult(
      levelIndex: levelIndex,
      timeMs: timeMs,
      deaths: deaths,
      stars: stars,
    ));
  }

  // ---- keyboard (handy on desktop/emulator) ----
  @override
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    moveLeft = keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    moveRight = keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);
    jumpHeld = keysPressed.contains(LogicalKeyboardKey.space) ||
        keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
        keysPressed.contains(LogicalKeyboardKey.keyW);
    slideHeld = keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
        keysPressed.contains(LogicalKeyboardKey.keyS);
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.keyW)) {
      pressJump();
    }
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.arrowDown ||
            event.logicalKey == LogicalKeyboardKey.keyS)) {
      pressSlide();
    }
    return KeyEventResult.handled;
  }
}

/// Quick red-ink splatter on death.
class InkSplat extends PositionComponent {
  InkSplat({required Vector2 position})
      : super(position: position, anchor: Anchor.center);

  static const _lifetime = 0.6;
  final _rng = math.Random();
  late final List<Vector2> _dirs = List.generate(
      14,
      (_) => Vector2((_rng.nextDouble() - 0.5) * 2, _rng.nextDouble() - 0.7)
        ..scale(120 + _rng.nextDouble() * 120));
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= _lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final progress = (_t / _lifetime).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = InkPalette.redInk.withValues(alpha: 1 - progress);
    for (final dir in _dirs) {
      final gravityDrop = 200 * _t * _t;
      final p = Offset(dir.x * _t, dir.y * _t + gravityDrop);
      canvas.drawCircle(p, 3 * (1 - progress) + 1, paint);
    }
  }
}
