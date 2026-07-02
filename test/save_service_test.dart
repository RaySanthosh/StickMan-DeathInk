import 'package:death_note/services/save_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveService.instance.init();
  });

  test('fresh save has only level 0 unlocked and no deaths', () {
    final save = SaveService.instance;
    expect(save.unlocked, 0);
    expect(save.totalDeaths, 0);
    expect(save.starsFor(0), 0);
    expect(save.bestTimeMs(0), isNull);
  });

  test('recordResult stores bests and unlocks the next level', () async {
    final save = SaveService.instance;
    await save.recordResult(
        level: 0, timeMs: 30000, deaths: 2, stars: 2, levelCount: 10);
    expect(save.unlocked, 1);
    expect(save.starsFor(0), 2);
    expect(save.bestTimeMs(0), 30000);
    expect(save.bestDeaths(0), 2);

    // worse run must not overwrite bests
    await save.recordResult(
        level: 0, timeMs: 50000, deaths: 5, stars: 1, levelCount: 10);
    expect(save.starsFor(0), 2);
    expect(save.bestTimeMs(0), 30000);

    // better run improves
    await save.recordResult(
        level: 0, timeMs: 20000, deaths: 0, stars: 3, levelCount: 10);
    expect(save.starsFor(0), 3);
    expect(save.bestTimeMs(0), 20000);
    expect(save.bestDeaths(0), 0);
  });

  test('recordDeath appends to the log and counts', () async {
    final save = SaveService.instance;
    await save.recordDeath(0, 'Fell off the page.');
    await save.recordDeath(0, 'Squished. Again.');
    await save.recordDeath(3, 'Cut short. Literally.');
    expect(save.totalDeaths, 3);
    expect(save.deathsOn(0), 2);
    expect(save.deathsOn(3), 1);
    final log = save.recentDeaths();
    expect(log.length, 3);
    expect(log.last.cause, 'Cut short. Literally.');
    expect(log.first.levelIndex, 0);
  });

  test('cloud progress merge keeps the better values', () async {
    final save = SaveService.instance;
    await save.recordResult(
        level: 0, timeMs: 30000, deaths: 2, stars: 2, levelCount: 10);
    await save.mergeProgress({
      'unlocked': 4,
      'level_0': {'stars': 3, 'timeMs': 25000, 'deaths': 0},
      'level_2': {'stars': 1, 'timeMs': 90000, 'deaths': 9},
    }, 10);
    expect(save.unlocked, 4);
    expect(save.starsFor(0), 3);
    expect(save.bestTimeMs(0), 25000);
    expect(save.starsFor(2), 1);

    // local better values survive a worse cloud snapshot
    await save.mergeProgress({
      'unlocked': 1,
      'level_0': {'stars': 1, 'timeMs': 99000, 'deaths': 9},
    }, 10);
    expect(save.unlocked, 4);
    expect(save.starsFor(0), 3);
    expect(save.bestTimeMs(0), 25000);
  });
}
