import 'package:flutter/material.dart';

import '../../game/levels_data.dart';
import '../../services/save_service.dart';
import '../../theme.dart';
import '../widgets/notebook.dart';

/// The Note itself: every recorded death, latest first.
class DeathNoteScreen extends StatelessWidget {
  const DeathNoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final save = SaveService.instance;
    final entries = save.recentDeaths().reversed.toList();
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
              Text('The Death Note', style: caveat(42, color: InkPalette.redInk)),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Text('☠ total: ${save.totalDeaths}', style: hand(24)),
              ),
            ],
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'No deaths yet.\nThe Note is hungry…',
                      textAlign: TextAlign.center,
                      style: hand(26, color: InkPalette.inkFaded),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(70, 4, 24, 16),
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final entry = entries[i];
                      final levelName =
                          entry.levelIndex < levels.length
                              ? levels[entry.levelIndex].name
                              : '?';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RichText(
                          text: TextSpan(
                            style: hand(21),
                            children: [
                              TextSpan(
                                text: 'Ch.${entry.levelIndex + 1} $levelName — ',
                                style: hand(21, color: InkPalette.inkFaded),
                              ),
                              TextSpan(
                                text: entry.cause,
                                style: hand(21, color: InkPalette.redInk),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
