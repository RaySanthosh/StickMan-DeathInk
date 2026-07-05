import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// System-tray taunts in the game's cocky Shinigami voice, fired after key
/// events (sign-in, chapter clear, top-3, personal best, full clear).
///
/// Local notifications, not server pushes — every trigger happens while the
/// app is running, so no Cloud Function / paid plan is needed.
/// Anime proper nouns are swapped out (same trademark rule as taunts.dart).
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _rng = Random();
  bool _ready = false;

  Future<void> init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications init failed: $e');
    }
  }

  Future<void> _show(String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _rng.nextInt(1 << 31),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'deadink',
            'Dead Ink',
            channelDescription: 'Taunts from the Note',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Notification failed: $e');
    }
  }

  /// After Google sign-in + profile save.
  Future<void> welcome(String name) => _show(
        '🖤 Welcome to the Note, $name.',
        'You just sold your soul to the game... officially.\n'
        "Your name is now written.\nDon't die too fast, gangster.",
      );

  /// Final chapter cleared.
  Future<void> gameCompleted() => _show(
        '🏆 DEAD INK COMPLETE',
        'You actually cleared every chapter?\n'
        'The Shinigami dropped their apples.\n'
        "You're not just a player anymore... you're a certified legend, "
        'gangster.\nNow go flex on everyone.',
      );

  /// Landed in the top 3 after a score upload. [rank] is 1-based.
  Future<void> topRank(int rank) => switch (rank) {
        1 => _show(
            '👑 LEADERBOARD',
            'You just took the #1 spot.\nThe throne is yours, King.\n'
            'All the other mortals are beneath you.\n'
            'Rule it like a real gangster.',
          ),
        2 => _show(
            '🥈 LEADERBOARD',
            '#2 spot secured.\nNot bad, gangster. '
            "But we both know you're coming for that #1.\nKeep cooking.",
          ),
        _ => _show(
            '🥉 LEADERBOARD',
            'You cracked the Top 3.\nThe underworld is watching.\n'
            'Real ones recognize real ones.\nStay dangerous.',
          ),
      };

  static const _bestLines = [
    'The Note respects you... for once.',
    'Look at you, moving like a boss.',
    "From dying 100 times to owning the board. That's growth, king.",
    "The other players just got written in the notebook. You're still breathing.",
  ];

  /// Beat your own record.
  Future<void> personalBest() =>
      _show('🔥 NEW PERSONAL BEST', _bestLines[_rng.nextInt(_bestLines.length)]);

  /// Ordinary chapter clear (no rank / best to brag about).
  Future<void> chapterCleared() => _show(
        '☠ Chapter cleared',
        'Cleared. For now.\nThe notebook almost had your name. Almost.',
      );
}
