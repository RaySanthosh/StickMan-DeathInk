import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../theme.dart';
import 'death_note_game.dart';

/// The stickman. Tile-grid AABB physics with acceleration + ground friction,
/// a walk that ramps into a run, skid-slides when reversing at speed, a
/// wall-bonk stagger on hard impacts and a stumble on heavy landings.
/// Double jump, wall slide and wall jump as before.
///
/// Animation is a forward-kinematics skeleton driven by joint ANGLES, not
/// positions. Proportions use the classic unit scheme (head 1u, torso 2u,
/// arm segments 1.2u, leg segments 1.5u), every pose is a set of hip / knee /
/// shoulder / elbow angles clamped to human joint limits, and the walk / run
/// gaits are keyframed cycles (contact -> passing -> contact -> passing) at
/// realistic cadences. The pelvis height is derived from the support leg's
/// extension so the centre of gravity rises and falls like an inverted
/// pendulum: walking is controlled falling, running is controlled jumping.
class Player extends PositionComponent with HasGameReference<DeathNoteGame> {
  Player() : super(size: Vector2(26, 42), anchor: Anchor.topLeft);

  // --- locomotion tuning ---
  static const walkSpeed = 145.0;
  static const runSpeed = 255.0;
  static const runRampTime = 0.55; // hold a direction this long to hit a sprint
  static const groundAccel = 1600.0;
  static const turnAccel = 1100.0; // reversing at speed is slower -> visible skid
  static const groundFriction = 1250.0; // letting go of input slides you to a stop
  static const airAccel = 960.0; // 60% air control
  static const airFriction = 180.0;
  static const gravity = 1500.0;
  static const jumpVelocity = -520.0;
  static const doubleJumpVelocity = -480.0;
  static const wallJumpVelocity = -500.0;
  static const wallJumpKick = 300.0;
  static const maxFall = 820.0;
  static const wallSlideMaxFall = 150.0;
  static const coyoteTime = 0.1;
  static const jumpBuffer = 0.12;
  static const bonkSpeed = 200.0; // hit a wall faster than this and you crumple
  static const heavyLanding = 660.0; // land faster than this and you stumble
  static const standHeight = 42.0;
  static const slideHeight = 22.0; // low enough to pass under hanging barbs
  static const slideSpeed = 310.0;
  static const slideDuration = 0.6;
  static const climbUpSpeed = 100.0; // ~2/3 of walk, per climb-speed ratio
  static const climbDownSpeed = 140.0;

  // --- skeleton proportions (athletic adult): unit u = height / 6.2 ---
  // head 1.0u, torso 2.2u, upper arm 1.1u, lower arm 1.0u, legs 1.5u+1.5u
  static const _u = 42.0 / 6.2;
  static const _torso = 2.2 * _u;
  static const _thigh = 1.5 * _u;
  static const _shin = 1.5 * _u;
  static const _uArm = 1.1 * _u;
  static const _fArm = 1.0 * _u;
  static const _headR = 0.5 * _u; // 1u head height, padded for readability

  static const _d2r = math.pi / 180;

  // joint limits (degrees, biomechanical maximums; bends never lock at 0)
  static const _shMin = -60.0, _shMax = 180.0;
  static const _elMin = 0.0, _elMax = 160.0;
  static const _hipMin = -65.0, _hipMax = 130.0; // -60 hip needed in a slide
  static const _kneeMin = 0.0, _kneeMax = 155.0;

