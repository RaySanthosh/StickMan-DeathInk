import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DeathEntry {
  DeathEntry({required this.levelIndex, required this.cause, required this.time});

  final int levelIndex;
  final String cause;
  final DateTime time;

  Map<String, dynamic> toJson() => {
        'l': levelIndex,
        'c': cause,
        't': time.toIso8601String(),
      };

  static DeathEntry? fromJson(Map<String, dynamic> json) {
    final level = json['l'];
    final cause = json['c'];
    final time = DateTime.tryParse(json['t'] as String? ?? '');
    if (level is! int || cause is! String || time == null) return null;
    return DeathEntry(levelIndex: level, cause: cause, time: time);
  }
}

/// Local persistence: progress, stats, the death log and settings.
class SaveService {
  SaveService._();

  static final SaveService instance = SaveService._();
  static const int maxLogEntries = 100;

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---- progress ----
  int get unlocked => _prefs.getInt('unlocked') ?? 0;

  int starsFor(int level) => _prefs.getInt('stars_$level') ?? 0;
  int? bestTimeMs(int level) => _prefs.getInt('bestTime_$level');
  int? bestDeaths(int level) => _prefs.getInt('bestDeaths_$level');

  /// Records a completed level; returns true if any best improved.
  Future<bool> recordResult({
    required int level,
    required int timeMs,
    required int deaths,
    required int stars,
    required int levelCount,
  }) async {
    var improved = false;
    if (stars > starsFor(level)) {
      await _prefs.setInt('stars_$level', stars);
      improved = true;
    }
    final time = bestTimeMs(level);
    if (time == null || timeMs < time) {
      await _prefs.setInt('bestTime_$level', timeMs);
      improved = true;
    }
    final best = bestDeaths(level);
    if (best == null || deaths < best) {
      await _prefs.setInt('bestDeaths_$level', deaths);
      improved = true;
    }
    if (level + 1 > unlocked && level + 1 < levelCount) {
      await _prefs.setInt('unlocked', level + 1);
    }
    return improved;
  }

  // ---- the death log ----
  int get totalDeaths => _prefs.getInt('deaths_total') ?? 0;
  int deathsOn(int level) => _prefs.getInt('deaths_l$level') ?? 0;

  Future<void> recordDeath(int level, String cause) async {
    await _prefs.setInt('deaths_total', totalDeaths + 1);
    await _prefs.setInt('deaths_l$level', deathsOn(level) + 1);
    final log = recentDeaths()..add(DeathEntry(levelIndex: level, cause: cause, time: DateTime.now()));
    while (log.length > maxLogEntries) {
      log.removeAt(0);
    }
    await _prefs.setString('death_log', jsonEncode(log.map((e) => e.toJson()).toList()));
  }

  List<DeathEntry> recentDeaths() {
    final raw = _prefs.getString('death_log');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(DeathEntry.fromJson)
          .whereType<DeathEntry>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---- settings ----
  bool get soundOn => _prefs.getBool('sound') ?? true;
  Future<void> setSoundOn(bool value) => _prefs.setBool('sound', value);

  String get nickname => _prefs.getString('nickname') ?? '';
  Future<void> setNickname(String value) => _prefs.setString('nickname', value);

  // ---- cloud sync helpers ----
  Map<String, dynamic> progressSnapshot(int levelCount) => {
        'unlocked': unlocked,
        'totalDeaths': totalDeaths,
        for (var i = 0; i < levelCount; i++)
          if (starsFor(i) > 0)
            'level_$i': {
              'stars': starsFor(i),
              'timeMs': bestTimeMs(i),
              'deaths': bestDeaths(i),
            },
      };

  /// Merges cloud progress into local (keeps whichever is better).
  Future<void> mergeProgress(Map<String, dynamic> cloud, int levelCount) async {
    final cloudUnlocked = cloud['unlocked'];
    if (cloudUnlocked is int && cloudUnlocked > unlocked) {
      await _prefs.setInt('unlocked', cloudUnlocked.clamp(0, levelCount - 1));
    }
    for (var i = 0; i < levelCount; i++) {
      final data = cloud['level_$i'];
      if (data is! Map<String, dynamic>) continue;
      final stars = data['stars'];
      final timeMs = data['timeMs'];
      final deaths = data['deaths'];
      if (stars is int && stars > starsFor(i)) await _prefs.setInt('stars_$i', stars);
      final localTime = bestTimeMs(i);
      if (timeMs is int && (localTime == null || timeMs < localTime)) {
        await _prefs.setInt('bestTime_$i', timeMs);
      }
      final localDeaths = bestDeaths(i);
      if (deaths is int && (localDeaths == null || deaths < localDeaths)) {
        await _prefs.setInt('bestDeaths_$i', deaths);
      }
    }
  }
}
