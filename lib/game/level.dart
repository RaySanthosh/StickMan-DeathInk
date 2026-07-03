import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../theme.dart';
import 'death_note_game.dart';
import 'levels_data.dart';
import 'traps.dart';

/// Parses a [LevelData] grid, owns solidity queries, tile rendering and the
/// trap components (which reshuffle every attempt).
class Level extends PositionComponent with HasGameReference<DeathNoteGame> {
  Level(this.data);

  static const tileSize = 48.0;

  final LevelData data;
  double get tile => tileSize;
  int get cols => data.cols;
  int get rowCount => data.rowCount;
  double get pixelWidth => cols * tileSize;
  double get pixelHeight => rowCount * tileSize;

  late List<List<bool>> _solid; // [row][col], static tiles only
  late Vector2 spawn;
  final List<Checkpoint> checkpoints = [];
  final List<(String, int, int)> _trapSpecs = []; // (type, col, row)
  final List<Component> _trapComponents = [];
  final Map<int, SteppableTile> _tiles = {}; // vanishing platforms & fake floors
  final Set<int> _climbable = {}; // rope/ladder cells
  ui.Picture? _picture;

  @override
  Future<void> onLoad() async {
    size = Vector2(pixelWidth, pixelHeight);
    _solid = List.generate(rowCount, (_) => List.filled(cols, false));

    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < cols; col++) {
        final ch = data.rows[row][col];
        final px = Vector2(col * tileSize, row * tileSize);
        switch (ch) {
          case '#':
            _solid[row][col] = true;
          case 'S':
            spawn = px + Vector2(11, 4);
          case 'E':
            add(ExitDoor(position: px));
          case 'C':
            final checkpoint = Checkpoint(position: px);
            checkpoints.add(checkpoint);
            add(checkpoint);
          case 'H':
            _climbable.add(_key(col, row));
          case '^':
          case 's':
          case 'X':
          case '~':
          case 'L':
          case '!':
          case 'd':
          case 'F':
          case 'v':
          case 'w':
            _trapSpecs.add((ch, col, row));
        }
      }
    }
    _picture = _buildPicture();
    reshuffle(math.Random());
  }

  // ---- solidity ----
  bool solidAt(int col, int row) {
    if (col < 0 || col >= cols) return true; // side walls
    if (row < 0 || row >= rowCount) return false; // open sky / pit
    if (_solid[row][col]) return true;
    return _tiles[_key(col, row)]?.solid ?? false;
  }

  bool staticSolidAt(int col, int row) =>
      col >= 0 && col < cols && row >= 0 && row < rowCount && _solid[row][col];

  bool climbableAt(int col, int row) => _climbable.contains(_key(col, row));

  void onSteppedOn(int col, int row) => _tiles[_key(col, row)]?.stepOn();

  int _key(int col, int row) => row * 10000 + col;

  /// Rebuilds every trap with fresh random parameters — the "unpredictable"
  /// part: patterns change on every attempt.
  void reshuffle(math.Random rng) {
    for (final c in _trapComponents) {
      c.removeFromParent();
    }
    // Darts fired by shooters are added to the level directly (not tracked in
    // _trapComponents), so clear any still in flight from the last attempt —
    // otherwise they pile up across deaths and progressively slow the game.
    for (final dart in children.whereType<InkDart>().toList()) {
      dart.removeFromParent();
    }
    _trapComponents.clear();
    _tiles.clear();

    for (final (type, col, row) in _trapSpecs) {
      Component trap;
      switch (type) {
        case '^':
          trap = Spike(col, row);
        case 's':
          trap = _buildSaw(col, row, rng);
        case 'X':
          trap = Crusher(
            col: col,
            row: row,
            floorY: _floorYBelow(col, row),
            triggerDist: 120 + rng.nextDouble() * 130, // senses you sooner
            fallSpeed: 720 + rng.nextDouble() * 340, // slams faster
            restDelay: 0.28 + rng.nextDouble() * 0.4, // shorter safe window
          );
        case '~':
          final platform = VanishingPlatform(
            col: col,
            row: row,
            vanishDelay: 0.2 + rng.nextDouble() * 0.22, // crumbles quicker
            respawnDelay: 1.9 + rng.nextDouble() * 1.1, // gone longer
          );
          _tiles[_key(col, row)] = platform;
          trap = platform;
        case '!':
          trap = PopUpSpike(col, row, rng);
        case 'd':
          trap = DartShooter(col, row, rng);
        case 'F':
          final fake = FakeFloor(col, row, rng);
          _tiles[_key(col, row)] = fake;
          trap = fake;
        case 'v':
          trap = HangingBarbs(col, row);
        case 'w':
          trap = _buildRailSaw(col, row, rng);
        case 'L':
          trap = LaserGate(
            col: col,
            row: row,
            floorY: _floorYBelow(col, row),
            period: 0.8 + rng.nextDouble() * 0.8, // cycles faster
            phase: rng.nextDouble() * 2.0,
          );
        default:
          continue;
      }
      _trapComponents.add(trap);
      add(trap);
    }
  }

  Saw _buildSaw(int col, int row, math.Random rng) {
    // Patrol horizontally between the nearest solid tiles on this row
    // (or up to 8 tiles each way). Sometimes patrol vertically instead
    // when there's headroom — that's part of the unpredictability.
    var left = col;
    while (left - 1 >= 0 && !staticSolidAt(left - 1, row) && col - left < 8) {
      left--;
    }
    var right = col;
    while (right + 1 < cols && !staticSolidAt(right + 1, row) && right - col < 8) {
      right++;
    }
    var up = row;
    while (up - 1 >= 0 && !staticSolidAt(col, up - 1) && row - up < 5) {
      up--;
    }
    final canVertical = row - up >= 3;
    final vertical = canVertical && rng.nextDouble() < 0.35;
    final center = Vector2(
        col * tileSize + tileSize / 2, row * tileSize + tileSize / 2);
    if (vertical) {
      return Saw(
        center: center,
        horizontal: false,
        minPos: up * tileSize + Saw.radius,
        maxPos: (row + 1) * tileSize - Saw.radius,
        speed: 130 + rng.nextDouble() * 120,
        phase: rng.nextDouble(),
      );
    }
    return Saw(
      center: center,
      horizontal: true,
      minPos: left * tileSize + Saw.radius,
      maxPos: (right + 1) * tileSize - Saw.radius,
      speed: 130 + rng.nextDouble() * 130,
      phase: rng.nextDouble(),
    );
  }

  /// Builds the closed waypoint loop for a rail saw by walking the perimeter
  /// of the solid region next to its spawn cell (solid kept on the attach
  /// side; travel direction is the attach vector rotated 90°).
  Component _buildRailSaw(int col, int row, math.Random rng) {
    const dirs = [(0, 1), (-1, 0), (1, 0), (0, -1)]; // below, left, right, above
    (int, int)? attach;
    for (final d in dirs) {
      if (staticSolidAt(col + d.$1, row + d.$2)) {
        attach = d;
        break;
      }
    }
    final center =
        Vector2(col * tileSize + tileSize / 2, row * tileSize + tileSize / 2);
    if (attach == null) {
      // nothing to ride — degenerate to a stationary blade
      return RailSaw(waypoints: [center], speed: 0, startOffset: 0);
    }
    final points = <Vector2>[];
    var cell = (col, row);
    var a = attach;
    final start = (cell, a);
    var steps = 0;
    do {
      points.add(_railPos(cell, a));
      final t = (a.$2, -a.$1); // travel = rot90(attach)
      final next = (cell.$1 + t.$1, cell.$2 + t.$2);
      final diag = (next.$1 + a.$1, next.$2 + a.$2);
      if (staticSolidAt(next.$1, next.$2)) {
        a = t; // inner corner: attach to the wall ahead
      } else if (staticSolidAt(diag.$1, diag.$2)) {
        cell = next; // straight along the surface
      } else {
        cell = diag; // outer corner: wrap around the block
        a = (-t.$1, -t.$2);
      }
      steps++;
    } while ((cell, a) != start && steps < 400);
    return RailSaw(
      waypoints: points,
      speed: 100 + rng.nextDouble() * 90,
      startOffset: rng.nextDouble() * 4000,
    );
  }

  Vector2 _railPos((int, int) cell, (int, int) attach) {
    final center = Vector2(cell.$1 * tileSize + tileSize / 2,
        cell.$2 * tileSize + tileSize / 2);
    final off = tileSize / 2 - Saw.radius + 6;
    return center + Vector2(attach.$1 * off, attach.$2 * off);
  }

  double _floorYBelow(int col, int row) {
    for (var r = row + 1; r < rowCount; r++) {
      if (_solid[r][col]) return r * tileSize;
    }
    return pixelHeight;
  }

  // ---- rendering ----
  @override
  void render(ui.Canvas canvas) {
    final picture = _picture;
    if (picture != null) canvas.drawPicture(picture);
  }

  ui.Picture _buildPicture() {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // paper
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, pixelWidth, pixelHeight),
        ui.Paint()..color = InkPalette.paper);
    // ruled lines
    final ruled = ui.Paint()
      ..color = InkPalette.ruledLine.withValues(alpha: 0.6)
      ..strokeWidth = 1.4;
    for (var y = tileSize; y < pixelHeight; y += tileSize) {
      canvas.drawLine(ui.Offset(0, y), ui.Offset(pixelWidth, y), ruled);
    }
    // red margin line
    canvas.drawLine(
        const ui.Offset(120, 0),
        ui.Offset(120, pixelHeight),
        ui.Paint()
          ..color = InkPalette.marginLine.withValues(alpha: 0.55)
          ..strokeWidth = 2);

    // platforms: merge each row into runs and draw ink blocks
    final fill = ui.Paint()..color = InkPalette.paperShade;
    final ink = ui.Paint()
      ..color = InkPalette.ink
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = ui.StrokeJoin.round;
    final hatch = ui.Paint()
      ..color = InkPalette.graphite.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;

    for (var row = 0; row < rowCount; row++) {
      var col = 0;
      while (col < cols) {
        if (!_solid[row][col]) {
          col++;
          continue;
        }
        final start = col;
        while (col < cols && _solid[row][col]) {
          col++;
        }
        final rect = ui.Rect.fromLTWH(start * tileSize, row * tileSize,
            (col - start) * tileSize, tileSize);
        canvas.drawRect(rect, fill);
        // diagonal hatching, clipped
        canvas.save();
        canvas.clipRect(rect);
        for (var x = rect.left - tileSize; x < rect.right; x += 13) {
          canvas.drawLine(ui.Offset(x, rect.bottom),
              ui.Offset(x + tileSize, rect.top), hatch);
        }
        canvas.restore();
        canvas.drawRect(rect, ink);
      }
    }

    // ropes (climbable cells): a wavy ink line with rungs
    final ropePaint = ui.Paint()
      ..color = InkPalette.ink
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.2;
    for (final key in _climbable) {
      final col = key % 10000;
      final row = key ~/ 10000;
      final x = col * tileSize + tileSize / 2;
      final y = row * tileSize;
      final rope = ui.Path()..moveTo(x, y);
      for (var i = 0; i < 4; i++) {
        rope.quadraticBezierTo(x + (i.isEven ? 3 : -3), y + i * 12 + 6,
            x, y + (i + 1) * 12);
      }
      canvas.drawPath(rope, ropePaint);
      for (var i = 1; i < 4; i++) {
        canvas.drawLine(ui.Offset(x - 7, y + i * 12),
            ui.Offset(x + 7, y + i * 12), ropePaint);
      }
      // anchor knot on the topmost rope cell
      if (!_climbable.contains(_key(col, row - 1))) {
        canvas.drawCircle(ui.Offset(x, y + 2), 3.4,
            ui.Paint()..color = InkPalette.ink);
      }
    }
    return recorder.endRecording();
  }
}

