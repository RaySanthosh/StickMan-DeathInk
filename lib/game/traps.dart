import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../theme.dart';
import 'death_note_game.dart';
import 'level.dart';

/// Base class: every trap kills the player on contact and owns a pool of
/// death-cause messages for the Death Note.
abstract class Trap extends PositionComponent with HasGameReference<DeathNoteGame> {
  List<String> get causes;

  bool touches(Rect playerRect);

  @override
  void update(double dt) {
    super.update(dt);
    final player = game.player;
    if (player.alive && touches(player.rect)) {
      game.killPlayer(causes);
    }
  }
}

/// Tiles that take part in collision through the level's dynamic solidity
/// map (vanishing platforms, fake floors).
abstract class SteppableTile extends Trap {
  bool get solid;
  void stepOn();
}

class Spike extends Trap {
  Spike(int col, int row) {
    position = Vector2(col * Level.tileSize, row * Level.tileSize);
    size = Vector2.all(Level.tileSize);
  }

  @override
  List<String> get causes => DeathNoteGame.spikeCauses;

  @override
  bool touches(Rect r) {
    final kill = Rect.fromLTWH(
        position.x + 8, position.y + Level.tileSize * 0.45,
        Level.tileSize - 16, Level.tileSize * 0.55);
    return r.overlaps(kill);
  }

  @override
  void render(Canvas canvas) {
    paintSpikes(canvas, up: true);
  }

  /// Shared spike drawing (also used by pop-up spikes / hanging barbs).
  static void paintSpikes(Canvas canvas,
      {required bool up, double raise = 1.0, bool red = false}) {
    final ink = Paint()
      ..color = red ? InkPalette.redInk : InkPalette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round;
    final fill = GamePaints.paperFill;
    const t = Level.tileSize;
    final path = Path();
    for (var i = 0; i < 3; i++) {
      final x0 = i * t / 3;
      if (up) {
        final tipY = t - (t * 0.75) * raise;
        path.moveTo(x0, t);
        path.lineTo(x0 + t / 6, tipY);
        path.lineTo(x0 + t / 3, t);
      } else {
        final tipY = (t * 0.75) * raise;
        path.moveTo(x0, 0);
        path.lineTo(x0 + t / 6, tipY);
        path.lineTo(x0 + t / 3, 0);
      }
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, ink);
    for (var i = 0; i < 3; i++) {
      final tipY = up ? t - (t * 0.72) * raise : (t * 0.72) * raise;
      canvas.drawCircle(
          Offset(i * t / 3 + t / 6, tipY), 2.2, GamePaints.redFill);
    }
  }
}

/// `v` — barbs hanging from the ceiling. Kill only the upper part of the
/// tile, so a sliding stickman passes safely underneath.
class HangingBarbs extends Trap {
  HangingBarbs(int col, int row) {
    position = Vector2(col * Level.tileSize, row * Level.tileSize);
    size = Vector2.all(Level.tileSize);
  }

  @override
  List<String> get causes => DeathNoteGame.barbCauses;

  @override
  bool touches(Rect r) {
    final kill = Rect.fromLTWH(position.x + 8, position.y,
        Level.tileSize - 16, Level.tileSize * 0.45);
    return r.overlaps(kill);
  }

  @override
  void render(Canvas canvas) {
    Spike.paintSpikes(canvas, up: false);
  }
}

/// `!` — pop-up spikes. Hidden except for faint red specks; spring out when
/// the player comes close.
class PopUpSpike extends Trap {
  PopUpSpike(int col, int row, math.Random rng)
      : _triggerDist = 60 + rng.nextDouble() * 60,
        _upTime = 0.8 + rng.nextDouble() * 0.5 {
    position = Vector2(col * Level.tileSize, row * Level.tileSize);
    size = Vector2.all(Level.tileSize);
  }

  static const _warnTime = 0.16;
  static const _cooldown = 0.6;

  final double _triggerDist;
  final double _upTime;
  _PopUpState _state = _PopUpState.hidden;
  double _timer = 0;

  @override
  List<String> get causes => DeathNoteGame.popSpikeCauses;