  // gait keyframes over one cycle: contact, passing, contact(mirror), swing.
  // Hip/shoulder angles are swings from straight-down vertical (+ = forward),
  // knee/elbow values are BEND amounts (0 = straight; interior = 180 - bend).
  // Walk (mocap): hips +30/-20, shoulders +20/-25 (back swing larger),
  // knees 10 front / 40 back, elbows 145/160 interior -> 35/20 bend.
  static const _walkHip = [30.0, 0.0, -20.0, 5.0];
  static const _walkKnee = [10.0, 8.0, 40.0, 25.0];
  static const _walkSh = [-25.0, 0.0, 20.0, 0.0]; // arms opposite the legs
  static const _walkEl = [20.0, 28.0, 35.0, 28.0];
  // Run (athletic sprint): hips +45/-35, shoulders +55/-50, knees 30 front /
  // 90 rear (60/120 in flight), elbows PUMP — 65deg interior (115 bend) when
  // the hand drives up to chest level, 100deg interior (80 bend) by the hip.
  static const _runHip = [45.0, 0.0, -35.0, 25.0];
  static const _runKnee = [30.0, 60.0, 90.0, 120.0];
  static const _runSh = [-50.0, 0.0, 55.0, 0.0];
  static const _runEl = [80.0, 95.0, 115.0, 95.0];
  // walk cycle 24 frames @60fps = 0.40s, run cycle 16 frames = 0.27s:
  // stride px/cycle so the cadence lands on those durations at each speed
  static const _walkStride = 58.0; // 145 px/s * 0.40 s
  static const _runStride = 68.0; // 255 px/s * 0.27 s

  final velocity = Vector2.zero();
  bool facingRight = true;
  bool grounded = false;
  int wallDir = 0; // -1 wall on left, 1 wall on right, 0 none
  bool _doubleJumpUsed = false;
  double _coyote = 0;
  double _buffer = 0;
  double _wallLock = 0; // input lock after wall jump
  bool alive = true;

  // locomotion state
  double _runHold = 0; // how long the current direction has been held
  double _lastDir = 0;
  double _stagger = 0; // wall-bonk recovery timer
  double _stumble = 0; // heavy-landing recovery timer
  double _djTuck = 0; // exaggerated double-jump tuck timer
  bool _skidding = false;
  bool sliding = false; // deliberate low slide (SLIDE button)
  double _slideTimer = 0;
  bool onLadder = false; // hanging on a rope
  double _gait = 0; // stride cycle (1.0 = one full left+right step pair)
  double _idleT = 0;

  // automatic door entry: reach the exit -> walk to it -> step inside
  static const enterDoorDuration = 0.45;
  double? _doorX; // door centre x while the entry autopilot runs
  double _enterT = 0; // time spent stepping through the doorway
  bool get enteringDoor => _doorX != null;

  // smoothed joint angles, degrees (A = near-side limb, B = far side)
  double _lean = 2; // torso lean from vertical, + = facing direction
  double _hipDy = 0; // pelvis crouch offset, + = lower
  double _hipA = 4, _kneeA = 10, _hipB = -4, _kneeB = 10;
  double _shA = 10, _elA = 20, _shB = 10, _elB = 20;

  Rect get rect => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  void reset(Vector2 spawn) {
    position = spawn.clone();
    velocity.setZero();
    alive = true;
    grounded = false;
    _doubleJumpUsed = false;
    _coyote = 0;
    _buffer = 0;
    _wallLock = 0;
    _runHold = 0;
    _lastDir = 0;
    _stagger = 0;
    _stumble = 0;
    _djTuck = 0;
    _skidding = false;
    sliding = false;
    _slideTimer = 0;
    onLadder = false;
    _doorX = null;
    _enterT = 0;
    size.y = standHeight;
    _gait = 0;
    // settle into the idle pose so nothing lerps in from odd angles
    _lean = 2;
    _hipDy = 0;
    _hipA = 4;
    _kneeA = 10;
    _hipB = -4;
    _kneeB = 10;
    _shA = 10;
    _elA = 20;
    _shB = 10;
    _elB = 20;
  }