class ExitDoor extends PositionComponent with HasGameReference<DeathNoteGame> {
  ExitDoor({required Vector2 position})
      : super(
          position: position - Vector2(0, Level.tileSize),
          size: Vector2(Level.tileSize, Level.tileSize * 2),
        );

  @override
  void update(double dt) {
    final player = game.player;
    if (player.alive &&
        !player.enteringDoor &&
        player.rect.overlaps(ui.Rect.fromLTWH(
            position.x + 8, position.y + 12, size.x - 16, size.y - 12))) {
      // hand over to the autopilot: he walks to the door and steps inside,
      // then the level completes
      player.beginExitDoor(position.x + size.x / 2);
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final ink = ui.Paint()
      ..color = InkPalette.ink
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.6;
    final door = ui.Rect.fromLTWH(6, 14, size.x - 12, size.y - 14);
    canvas.drawRect(door, ui.Paint()..color = InkPalette.paperShade);
    canvas.drawRect(door, ink);
    canvas.drawCircle(ui.Offset(size.x - 14, size.y * 0.6), 2.6,
        ui.Paint()..color = InkPalette.redInk);
    // "way out" doodle arrow above
    final red = ui.Paint()
      ..color = InkPalette.redInk
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(ui.Offset(size.x / 2, 2), ui.Offset(size.x / 2, 10), red);
    canvas.drawLine(ui.Offset(size.x / 2 - 4, 6), ui.Offset(size.x / 2, 10), red);
    canvas.drawLine(ui.Offset(size.x / 2 + 4, 6), ui.Offset(size.x / 2, 10), red);
  }
}

class Checkpoint extends PositionComponent with HasGameReference<DeathNoteGame> {
  Checkpoint({required Vector2 position})
      : super(position: position, size: Vector2.all(Level.tileSize));

  bool activated = false;

  @override
  void update(double dt) {
    if (activated) return;
    final player = game.player;
    if (player.alive && player.rect.overlaps(rect)) {
      activated = true;
      game.setCheckpoint(this);
    }
  }

  ui.Rect get rect =>
      ui.Rect.fromLTWH(position.x, position.y, size.x, size.y);

  /// Where the player respawns from this checkpoint.
  Vector2 get respawnPoint => position + Vector2(11, 4);

  @override
  void render(ui.Canvas canvas) {
    final ink = ui.Paint()
      ..color = InkPalette.ink
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.4;
    const t = Level.tileSize;
    // pole
    canvas.drawLine(const ui.Offset(14, 6), const ui.Offset(14, t), ink);
    // flag
    final flag = ui.Path()
      ..moveTo(14, 8)
      ..lineTo(38, 14)
      ..lineTo(14, 22)
      ..close();
    canvas.drawPath(
        flag,
        ui.Paint()
          ..color = activated
              ? InkPalette.redInk
              : InkPalette.paperShade);
    canvas.drawPath(flag, ink);
  }
}
