import 'package:flutter/material.dart';

import '../../game/levels_data.dart';
import '../../game/scoring.dart';
import '../../services/save_service.dart';
import '../../theme.dart';
import '../widgets/notebook.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  @override
  Widget build(BuildContext context) {
    final save = SaveService.instance;
    return NotebookPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: InkPalette.ink),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Text('Chapters', style: caveat(42)),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                for (var world = 1; world <= worldNames.length; world++) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    child: Text('World $world — ${worldNames[world - 1]}',
                        style: hand(24,
                            color: world == 2
                                ? InkPalette.redInk
                                : InkPalette.ink)),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < levels.length; i++)
                        if (levels[i].world == world)
                          _LevelCard(
                            index: i,
                            unlocked: i <= save.unlocked,
                            onPlay: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => GameScreen(levelIndex: i)),
                              );
                              if (mounted) setState(() {});
                            },
                          ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.index,
    required this.unlocked,
    required this.onPlay,
  });

  final int index;
  final bool unlocked;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final save = SaveService.instance;
    final level = levels[index];
    final bestTime = save.bestTimeMs(index);
    return GestureDetector(
      onTap: unlocked ? onPlay : null,
      child: Opacity(
        opacity: unlocked ? 1 : 0.45,
        child: Container(
          width: 168,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: InkPalette.paper,
            border: Border.all(color: InkPalette.ink, width: 2),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(3),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: InkPalette.ink.withValues(alpha: 0.15),
                offset: const Offset(2, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Ch.${index + 1}',
                      style: caveat(24, color: InkPalette.redInk)),
                  const Spacer(),
                  if (!unlocked)
                    const Icon(Icons.lock, size: 18, color: InkPalette.ink)
                  else
                    StarRow(stars: save.starsFor(index), size: 17),
                ],
              ),
              Text(level.name, style: hand(20)),
              const SizedBox(height: 2),
              Text(
                unlocked
                    ? (bestTime == null
                        ? (index == 0 ? 'Tip: tap jump twice!' : 'Unwritten…')
                        : 'Best ${formatTime(bestTime)} · ☠ ${save.deathsOn(index)}')
                    : 'Locked',
                style: hand(15, color: InkPalette.inkFaded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