  @override
  void update(double dt) {
    if (!alive) return;
    dt = math.min(dt, 1 / 30); // avoid tunneling on hitches
    _idleT += dt;
    if (_djTuck > 0) _djTuck -= dt;

    // --- door-entry autopilot: input is ignored, he walks himself in ---
    if (_doorX != null) {
      _enterDoor(dt);
      return;
    }

    // --- rope climbing ---
    final overRope = _overlappingRope();
    if (onLadder && !overRope) onLadder = false;
    if (!onLadder && overRope && !grounded && velocity.y > 0) {
      onLadder = true; // catch the rope while falling past it
      _doubleJumpUsed = false;
      velocity.setZero();
    }
    if (onLadder) {
      var climbDir = 0.0;
      if (game.moveLeft) climbDir -= 1;
      if (game.moveRight) climbDir += 1;
      if (climbDir != 0) facingRight = climbDir > 0;
      velocity.x = climbDir * 70;
      velocity.y = game.jumpHeld
          ? -climbUpSpeed
          : (game.slideHeld ? climbDownSpeed : 0.0);
      _gait += velocity.length * dt / 46; // hand-over-hand cadence
      if (game.consumeJumpPressed()) {
        onLadder = false; // leap off
        velocity.y = jumpVelocity * 0.85;
        if (climbDir != 0) velocity.x = climbDir * walkSpeed;
        game.audio.jump();
      }
      game.consumeSlidePressed();
      _moveAndCollide(dt);
      if (grounded) onLadder = false;
      _updatePose(dt);
      if (position.y > game.level.pixelHeight + 100) {
        game.killPlayer(DeathNoteGame.voidCauses);
      }
      return;
    }

    // --- deliberate slide: duck under barbs and darts ---
    if (game.consumeSlidePressed() && grounded && !sliding && _stagger <= 0) {
      sliding = true;
      _slideTimer = slideDuration;
      position.y += standHeight - slideHeight;
      size.y = slideHeight;
      velocity.x = (facingRight ? 1 : -1) * slideSpeed;
    }
    if (sliding) {
      _slideTimer -= dt;
      final k = (_slideTimer / slideDuration).clamp(0.0, 1.0);
      velocity.x =
          (facingRight ? 1 : -1) * (walkSpeed + (slideSpeed - walkSpeed) * k);
      if (_slideTimer <= 0 && _tryStand()) sliding = false;
    }

    // --- horizontal input ---
    var dir = 0.0;
    if (game.moveLeft) dir -= 1;
    if (game.moveRight) dir += 1;
    if (_stagger > 0) {
      _stagger -= dt;
      dir = 0; // too dazed to steer
    }
    if (_stumble > 0) _stumble -= dt;
    if (_wallLock > 0) {
      _wallLock -= dt;
      dir = 0; // preserve the wall-jump kick
    }

    // a held direction ramps a walk into a run
    if (dir == 0 || dir != _lastDir) _runHold = 0;
    if (dir != 0) _runHold += dt;
    _lastDir = dir;
    final ramp = (_runHold / runRampTime).clamp(0.0, 1.0);
    var topSpeed = walkSpeed + (runSpeed - walkSpeed) * ramp;
    if (_stumble > 0) topSpeed = walkSpeed * 0.6; // wobbly knees after a hard landing

    // acceleration & friction instead of instant velocity
    _skidding = false;
    if (sliding) {
      // committed: velocity is owned by the slide itself
    } else if (dir == 0) {
      final friction = grounded ? groundFriction : airFriction;
      velocity.x = _approach(velocity.x, 0, friction * dt);
    } else {
      final reversing = velocity.x != 0 && dir * velocity.x < 0;
      if (reversing && grounded && velocity.x.abs() > walkSpeed * 0.8) {
        _skidding = true; // feet planted, sliding on momentum, low CoG
      }
      final accel = !grounded ? airAccel : (reversing ? turnAccel : groundAccel);
      velocity.x = _approach(velocity.x, dir * topSpeed, accel * dt);
      facingRight = dir > 0;
    }

    // --- jumping ---
    _coyote = grounded ? coyoteTime : math.max(0, _coyote - dt);
    _buffer = game.consumeJumpPressed() ? jumpBuffer : math.max(0, _buffer - dt);
    if (_buffer > 0 && _stagger <= 0) {
      if (grounded || _coyote > 0) {
        if (!sliding || _tryStand()) {
          sliding = false;
          velocity.y = jumpVelocity;
          grounded = false;
          _coyote = 0;
          _buffer = 0;
          game.audio.jump();
        }
      } else if (wallDir != 0) {
        velocity.y = wallJumpVelocity;
        velocity.x = -wallDir * wallJumpKick;
        _wallLock = 0.14;
        facingRight = wallDir < 0;
        _doubleJumpUsed = false;
        _buffer = 0;
        game.audio.jump();
      } else if (!_doubleJumpUsed) {
        velocity.y = doubleJumpVelocity;
        _doubleJumpUsed = true;
        _djTuck = 0.26; // knees to chest, arms thrown high
        _buffer = 0;
        game.audio.jump();
      }
    }

    // --- gravity & wall slide ---
    velocity.y += gravity * dt;
    final pushingWall = wallDir != 0 &&
        ((wallDir < 0 && game.moveLeft) || (wallDir > 0 && game.moveRight));
    final maxFallNow = pushingWall && velocity.y > 0 ? wallSlideMaxFall : maxFall;
    if (velocity.y > maxFallNow) velocity.y = maxFallNow;

    _moveAndCollide(dt);

    if (grounded || wallDir != 0) _doubleJumpUsed = false;

    _updatePose(dt);

    // fell off the page
    if (position.y > game.level.pixelHeight + 100) {
      game.killPlayer(DeathNoteGame.voidCauses);
    }
  }

