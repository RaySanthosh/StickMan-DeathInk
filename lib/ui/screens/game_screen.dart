import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/death_note_game.dart';
import '../../game/levels_data.dart';
import '../../game/scoring.dart';
import '../../services/firebase_service.dart';
import '../../services/save_service.dart';
import '../../theme.dart';
import '../widgets/notebook.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.levelIndex});

  final int levelIndex;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final DeathNoteGame game;
  String _cause = '';
  LevelResult? _result;

  @override
  void initState() {
    super.initState();
    game = DeathNoteGame(
      levelIndex: widget.levelIndex,
      onDeathOverlay: (cause) {
        setState(() => _cause = cause);
        game.overlays.add('death');
      },
      onCompleteOverlay: (result) {
        setState(() => _result = result);
        game.overlays.add('complete');
      },
    );
  }

  void _pause() {
    game.paused = true;
    game.clock.stop();
    game.overlays.add('pause');
  }

  void _resume() {
    game.overlays.remove('pause');
    game.paused = false;
    if (game.player.alive) game.clock.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: game,
        overlayBuilderMap: {
          'hud': (context, _) => _Hud(game: game, onPause: _pause),
          'pause': (context, _) => _PauseOverlay(
                onResume: _resume,
                onQuit: () => Navigator.of(context).pop(),
              ),
          'death': (context, _) => _DeathOverlay(
                cause: _cause,
                deaths: game.deaths,
                onRetry: () {
                  game.overlays.remove('death');
                  game.respawn();
                },
                onQuit: () => Navigator.of(context).pop(),
              ),
          'complete': (context, _) => _CompleteOverlay(
                result: _result!,
                onNext: () {
                  final next = _result!.levelIndex + 1;
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => GameScreen(levelIndex: next)));
                },
                onReplay: () {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) =>
                          GameScreen(levelIndex: _result!.levelIndex)));
                },
                onQuit: () => Navigator.of(context).pop(),
              ),
        },
        initialActiveOverlays: const ['hud'],
      ),
    );
  }
}

// ---------------------------------------------------------------- HUD

class _Hud extends StatefulWidget {
  const _Hud({required this.game, required this.onPause});

  final DeathNoteGame game;
  final VoidCallback onPause;

  @override
  State<_Hud> createState() => _HudState();
}

class _HudState extends State<_Hud> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
        const Duration(milliseconds: 100), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 6,
            left: 10,
            child: Row(
              children: [
                _RoundButton(
                  size: 44,
                  onDown: widget.onPause,
                  child: const Icon(Icons.pause, color: InkPalette.ink),
                ),
                const SizedBox(width: 10),
                Text(
                  'Ch.${game.levelIndex + 1} ${levels[game.levelIndex].name}',
                  style: hand(20, color: InkPalette.ink),
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 14,
            child: Text(
              '☠ ${game.deaths}   ${formatTime(game.clock.elapsedMilliseconds)}',
              style: hand(22, color: InkPalette.ink),
            ),
          ),
          // movement buttons
          Positioned(
            left: 18,
            bottom: 16,
            child: Row(
              children: [
                _RoundButton(
                  size: 72,
                  onDown: () => game.moveLeft = true,
                  onUp: () => game.moveLeft = false,
                  child: const Icon(Icons.arrow_back,
                      size: 34, color: InkPalette.ink),
                ),
                const SizedBox(width: 14),
                _RoundButton(
                  size: 72,
                  onDown: () => game.moveRight = true,
                  onUp: () => game.moveRight = false,
                  child: const Icon(Icons.arrow_forward,
                      size: 34, color: InkPalette.ink),
                ),
              ],
            ),
          ),
          Positioned(
            right: 22,
            bottom: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _RoundButton(
                  size: 64,
                  onDown: () {
                    game.pressSlide();
                    game.slideHeld = true;
                  },
                  onUp: () => game.slideHeld = false,
                  child:
                      Text('SLIDE', style: hand(16, color: InkPalette.ink)),
                ),
                const SizedBox(width: 12),
                _RoundButton(
                  size: 84,
                  onDown: () {
                    game.pressJump();
                    game.jumpHeld = true;
                  },
                  onUp: () => game.jumpHeld = false,
                  child:
                      Text('JUMP', style: hand(22, color: InkPalette.redInk)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.child,
    required this.onDown,
    this.onUp,
    required this.size,
  });

  final Widget child;
  final VoidCallback onDown;
  final VoidCallback? onUp;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp?.call(),
      onPointerCancel: (_) => onUp?.call(),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: InkPalette.paper.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(color: InkPalette.ink, width: 2.4),
        ),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------- overlays

class _OverlayCard extends StatelessWidget {
  const _OverlayCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: InkPalette.ink.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
        decoration: BoxDecoration(
          color: InkPalette.paper,
          border: Border.all(color: InkPalette.ink, width: 2.6),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(5),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume, required this.onQuit});

  final VoidCallback onResume;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return _OverlayCard(
      children: [
        Text('Paused', style: caveat(44)),
        const SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkButton(label: 'Resume', fontSize: 22, onTap: onResume),
            const SizedBox(width: 14),
            InkButton(label: 'Quit', fontSize: 22, onTap: onQuit),
          ],
        ),
      ],
    );
  }
}

class _DeathOverlay extends StatelessWidget {
  const _DeathOverlay({
    required this.cause,
    required this.deaths,
    required this.onRetry,
    required this.onQuit,
  });

  final String cause;
  final int deaths;
  final VoidCallback onRetry;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return _OverlayCard(
      children: [
        Text('✖ DEATH #$deaths', style: caveat(46, color: InkPalette.redInk)),
        const SizedBox(height: 4),
        Text('"$cause"', style: hand(24)),
        Text('…written in the Note.',
            style: hand(17, color: InkPalette.inkFaded)),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkButton(
                label: 'Try Again',
                fontSize: 22,
                color: InkPalette.redInk,
                onTap: onRetry),
            const SizedBox(width: 14),
            InkButton(label: 'Give Up', fontSize: 22, onTap: onQuit),
          ],
        ),
      ],
    );
  }
}

class _CompleteOverlay extends StatelessWidget {
  const _CompleteOverlay({
    required this.result,
    required this.onNext,
    required this.onReplay,
    required this.onQuit,
  });

  final LevelResult result;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final hasNext = result.levelIndex + 1 < levels.length &&
        result.levelIndex + 1 <= SaveService.instance.unlocked;
    return _OverlayCard(
      children: [
        Text('Chapter Complete!', style: caveat(44)),
        StarRow(stars: result.stars, size: 38),
        const SizedBox(height: 6),
        Text(
          'Time ${formatTime(result.timeMs)}   ·   ☠ ${result.deaths}',
          style: hand(22),
        ),
        if (FirebaseService.instance.isSignedIn) ...[
          const SizedBox(height: 4),
          Text(
            'Your latest run counts — it replaces your leaderboard entry.',
            textAlign: TextAlign.center,
            style: hand(15, color: InkPalette.inkFaded),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasNext) ...[
              InkButton(
                  label: 'Next ▶',
                  fontSize: 22,
                  color: InkPalette.redInk,
                  onTap: onNext),
              const SizedBox(width: 14),
            ],
            InkButton(label: 'Replay', fontSize: 22, onTap: onReplay),
            const SizedBox(width: 14),
            InkButton(label: 'Menu', fontSize: 22, onTap: onQuit),
          ],
        ),
      ],
    );
  }
}