  @override
  void update(double dt) {
    final player = game.player;
    switch (_state) {
      case _PopUpState.hidden:
        final cx = position.x + size.x / 2;
        final playerBottom = player.position.y + player.size.y;
        final sameBand = (playerBottom - (position.y + size.y)).abs() < 60;
        if (player.alive &&
            sameBand &&
            (player.center.x - cx).abs() < _triggerDist) {
          _state = _PopUpState.warning;
          _timer = _warnTime;
        }
      case _PopUpState.warning:
        _timer -= dt;
        if (_timer <= 0) {
          _state = _PopUpState.up;
          _timer = _upTime;
        }
      case _PopUpState.up:
        _timer -= dt;
        if (_timer <= 0) {
          _state = _PopUpState.cooling;
          _timer = _cooldown;
        }
      case _PopUpState.cooling:
        _timer -= dt;
        if (_timer <= 0) _state = _PopUpState.hidden;
    }
    super.update(dt);
  }

  @override
  bool touches(Rect r) {
    if (_state != _PopUpState.up) return false;
    final kill = Rect.fromLTWH(
        position.x + 8, position.y + Level.tileSize * 0.45,
        Level.tileSize - 16, Level.tileSize * 0.55);
    return r.overlaps(kill);
  }

  @override
  void render(Canvas canvas) {
    const t = Level.tileSize;
    switch (_state) {
      case _PopUpState.hidden:
      case _PopUpState.cooling:
        // the tell: faint red specks on the floor
        final specks = Paint()
          ..color = InkPalette.redInk.withValues(alpha: 0.45);
        canvas.drawCircle(const Offset(t * 0.25, t - 4), 1.6, specks);
        canvas.drawCircle(const Offset(t * 0.55, t - 3), 1.3, specks);
        canvas.drawCircle(const Offset(t * 0.8, t - 5), 1.6, specks);
      case _PopUpState.warning:
        Spike.paintSpikes(canvas, up: true, raise: 0.25, red: true);
      case _PopUpState.up:
        Spike.paintSpikes(canvas, up: true, red: true);
    }
  }
}

enum _PopUpState { hidden, warning, up, cooling }

/// `d` — an inkwell that spits ink darts. The muzzle glows red before firing.
class DartShooter extends PositionComponent
    with HasGameReference<DeathNoteGame> {
  DartShooter(int col, int row, math.Random rng)
      : _col = col,
        _row = row,
        _period = 1.4 + rng.nextDouble() * 1.0 {
    position = Vector2(col * Level.tileSize, row * Level.tileSize);
    size = Vector2.all(Level.tileSize);
    _timer = _period * rng.nextDouble();
  }

  static const _warnTime = 0.3;

  final int _col;
  final int _row;
  final double _period;
  int dir = 1; // -1 left, 1 right; aimed at the longer open run on load
  double _timer = 0;

  bool get _warning => _timer < _warnTime;

  @override
  Future<void> onLoad() async {
    final level = game.level;
    var left = 0;
    while (_col - 1 - left >= 0 &&
        !level.staticSolidAt(_col - 1 - left, _row)) {
      left++;
    }
    var right = 0;
    while (_col + 1 + right < level.cols &&
        !level.staticSolidAt(_col + 1 + right, _row)) {
      right++;
    }
    dir = right >= left ? 1 : -1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer -= dt;
    if (_timer <= 0) {
      _timer = _period;
      // Only fire when the player is roughly on-screen. Off-screen shooters
      // used to spew darts nobody could see, piling up flying components and
      // dragging the whole game down over a session.
      final player = game.player;
      final cx = position.x + size.x / 2;
      final near = player.alive &&
          (player.center.x - cx).abs() < 640 &&
          (player.center.y - position.y).abs() < 320;
      if (!near) return;
      final rng = math.Random();
      parent?.add(InkDart(
        start: position +
            Vector2(dir > 0 ? size.x - 6 : 6, Level.tileSize - 30),
        velocity: Vector2(dir * (260 + rng.nextDouble() * 80), 0),
      ));
    }
  }

  @override
  void render(Canvas canvas) {
    const t = Level.tileSize;
    final ink = GamePaints.ink24;
    // inkwell pot
    final pot = Path()
      ..moveTo(t * 0.3, t)
      ..lineTo(t * 0.26, t * 0.62)
      ..lineTo(t * 0.74, t * 0.62)
      ..lineTo(t * 0.7, t)
      ..close();
    canvas.drawPath(pot, GamePaints.paperFill);
    canvas.drawPath(pot, ink);
    canvas.drawLine(
        Offset(t * 0.22, t * 0.62), Offset(t * 0.78, t * 0.62), ink);
    // muzzle
    final muzzleX = dir > 0 ? t * 0.78 : t * 0.22;
    canvas.drawCircle(Offset(muzzleX, t * 0.72), _warning ? 4.0 : 2.6,
        _warning ? GamePaints.redFill : GamePaints.graphiteFill);
  }
}

