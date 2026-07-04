import 'dart:math';

/// Taunts shown on death, chapter clear, and full-game clear.
///
/// Note: proper nouns from the Death Note anime (Ryuk, Light Yagami, L, the
/// "Death Note" itself) were swapped for generic equivalents to keep the app
/// clear of Shueisha's trademark. "Shinigami" is a common word and kept.
class Taunts {
  Taunts._();

  static final _rng = Random();

  // ---- death ----
  static const _generalDeath = [
    'Pathetic. Another name written in the Note.',
    'You died like the worthless worm you are.',
    'Even the Shinigami are laughing at how bad you are.',
    'Death looks good on you. Too bad you keep coming back.',
    'The Shinigami are betting on how many more times you fail.',
    'Congratulations, you made the notebook again.',
    'Was that really your best? How embarrassing.',
    'A god of death would be disappointed. I am just impressed by the incompetence.',
  ];

  static const _spikeDeath = [
    'Impaled like the amateur you are. Predictable.',
    'Sliced, diced, and thoroughly humiliated.',
    'The traps have claimed another fool.',
    'Sharp objects 1 — You 0.',
  ];

  static const _dartDeath = [
    'Turned into a pincushion. Elegant.',
    'Darts do not miss. You do.',
    'Bullseye. Too bad it was on your corpse.',
  ];

  static const _fallDeath = [
    'Gravity wins again, genius.',
    'Falling to your death? How original.',
    'The abyss called. It wants you to stay.',
  ];

  /// Picks a death taunt. High death counts unlock escalating roasts;
  /// otherwise a cause-flavoured or general taunt. [causeKind] is one of
  /// 'spike', 'dart', 'fall', or anything else for general.
  static String pickDeath(int deaths, String causeKind) {
    if (deaths >= 200) return 'Even gods are tired of watching you die.';
    if (deaths >= 100) return 'The Note is running out of pages because of you.';
    if (deaths >= 50) {
      return "At this point I'm keeping you alive out of pity.";
    }
    final pool = switch (causeKind) {
      'spike' => _spikeDeath,
      'dart' => _dartDeath,
      'fall' => _fallDeath,
      _ => _generalDeath,
    };
    return pool[_rng.nextInt(pool.length)];
  }

  // ---- chapter clear ----
  static const _clear = [
    'Not bad... for a human. Chapter complete.',
    "You barely scraped by. Don't let it go to your head.",
    'The notebook almost had your name. Almost.',
    'A Shinigami must be watching over your worthless soul.',
    'Cleared. For now.',
    'You survived... this time.',
    'Impressive. For someone with your skill level.',
    'The death gods are mildly disappointed you did not die.',
    "Congratulations, mortal. You didn't completely embarrass yourself.",
    'One more chapter stained with your sweat and tears.',
    'I expected you to die 20 more times. Color me surprised.',
    'You actually did it? Miracles still happen, huh?',
  ];

  static String pickClear() => _clear[_rng.nextInt(_clear.length)];

  // ---- full game clear ----
  static const ending =
      'Look at you. All chapters cleared.\n\n'
      'You really thought this was the end?\n\n'
      'The real game begins now...\n\n'
      'See you in New Game+, loser.';
}
