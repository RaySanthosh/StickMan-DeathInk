/// Star rating for a completed level.
/// 3★ deathless and under par, 2★ few deaths or reasonably fast, 1★ otherwise.
int starRating({
  required int timeMs,
  required int deaths,
  required double parSeconds,
}) {
  if (deaths == 0 && timeMs <= parSeconds * 1000) return 3;
  if (deaths <= 3 || timeMs <= parSeconds * 1500) return 2;
  return 1;
}

class LevelResult {
  const LevelResult({
    required this.levelIndex,
    required this.timeMs,
    required this.deaths,
    required this.stars,
  });

  final int levelIndex;
  final int timeMs;
  final int deaths;
  final int stars;
}

String formatTime(int ms) {
  final totalSeconds = ms ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  final tenths = (ms % 1000) ~/ 100;
  return '$minutes:${seconds.toString().padLeft(2, '0')}.$tenths';
}