class InkDart extends Trap {
  InkDart({required Vector2 start, required this.velocity}) {
    position = start;
    size = Vector2(16, 6);
    anchor = Anchor.center;
  }

  final Vector2 velocity;
  double _life = 0; // hard cap so no dart can ever linger and accumulate

  @override
  List<String> get causes => DeathNoteGame.dartCauses;

  @override
  void update(double dt) {
    position += velocity * dt;
    _life += dt;
    final level = game.level;
    final col = (position.x / level.tile).floor();
    final row = (position.y / level.tile).floor();
    if (_life > 3.0 ||
        position.x < -50 ||
        position.x > level.pixelWidth + 50 ||
        level.solidAt(col, row)) {
      removeFromParent();
      return;
    }
    super.update(dt);
  }

  @override
  bool touches(Rect r) => r.overlaps(Rect.fromCenter(
      center: Offset(position.x, position.y), width: 14, height: 6));

  @override
  void render(Canvas canvas) {
    final ink = Paint()
      ..color = InkPalette.ink
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final flip = velocity.x < 0 ? -1.0 : 1.0;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.drawLine(Offset(-7 * flip, 0), Offset(6 * flip, 0), ink);
    canvas.drawCircle(Offset(7 * flip, 0), 2, Paint()..color = InkPalette.redInk);
    canvas.restore();
  }
}

/// `F` — fake floor. Looks like an ordinary tile apart from a hairline
/// crack; crumbles shortly after being stepped on.
class FakeFloor extends SteppableTile {
  FakeFloor(int col, int row, math.Random rng)
      : _respawnDelay = 2.6 + rng.nextDouble() * 1.2 {
    position = Vector2(col * Level.tileSize, row * Level.tileSize);
    size = Vector2.all(Level.tileSize);
  }

  static const _crumbleTime = 0.3;

  final double _respawnDelay;
  _FloorState _state = _FloorState.intact;
  double _timer = 0;

  @override
  bool get solid => _state != _FloorState.gone;

  @override
  List<String> get causes => const [];

  @override
  bool touches(Rect r) => false;

  @override
  void stepOn() {
    if (_state == _FloorState.intact) {
      _state = _FloorState.crumbling;
      _timer = _crumbleTime;
      game.floorBetrayal();
    }
  }

  @override
  void update(double dt) {
    switch (_state) {
      case _FloorState.intact:
        break;
      case _FloorState.crumbling:
        _timer -= dt;
        if (_timer <= 0) {
          _state = _FloorState.gone;
          _timer = _respawnDelay;
          game.floorBetrayal();
        }
      case _FloorState.gone:
        _timer -= dt;
        if (_timer <= 0) _state = _FloorState.intact;
    }
  }

  @override
  void render(Canvas canvas) {
    const t = Level.tileSize;
    if (_state == _FloorState.gone) {
      final ghost = Paint()
        ..color = InkPalette.inkFaded.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawRect(const Rect.fromLTWH(2, 2, t - 4, t - 4), ghost);
      return;
    }
    canvas.save();
    if (_state == _FloorState.crumbling) {
      canvas.translate(math.sin(_timer * 70) * 2, 0);
    }
    const rect = Rect.fromLTWH(0, 0, t, t);
    canvas.drawRect(rect, GamePaints.paperFill);
    for (var x = -t; x < t; x += 13) {
      canvas.drawLine(Offset(x, t), Offset(x + t, 0), GamePaints.hatch);
    }
    canvas.drawRect(rect, GamePaints.ink3);
    // the hairline crack (the tell)
    final crack = Paint()
      ..color = InkPalette.ink.withValues(alpha: 0.7)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final crackPath = Path()
      ..moveTo(t * 0.2, 2)
      ..lineTo(t * 0.4, t * 0.3)
      ..lineTo(t * 0.3, t * 0.55)
      ..lineTo(t * 0.55, t * 0.8)
      ..lineTo(t * 0.5, t - 2);
    canvas.drawPath(crackPath, crack);
    canvas.restore();
  }
}

