import 'package:death_note/game/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('starRating', () {
    test('deathless under par earns 3 stars', () {
      expect(starRating(timeMs: 20000, deaths: 0, parSeconds: 25), 3);
    });

    test('deathless but slow earns 2 stars (few deaths rule)', () {
      expect(starRating(timeMs: 60000, deaths: 0, parSeconds: 25), 2);
    });

    test('few deaths earns 2 stars', () {
      expect(starRating(timeMs: 60000, deaths: 3, parSeconds: 25), 2);
    });

    test('fast but many deaths earns 2 stars', () {
      expect(starRating(timeMs: 30000, deaths: 10, parSeconds: 25), 2);
    });

    test('slow and deathful earns 1 star', () {
      expect(starRating(timeMs: 60000, deaths: 10, parSeconds: 25), 1);
    });
  });

  group('formatTime', () {
    test('formats minutes, seconds and tenths', () {
      expect(formatTime(0), '0:00.0');
      expect(formatTime(61234), '1:01.2');
      expect(formatTime(9900), '0:09.9');
    });
  });
}
