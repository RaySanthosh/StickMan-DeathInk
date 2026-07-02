import 'package:flutter/material.dart';

import '../../game/levels_data.dart';
import '../../game/scoring.dart';
import '../../services/firebase_service.dart';
import '../../theme.dart';
import '../widgets/notebook.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _level = 0;
  late Future<List<ScoreEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = FirebaseService.instance.fetchLeaderboard(_level);
  }

  void _pick(int level) {
    setState(() {
      _level = level;
      _future = FirebaseService.instance.fetchLeaderboard(level);
    });
  }

  @override
  Widget build(BuildContext context) {
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
              Text('Leaderboard', style: caveat(42)),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: DropdownButton<int>(
                  value: _level,
                  style: hand(20),
                  onChanged: (v) => _pick(v ?? 0),
                  items: [
                    for (var i = 0; i < levels.length; i++)
                      DropdownMenuItem(
                          value: i,
                          child: Text('Ch.${i + 1} ${levels[i].name}')),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: !FirebaseService.instance.available
                ? Center(
                    child: Text(
                      'Playing offline.\nConnect Firebase to duel the world.',
                      textAlign: TextAlign.center,
                      style: hand(24, color: InkPalette.inkFaded),
                    ),
                  )
                : FutureBuilder<List<ScoreEntry>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: InkPalette.redInk));
                      }
                      final scores = snapshot.data!;
                      if (scores.isEmpty) {
                        return Center(
                          child: Text('No one has survived this chapter yet.',
                              style: hand(24, color: InkPalette.inkFaded)),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(70, 4, 24, 16),
                        itemCount: scores.length,
                        itemBuilder: (context, i) {
                          final s = scores[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: Text('${i + 1}.',
                                      style: caveat(24,
                                          color: i == 0
                                              ? InkPalette.gold
                                              : InkPalette.ink)),
                                ),
                                Expanded(
                                    child:
                                        Text(s.nickname, style: hand(22))),
                                Text(
                                    '${formatTime(s.timeMs)}  ·  ☠ ${s.deaths}',
                                    style:
                                        hand(20, color: InkPalette.inkFaded)),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