enum _FloorState { intact, crumbling, gone }

class Saw extends Trap {
  Saw({
    required Vector2 center,
    required bool horizontal,
    required double minPos,
    required double maxPos,
    required double speed,
    required double phase,
  })  : _horizontal = horizontal,
        _min = minPos,
        _max = maxPos,
        _speed = speed {
    _travel = (_max - _min).abs();
    _s = _travel == 0 ? 0 : phase % 1.0;
    _base = center.clone();
    position = center;
    size = Vector2.all(radius * 2);
    anchor = Anchor.center;
  }

  static const radius = 19.0;

  final bool _horizontal;
  final double _min;
  final double _max;
  final double _speed;
  late final double _travel;
  late final Vector2 _base;
  double _s = 0; // 0..1 along the patrol
  bool _forward = true;
  double _spin = 0;

  @override
  List<String> get causes => DeathNoteGame.sawCauses;

  @override
  void update(double dt) {
    if (_travel > 0) {
      final step = _speed * dt / _travel;
      _s += _forward ? step : -step;
      if (_s >= 1) {
        _s = 1;
        _forward = false;
      } else if (_s <= 0) {
        _s = 0;
        _forward = true;
      }
      final p = _min + (_max - _min) * _s;
      if (_horizontal) {
        position.setValues(p, _base.y);
      } else {
        position.setValues(_base.x, p);
      }
    }
    _spin += dt * 7;
    super.update(dt);
  }

  @override
  bool touches(Rect r) => sawTouches(position, r);

  static bool sawTouches(Vector2 center, Rect r) {
    final cx = center.x.clamp(r.left, r.right);
    final cy = center.y.clamp(r.top, r.bottom);
    final dx = center.x - cx;
    final dy = center.y - cy;
    return dx * dx + dy * dy < (radius - 3) * (radius - 3);
  }

  @override
  void render(Canvas canvas) => paintBlade(canvas, _spin);

  static void paintBlade(Canvas canvas, double spin) {
    canvas.save();
    canvas.translate(radius, radius);
    canvas.rotate(spin);
    final ink = GamePaints.ink24;
    canvas.drawCircle(Offset.zero, radius - 4, GamePaints.paperFill);
    canvas.drawCircle(Offset.zero, radius - 4, ink);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final p1 = Offset(math.cos(a), math.sin(a)) * (radius - 4);
      final p2 = Offset(math.cos(a + 0.2), math.sin(a + 0.2)) * radius;
      canvas.drawLine(p1, p2, ink);
    }
    canvas.drawCircle(Offset.zero, 3, GamePaints.redFill);
    canvas.restore();
  }
}

/// `w` — rail saw. Crawls around the perimeter of a floating platform,
/// hugging floors, walls and ceilings. The waypoint loop is computed by
/// Level when the trap is (re)built.
class RailSaw extends Trap {
  RailSaw({
    required List<Vector2> waypoints,
    required double speed,
    required double startOffset,
  })  : _points = waypoints,
        _speed = speed {
    _lengths = [];
    _total = 0;
    for (var i = 0; i < _points.length; i++) {
      final next = _points[(i + 1) % _points.length];
      final len = _points[i].distanceTo(next);
      _lengths.add(len);
      _total += len;
    }
    _d = _total > 0 ? startOffset % _total : 0;
    position = _points.first.clone();
    size = Vector2.all(Saw.radius * 2);
    anchor = Anchor.center;
  }

  final List<Vector2> _points;
  final double _speed;
  late final List<double> _lengths;
  late double _total;
  double _d = 0;
  double _spin = 0;

  @override
  List<String> get causes => DeathNoteGame.railSawCauses;

