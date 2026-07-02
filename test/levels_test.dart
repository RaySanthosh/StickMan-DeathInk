import 'package:death_note/game/levels_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('level data integrity', () {
    test('there are 10 levels across 2 worlds', () {
      expect(levels.length, 10);
      expect(levels.where((l) => l.world == 1).length, 5);
      expect(levels.where((l) => l.world == 2).length, 5);
    });

    for (final level in levels) {
      group(level.name, () {
        test('grid is rectangular and 12 rows tall', () {
          expect(level.rows.length, 12);
          for (final row in level.rows) {
            expect(row.length, level.cols,
                reason: 'row "${row.substring(0, 10)}..." has wrong width');
          }
        });

        test('has exactly one start and one exit', () {
          final all = level.rows.join();
          expect('S'.allMatches(all).length, 1);
          expect('E'.allMatches(all).length, 1);
        });

        test('uses only known tiles', () {
          final all = level.rows.join();
          expect(RegExp(r'^[#.SEC\^sX~L!dFvHw]+$').hasMatch(all), isTrue);
        });

        test('start and exit stand on solid ground', () {
          for (final marker in ['S', 'E']) {
            final row = level.rows.indexWhere((r) => r.contains(marker));
            final col = level.rows[row].indexOf(marker);
            expect(level.rows[row + 1][col], '#',
                reason: '$marker at ($col,$row) must have ground below');
          }
        });

        test('traps hang from or rest on sensible tiles', () {
          for (var r = 0; r < level.rowCount; r++) {
            for (var c = 0; c < level.cols; c++) {
              final ch = level.rows[r][c];
              if (ch == 'X') {
                expect(level.rows[r - 1][c], '#',
                    reason: 'crusher at ($c,$r) needs a ceiling above');
              }
              if (ch == '^') {
                expect(level.rows[r + 1][c], anyOf('#', '^'),
                    reason: 'spike at ($c,$r) needs support below');
              }
              if (ch == '!' || ch == 'd') {
                expect(level.rows[r + 1][c], '#',
                    reason: '$ch at ($c,$r) needs solid ground below');
              }
              if (ch == 'v') {
                expect(level.rows[r - 1][c], '#',
                    reason: 'barbs at ($c,$r) need a ceiling above');
              }
              if (ch == 'H') {
                expect(level.rows[r - 1][c], anyOf('#', 'H'),
                    reason: 'rope at ($c,$r) must hang from something');
              }
              if (ch == 'w') {
                final neighbors = [
                  if (r > 0) level.rows[r - 1][c],
                  if (r + 1 < level.rowCount) level.rows[r + 1][c],
                  if (c > 0) level.rows[r][c - 1],
                  if (c + 1 < level.cols) level.rows[r][c + 1],
                ];
                expect(neighbors, contains('#'),
                    reason: 'rail saw at ($c,$r) needs a platform to ride');
              }
            }
          }
        });
      });
    }
  });
}