  /// Called by the exit door: hand control to the autopilot.
  void beginExitDoor(double doorCenterX) {
    if (_doorX != null || !alive) return;
    if (sliding && _tryStand()) sliding = false;
    _doorX = doorCenterX;
    _stagger = 0;
    _stumble = 0;
  }

  /// Walk to the door centre, stop, then step inside (fade handled in
  /// render); the level completes once he's fully through.
  void _enterDoor(double dt) {
    final dx = _doorX! - (position.x + size.x / 2);
    if (_enterT == 0 && dx.abs() > 3) {
      facingRight = dx > 0;
      velocity.x = _approach(velocity.x, dx.sign * walkSpeed, groundAccel * dt);
    } else {
      _enterT += dt;
      velocity.x = _approach(velocity.x, 0, groundFriction * dt);
      if (_enterT >= enterDoorDuration) game.completeLevel();
    }
    velocity.y = math.min(velocity.y + gravity * dt, maxFall);
    _moveAndCollide(dt);
    _updatePose(dt);
  }

  static double _approach(double v, double target, double maxDelta) {
    if (v < target) return math.min(v + maxDelta, target);
    return math.max(v - maxDelta, target);
  }

  void _moveAndCollide(double dt) {
    final level = game.level;

    // X axis
    final preVx = velocity.x;
    position.x += velocity.x * dt;
    wallDir = 0;
    if (velocity.x > 0) {
      final col = ((position.x + size.x) / level.tile).floor();
      if (_solidInColumn(col)) {
        position.x = col * level.tile - size.x - 0.01;
        velocity.x = 0;
        wallDir = 1;
        _maybeBonk(preVx);
      }
    } else if (velocity.x < 0) {
      final col = (position.x / level.tile).floor();
      if (_solidInColumn(col)) {
        position.x = (col + 1) * level.tile + 0.01;
        velocity.x = 0;
        wallDir = -1;
        _maybeBonk(preVx);
      }
    } else {
      // still report wall contact for slide/jump when pressing into a wall
      final rightCol = ((position.x + size.x + 1) / level.tile).floor();
      final leftCol = ((position.x - 1) / level.tile).floor();
      if (_solidInColumn(rightCol)) wallDir = 1;
      if (_solidInColumn(leftCol)) wallDir = -1;
    }
    position.x = position.x.clamp(0.0, level.pixelWidth - size.x);

    // Y axis
    final preVy = velocity.y;
    position.y += velocity.y * dt;
    grounded = false;
    if (velocity.y > 0) {
      final row = ((position.y + size.y) / level.tile).floor();
      if (_solidInRow(row)) {
        position.y = row * level.tile - size.y - 0.01;
        velocity.y = 0;
        grounded = true;
        if (preVy > heavyLanding) {
          // hard landing: knees buckle, momentum bleeds off
          _stumble = 0.30;
          velocity.x *= 0.35;
          _runHold = 0;
        }
      }
    } else if (velocity.y < 0) {
      final row = (position.y / level.tile).floor();
      if (_solidInRow(row)) {
        position.y = (row + 1) * level.tile + 0.01;
        velocity.y = 0;
      }
    }
  }