  @override
  void update(double dt) {
    if (_total > 0) {
      _d = (_d + _speed * dt) % _total;
      var remaining = _d;
      for (var i = 0; i < _points.length; i++) {
        if (remaining <= _lengths[i] || i == _points.length - 1) {
          final next = _points[(i + 1) % _points.length];
          final t = _lengths[i] == 0 ? 0.0 : remaining / _lengths[i];
          position = _points[i] + (next - _points[i]) * t;
          break;
        }
        remaining -= _lengths[i];
      }
    }
    _spin += dt * 9;
    super.update(dt);
  }

  @override
  bool touches(Rect r) => Saw.sawTouches(position, r);

  @override
  void render(Canvas canvas) => Saw.paintBlade(canvas, _spin);
}

class Crusher extends Trap {
  Crusher({
    required int col,
    required int row,
    required double floorY,
    required double triggerDist,
    required double fallSpeed,
    required double restDelay,
  })  : _homeY = row * Level.tileSize,
        _floorY = floorY,
        _triggerDist = triggerDist,
        _fallSpeed = fallSpeed,
        _restDelay = restDelay {
    position = Vector2(col * Level.tileSize + 2, _homeY);
    size = Vector2(Level.tileSize - 4, Level.tileSize - 6);
  }

  final double _homeY;
  final double _floorY;
  final double _triggerDist;
  final double _fallSpeed;
  final double _restDelay;

  static const _riseSpeed = 130.0;
  _CrusherState _state = _CrusherState.idle;
  double _rest = 0;

  @override
  List<String> get causes => DeathNoteGame.crusherCauses;

  @override
  void update(double dt) {
    final player = game.player;
    switch (_state) {
      case _CrusherState.idle:
        final cx = position.x + size.x / 2;
        final px = player.center.x;
        if (player.alive &&
            (px - cx).abs() < _triggerDist &&
            player.position.y > position.y) {
          _state = _CrusherState.falling;
        }
      case _CrusherState.falling:
        position.y += _fallSpeed * dt;
        if (position.y + size.y >= _floorY) {
          position.y = _floorY - size.y;
          _state = _CrusherState.resting;
          _rest = _restDelay;
          game.shake(0.18);
        }
      case _CrusherState.resting:
        _rest -= dt;
        if (_rest <= 0) _state = _CrusherState.rising;
      case _CrusherState.rising:
        position.y -= _riseSpeed * dt;
        if (position.y <= _homeY) {
          position.y = _homeY;
          _state = _CrusherState.idle;
        }
    }
    super.update(dt);
  }

  @override
  bool touches(Rect r) {
    if (_state != _CrusherState.falling) return false;
    return r.overlaps(
        Rect.fromLTWH(position.x + 2, position.y, size.x - 4, size.y));
  }

  @override
  void render(Canvas canvas) {
    final ink = GamePaints.ink26;
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(rect, GamePaints.paperFill);
    canvas.drawRect(rect, ink);
    for (var x = -size.y; x < size.x; x += 9) {
      canvas.drawLine(
          Offset(x, size.y), Offset(x + size.y, 0), GamePaints.hatch05);
    }
    final teeth = Path();
    for (var i = 0; i < 4; i++) {
      final x0 = i * size.x / 4;
      teeth.moveTo(x0, size.y);
      teeth.lineTo(x0 + size.x / 8, size.y + 7);
      teeth.lineTo(x0 + size.x / 4, size.y);
    }
    canvas.drawPath(teeth, ink);
    // separate static (never mutate the shared ink paint)
    canvas.drawLine(Offset(size.x / 2, 0),
        Offset(size.x / 2, _homeY - position.y), GamePaints.ink2);
  }
}

enum _CrusherState { idle, falling, resting, rising }

class VanishingPlatform extends SteppableTile {
  VanishingPlatform({
    required this.col,
    required this.row,
    required double vanishDelay,
    required double respawnDelay,
  })  : _vanishDelay = vanishDelay,
        _respawnDelay = respawnDelay {
    position = Vector2(col * Level.tileSize, row * Level.tileSize);
    size = Vector2.all(Level.tileSize);
  }

