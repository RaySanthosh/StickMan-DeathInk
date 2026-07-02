import 'package:flutter/material.dart';

import '../../services/audio_service.dart';
import '../../services/firebase_service.dart';
import '../../services/save_service.dart';
import '../../theme.dart';
import '../widgets/notebook.dart';
import 'death_note_screen.dart';
import 'leaderboard_screen.dart';
import 'level_select_screen.dart';
import 'profile_screen.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  Future<void> _play() async {
    if (SaveService.instance.nickname.isEmpty) {
      await _askNickname();
    }
    if (!mounted) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const LevelSelectScreen()));
  }

  Future<void> _askNickname() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign the Note', style: caveat(34)),
        content: TextField(
          controller: controller,
          maxLength: 14,
          style: hand(22),
          decoration: InputDecoration(
            hintText: 'Your name, victim…',
            hintStyle: hand(20, color: InkPalette.inkFaded),
          ),
        ),
        actions: [
          InkButton(
            label: 'Sign',
            fontSize: 20,
            onTap: () {
              final name = controller.text.trim();
              SaveService.instance
                  .setNickname(name.isEmpty ? 'Stickman' : name);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDeaths = SaveService.instance.totalDeaths;
    return NotebookPage(
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('DEATH NOTE',
                    style: caveat(76, color: InkPalette.redInk)),
                Text('every death gets written down',
                    style: hand(20, color: InkPalette.inkFaded)),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    InkButton(
                        label: '▶  Play',
                        color: InkPalette.redInk,
                        onTap: _play),
                    InkButton(
                        label: 'The Note',
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const DeathNoteScreen()))),
                    InkButton(
                        label: 'Leaderboard',
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const LeaderboardScreen()))),
                    InkButton(
                        label: FirebaseService.instance.isSignedIn
                            ? 'Profile ✓'
                            : 'Sign in',
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const ProfileScreen()));
                          if (mounted) setState(() {});
                        }),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 12,
            child: IconButton(
              iconSize: 30,
              color: InkPalette.ink,
              icon: Icon(SaveService.instance.soundOn
                  ? Icons.volume_up
                  : Icons.volume_off),
              onPressed: () async {
                await SaveService.instance
                    .setSoundOn(!SaveService.instance.soundOn);
                AudioService.instance.click();
                setState(() {});
              },
            ),
          ),
          if (totalDeaths > 0)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Text(
                '☠ $totalDeaths deaths recorded in the Note',
                textAlign: TextAlign.center,
                style: hand(18, color: InkPalette.inkFaded),
              ),
            ),
        ],
      ),
    );
  }
}