  /// Running face-first into a wall isn't free: recoil and a short daze.
  void _maybeBonk(double impactVx) {
    if (impactVx.abs() < bonkSpeed || _stagger > 0) return;
    _stagger = 0.30;
    velocity.x = -impactVx.sign * 70; // bounce off the wall
    _runHold = 0;
    game.shake(0.12);
  }

  bool _solidInColumn(int col) {
    final level = game.level;
    final top = (position.y / level.tile).floor();
    final bottom = ((position.y + size.y - 1) / level.tile).floor();
    for (var row = top; row <= bottom; row++) {
      if (level.solidAt(col, row)) return true;
    }
    return false;
  }

  bool _solidInRow(int row) {
    final level = game.level;
    final left = (position.x / level.tile).floor();
    final right = ((position.x + size.x - 1) / level.tile).floor();
    for (var col = left; col <= right; col++) {
      if (level.solidAt(col, row)) {
        // notify vanishing platforms / fake floors we stepped on them
        if (velocity.y > 0) level.onSteppedOn(col, row);
        return true;
      }
    }
    return false;
  }

  /// Restores the standing hitbox if there's headroom; false when blocked.
  bool _tryStand() {
    final level = game.level;
    final newTop = position.y + size.y - standHeight;
    final left = (position.x / level.tile).floor();
    final right = ((position.x + size.x - 1) / level.tile).floor();
    final topRow = (newTop / level.tile).floor();
    final bottomRow = ((position.y - 1) / level.tile).floor();
    for (var row = topRow; row <= bottomRow; row++) {
      for (var col = left; col <= right; col++) {
        if (level.solidAt(col, row)) return false;
      }
    }
    position.y = newTop;
    size.y = standHeight;
    return true;
  }