  final int col;
  final int row;
  final double _vanishDelay;
  final double _respawnDelay;

  _PlatformState _state = _PlatformState.stable;
  double _timer = 0;

  @override
  bool get solid => _state != _PlatformState.gone;

  @override
  List<String> get causes => const [];

  @override
  bool touches(Rect r) => false;

  @override
  void stepOn() {
    if (_state == _PlatformState.stable) {
      _state = _PlatformState.wobbling;
      _timer = _vanishDelay;
    }
  }

  @override
  void update(double dt) {
    switch (_state) {
      case _PlatformState.stable:
        break;
      case _PlatformState.wobbling:
        _timer -= dt;
        if (_timer <= 0) {
          _state = _PlatformState.gone;
          _timer = _respawnDelay;
        }
      case _PlatformState.gone:
        _timer -= dt;
        if (_timer <= 0) _state = _PlatformState.stable;
    }
  }

  @override
  void render(Canvas canvas) {
    const t = Level.tileSize;
    const rect = Rect.fromLTWH(3, 6, t - 6, 12);
    if (_state == _PlatformState.gone) {
      final ghost = Paint()
        ..color = InkPalette.inkFaded.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawRect(rect, ghost);
      return;
    }
    canvas.save();
    if (_state == _PlatformState.wobbling) {
      final jitter = math.sin(_timer * 60) * 1.6;
      canvas.translate(jitter, 0);
    }
    final ink = GamePaints.ink24;
    canvas.drawRect(rect, GamePaints.paperFill);
    canvas.drawRect(rect, ink);
    for (var x = 6.0; x < t - 6; x += 10) {
      canvas.drawLine(
          Offset(x, 22), Offset(x + 5, 22), GamePaints.inkFadedThin);
    }
    canvas.restore();
  }
}

enum _PlatformState { stable, wobbling, gone }

class LaserGate extends Trap {
  LaserGate({
    required int col,
    required int row,
    required double floorY,
    required double period,
    required double phase,
  })  : _period = period,
        _phase = phase,
        _beamTop = (row + 1) * Level.tileSize,
        _beamBottom = floorY {
    position = Vector2(col * Level.tileSize, row * Level.tileSize);
    size = Vector2(Level.tileSize, floorY - row * Level.tileSize);
  }

  static const _duty = 0.55;

  final double _period;
  final double _phase;
  final double _beamTop;
  final double _beamBottom;
  double _t = 0;

  bool get firing => ((_t + _phase) % _period) < _period * _duty;

  @override
  List<String> get causes => DeathNoteGame.laserCauses;

  @override
  void update(double dt) {
    _t += dt;
    super.update(dt);
  }

  @override
  bool touches(Rect r) {
    if (!firing) return false;
    final beam = Rect.fromLTWH(position.x + Level.tileSize / 2 - 4, _beamTop,
        8, _beamBottom - _beamTop);
    return r.overlaps(beam);
  }

  @override
  void render(Canvas canvas) {
    const t = Level.tileSize;
    final ink = GamePaints.ink24;
    const housing = Rect.fromLTWH(t / 2 - 12, t - 18, 24, 18);
    canvas.drawRect(housing, GamePaints.paperFill);
    canvas.drawRect(housing, ink);
    canvas.drawCircle(const Offset(t / 2, t - 4), 3,
        firing ? GamePaints.redFill : GamePaints.graphiteFill);

    final beamLen = _beamBottom - _beamTop;
    if (firing) {
      final glow = Paint()
        ..color = InkPalette.redInk.withValues(alpha: 0.25)
        ..strokeWidth = 9;
      final core = Paint()
        ..color = InkPalette.redInk
        ..strokeWidth = 3;
      canvas.drawLine(const Offset(t / 2, t), Offset(t / 2, t + beamLen), glow);
      canvas.drawLine(const Offset(t / 2, t), Offset(t / 2, t + beamLen), core);
    } else {
      final warn = Paint()
        ..color = InkPalette.redInk.withValues(alpha: 0.35)
        ..strokeWidth = 1.6;
      for (var y = t; y < t + beamLen; y += 12) {
        canvas.drawLine(Offset(t / 2, y), Offset(t / 2, y + 5), warn);
      }
    }
  }
}