  bool _overlappingRope() {
    final level = game.level;
    final col = ((position.x + size.x / 2) / level.tile).floor();
    final top = (position.y / level.tile).floor();
    final bottom = ((position.y + size.y - 1) / level.tile).floor();
    for (var row = top; row <= bottom; row++) {
      if (level.climbableAt(col, row)) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------- pose ---

  /// Smoothly samples a looping keyframe list at cycle phase [ph] (cycles).
  static double _cycle(List<double> keys, double ph) {
    final n = keys.length;
    var x = (ph % 1.0) * n;
    if (x < 0) x += n;
    final i = x.floor() % n;
    final t = x - x.floorToDouble();
    final s = 0.5 - 0.5 * math.cos(t * math.pi); // ease between keys
    return keys[i] * (1 - s) + keys[(i + 1) % n] * s;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Picks target joint angles for the current movement state, clamps them to
  /// joint limits and eases the smoothed angles toward them.
  void _updatePose(double dt) {
    final speed = velocity.x.abs();
    final r = ((speed - walkSpeed) / (runSpeed - walkSpeed)).clamp(0.0, 1.0);
    final moving = speed > 8;

    // targets (degrees)
    double lean, hipDy, hipA, kneeA, hipB, kneeB, shA, elA, shB, elB;

    final wallSliding = !grounded &&
        wallDir != 0 &&
        velocity.y > 0 &&
        (wallDir < 0 ? game.moveLeft : game.moveRight);

    if (_stagger > 0) {
      // crumpled off a wall bonk: torso thrown back, arms shielding the face
      lean = -25;
      hipDy = 3;
      hipA = 15;
      kneeA = 30;
      hipB = -15;
      kneeB = 20;
      shA = 70;
      elA = 50;
      shB = 55;
      elB = 60;
    } else if (wallSliding || onLadder) {
      // climbing: the arms PULL the body. Reach phase: shoulder 170deg,
      // elbow nearly straight (20deg bend), hip 40 / knee 70. Pull phase:
      // shoulder 120deg, elbow 90deg bend, hip 50 / knee 90. The two arms
      // alternate half a cycle apart, driven by climb distance.
      final ph = _gait;
      lean = 3;
      hipDy = 2;
      hipA = _cycle(const [40.0, 50.0], ph);
      kneeA = _cycle(const [70.0, 90.0], ph);
      hipB = _cycle(const [50.0, 40.0], ph);
      kneeB = _cycle(const [90.0, 70.0], ph);
      shA = _cycle(const [170.0, 120.0], ph);
      elA = _cycle(const [20.0, 90.0], ph);
      shB = _cycle(const [120.0, 170.0], ph);
      elB = _cycle(const [90.0, 20.0], ph);
    } else if (!grounded) {
      if (_djTuck > 0) {
        // double jump: exaggerated because it isn't realistic — knees to the
        // chest, arms thrown ~160deg upward like pulling yourself skyward
        lean = 0;
        hipDy = 0;
        hipA = 85;
        kneeA = 130;
        hipB = 65;
        kneeB = 140;
        shA = 150;
        elA = 30;
        shB = 142;
        elB = 25;
      } else if (velocity.y < 0) {
        // takeoff -> apex (mocap): launch with legs extended (knee 170deg
        // interior = 10 bend), arms exploding to 120deg shoulder / 140deg
        // interior elbow; by the apex the hips draw to 30, knees to 50 bend
        // and the arms settle (80deg shoulder, 100deg interior elbow)
        final t = (1 + velocity.y / -jumpVelocity).clamp(0.0, 1.0); // 0 launch, 1 apex
        lean = _lerp(20, 8, t);
        hipDy = 0;
        hipA = _lerp(15, 30, t);
        kneeA = _lerp(10, 50, t);
        hipB = _lerp(-10, 5, t);
        kneeB = _lerp(12, 60, t);
        shA = _lerp(120, 80, t);
        elA = _lerp(40, 80, t);
        shB = _lerp(105, 70, t);
        elB = _lerp(45, 75, t);
      } else {
        // falling toward landing: hips fold to ~55, knees brace at 75 bend,
        // shoulders drop from the apex 80 to a forward 25, elbows to 60
        final v = (velocity.y / 650).clamp(0.0, 1.0);
        lean = _lerp(5, 18, v);
        hipDy = 0;
        hipA = _lerp(30, 50, v);
        kneeA = 75;
        hipB = -10;
        kneeB = 75;
        shA = _lerp(80, 25, v);
        elA = _lerp(80, 60, v);
        shB = _lerp(65, 15, v);
        elB = _lerp(75, 60, v);
      }
    } else if (_stumble > 0) {
      // landing absorb (mocap): torso 20deg, hip 55, knee 75 bend,
      // shoulder 25, elbow 120deg interior (60 bend), arms out for balance
      final k = (_stumble / 0.30).clamp(0.0, 1.0);
      lean = 20 * k + 4;
      hipDy = 5 * k;
      hipA = 55 * k + 8;
      kneeA = 75 * k + 10;
      hipB = -10;
      kneeB = 60 * k + 10;
      shA = 25;
      elA = 60;
      shB = 18;
      elB = 60;
    } else if (sliding) {
      // baseball slide (mocap): torso 45deg back, lead leg stretched OUT
      // ALONG the ground (hip 75 so the leg is nearly horizontal, knee 25
      // bend), rear leg folded underneath (hip -35, knee 115), elbows 90
      // and tucked in. The crouch comes from the leg geometry itself —
      // never from pushing the pelvis down, so the feet stay on the floor.
      lean = -45;
      hipDy = 0;
      hipA = 75;
      kneeA = 25;
      hipB = -35;
      kneeB = 115;
      shA = 25;
      elA = 90;
      shB = -30;
      elB = 90;
    } else if (_skidding) {
      // slide: torso ~45deg back against the motion, front leg extended,
      // back leg folded, arms trailing behind, centre of gravity very low
      final m = velocity.x.sign * (facingRight ? 1.0 : -1.0); // motion vs facing
      lean = -40 * m;
      hipDy = 7;
      hipA = 70 * m;
      kneeA = 15;
      hipB = -10 * m;
      kneeB = 110;
      // parkour-slide arms: front arm forward, back arm trailing, both bent
      shA = 30 * m;
      elA = 90;
      shB = -50 * m;
      elB = 90;
    } else if (moving) {
      // walk/run gait: keyframed contact -> passing cycle, arms counter-swing,
      // pelvis bobbing like an inverted pendulum. Cadence is tied to distance
      // travelled so the feet never skate.
      final stride = _lerp(_walkStride, _runStride, r);
      _gait += speed * dt / stride;
      // slow shuffles use a smaller stride amplitude
      final amp = (speed / walkSpeed).clamp(0.35, 1.0);

      double leg(List<double> w, List<double> rn, double off) =>
          _lerp(_cycle(w, _gait + off), _cycle(rn, _gait + off), r) * amp;
      hipA = leg(_walkHip, _runHip, 0);
      kneeA = _lerp(_cycle(_walkKnee, _gait), _cycle(_runKnee, _gait), r);
      hipB = leg(_walkHip, _runHip, 0.5);
      kneeB = _lerp(_cycle(_walkKnee, _gait + 0.5), _cycle(_runKnee, _gait + 0.5), r);
      shA = leg(_walkSh, _runSh, 0);
      shB = leg(_walkSh, _runSh, 0.5);
      // elbows swing with the arm — smooth sinusoidal pendulum, never a snap
      elA = _lerp(_cycle(_walkEl, _gait), _cycle(_runEl, _gait), r);
      elB = _lerp(_cycle(_walkEl, _gait + 0.5), _cycle(_runEl, _gait + 0.5), r);
      lean = _lerp(5, 12, r); // walk lean 5deg, run 10deg, edging to sprint 15
      hipDy = _cycle(const [0.5, -1.0, 0.5, -1.0], _gait) * (1 + r);
    } else {
      // athletic idle (mocap): 3deg forward lean, hips split ~5deg, knees at
      // 165deg interior (15 bend), shoulders 10deg forward with elbows at
      // 155deg interior (25 bend) so the hands hang at mid-thigh.
      // Breathing sways the arms.
      final breathe = math.sin(_idleT * 2.6);
      lean = 3 + breathe * 0.5;
      hipDy = 0;
      hipA = 5;
      kneeA = 15;
      hipB = -5;
      kneeB = 15;
      shA = 10;
      elA = 25 + breathe * 3;
      shB = 8;
      elB = 25 + breathe * 3;
    }

    // human joint limits
    hipA = hipA.clamp(_hipMin, _hipMax);
    hipB = hipB.clamp(_hipMin, _hipMax);
    kneeA = kneeA.clamp(_kneeMin, _kneeMax);
    kneeB = kneeB.clamp(_kneeMin, _kneeMax);
    shA = shA.clamp(_shMin, _shMax);
    shB = shB.clamp(_shMin, _shMax);
    elA = elA.clamp(_elMin, _elMax);
    elB = elB.clamp(_elMin, _elMax);

    // exponential smoothing keeps every state change seamless
    final k = 1 - math.exp(-22 * dt);
    _lean += (lean - _lean) * k;
    _hipDy += (hipDy - _hipDy) * k;
    _hipA += (hipA - _hipA) * k;
    _kneeA += (kneeA - _kneeA) * k;
    _hipB += (hipB - _hipB) * k;
    _kneeB += (kneeB - _kneeB) * k;
    _shA += (shA - _shA) * k;
    _elA += (elA - _elA) * k;
    _shB += (shB - _shB) * k;
    _elB += (elB - _elB) * k;
  }

  // -------------------------------------------------------------- render ---

  @override
  void render(Canvas canvas) {
    if (!alive) return;
    final f = facingRight ? 1.0 : -1.0;
    final cx = size.x / 2;
    final groundY = size.y;

    // stepping through the doorway: fade out and shrink into it
    final entering = _doorX != null && _enterT > 0;
    if (entering) {
      final p = (_enterT / enterDoorDuration).clamp(0.0, 1.0);
      canvas.saveLayer(null,
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 1 - p));
      canvas.translate(cx, groundY);
      canvas.scale(1 - 0.3 * p);
      canvas.translate(-cx, -groundY);
    }

    // bone direction from an angle measured off straight-down vertical,
    // positive = toward the facing direction
    Offset boneDir(double deg) =>
        Offset(math.sin(deg * _d2r) * f, math.cos(deg * _d2r));

    // pelvis height follows the support leg so planted feet meet the ground
    // (the inverted-pendulum rise and fall of the centre of gravity)
    double legExt(double hip, double knee) =>
        _thigh * math.cos(hip * _d2r) + _shin * math.cos((hip - knee) * _d2r);
    final support = math.max(legExt(_hipA, _kneeA), legExt(_hipB, _kneeB));
    // _hipDy may only LIFT the body (gait bob/flight) — pushing the pelvis
    // down would drive the planted foot through the floor
    final pelvisY = grounded
        ? (groundY - support + math.min(_hipDy, 0.0)).clamp(6.0, groundY - 4.0)
        : groundY - 17 + _hipDy;
    final pelvis = Offset(cx - _lean * _d2r * _torso * 0.5 * f, pelvisY);

    // torso leans from the pelvis; neck, shoulder & head ride on it
    final up = Offset(math.sin(_lean * _d2r) * f, -math.cos(_lean * _d2r));
    final neck = pelvis + up * _torso;
    final shoulder = pelvis + up * (_torso * 0.9);
    final headC = neck + up * (_headR + 1.5);

    // forward kinematics: knee = hip angle, foot = hip angle minus knee bend
    // (the shin folds backward); hand = shoulder angle plus elbow bend
    // (the forearm folds forward)
    Offset knee(double hip) => pelvis + boneDir(hip) * _thigh;
    Offset foot(double hip, double kneeBend) =>
        knee(hip) + boneDir(hip - kneeBend) * _shin;
    Offset elbow(double sh) => shoulder + boneDir(sh) * _uArm;
    Offset hand(double sh, double elBend) =>
        elbow(sh) + boneDir(sh + elBend) * _fArm;

    final ink = Paint()
      ..color = InkPalette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // far-side limbs drawn fainter for depth
    final inkFar = Paint()
      ..color = InkPalette.ink.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void limb(Offset a, Offset mid, Offset end, Paint paint) {
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(mid.dx, mid.dy)
        ..lineTo(end.dx, end.dy);
      canvas.drawPath(path, paint);
    }

    // small hand segment (0.3u) continuing the forearm line
    void handTick(double sh, double el, Paint paint) {
      final h = hand(sh, el);
      canvas.drawLine(h, h + boneDir(sh + el) * (0.3 * _u), paint);
    }

    // feet may never render below the floor line
    Offset floorClamp(Offset p) =>
        grounded && p.dy > groundY ? Offset(p.dx, groundY) : p;

    // far leg & arm first so the near ones draw on top
    final footB = floorClamp(foot(_hipB, _kneeB));
    limb(pelvis, knee(_hipB), footB, inkFar);
    limb(shoulder, elbow(_shB), hand(_shB, _elB), inkFar);
    handTick(_shB, _elB, inkFar);

    // spine: a subtle curve following the lean
    final spine = Path()
      ..moveTo(neck.dx, neck.dy)
      ..quadraticBezierTo(
          (neck.dx + pelvis.dx) / 2 + _lean * _d2r * 4 * f,
          (neck.dy + pelvis.dy) / 2,
          pelvis.dx,
          pelvis.dy);
    canvas.drawPath(spine, ink);

    final footA = floorClamp(foot(_hipA, _kneeA));
    limb(pelvis, knee(_hipA), footA, ink);
    limb(shoulder, elbow(_shA), hand(_shA, _elA), ink);
    handTick(_shA, _elA, ink);

    // little feet add a lot of readability
    canvas.drawLine(footA, footA + Offset(f * 3.2, 0), ink);
    canvas.drawLine(footB, footB + Offset(f * 3.2, 0), inkFar);

    // head
    canvas.drawCircle(headC, _headR + 2.2, ink);
    // eye dot (faces travel direction)
    canvas.drawCircle(headC + Offset(f * 2.8, -1),
        1.4, Paint()..color = InkPalette.ink);

    if (entering) canvas.restore();
  }
}
