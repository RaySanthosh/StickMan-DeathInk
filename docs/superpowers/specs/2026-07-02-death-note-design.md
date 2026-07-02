# Death Note — Stickman Platformer (Design Spec)

Date: 2026-07-02 · Status: Approved by user ("go for it")

## Concept
A hardcore-but-fair stickman level platformer for Android built with Flutter + Flame.
The player guides a stickman through trap-filled levels. Every death is logged in the
"Death Note" — an in-app book listing each death with a darkly humorous cause.
Trap parameters reshuffle between attempts so runs can't be fully memorized.

Art direction: **ink-on-paper notebook aesthetic** — the whole game looks hand-drawn
inside a ruled notebook (paper texture, ruled lines, ink strokes, handwriting fonts).

## Platform & Stack
- Frontend: Flutter (stable 3.38), Flame engine for the game loop/rendering.
- Target: Android phone, landscape orientation, on-screen touch controls.
- Backend: Firebase free Spark tier — Anonymous Auth + Cloud Firestore.
- Offline-first: fully playable without internet or Firebase config; sync when available.
- Project: `C:\Santhosh\death_note`, package `com.santhosh.death_note`.

## Gameplay
- Controls: on-screen ◀ ▶ buttons + jump button. Double-jump, wall-slide and wall-jump.
- Physics: tile-based AABB collision (resolve X then Y), gravity, clamped fall speed.
- 10 hand-crafted levels across 2 worlds ("The Notebook" / "Red Ink"), tutorial → rage.
- Checkpoints mid-level (C tile). Exit door (E tile) completes the level.
- Death counter always visible; per-level timer.
- Stars: 3★ no deaths & under par time; 2★ ≤3 deaths or ≤1.5× par; 1★ completion.

## Traps (all kill on touch, each has a pool of death-cause messages)
| Tile | Trap | Per-attempt randomization |
|------|------|---------------------------|
| ^    | Spikes | none (static baseline) |
| s    | Saw blade | horizontal or vertical patrol, speed, phase |
| X    | Crusher | trigger distance, fall speed, reset delay |
| ~    | Vanishing platform | vanish delay, respawn delay |
| L    | Laser gate | on/off period, phase offset |

Randomization is seeded per attempt (reshuffles on every death/restart).

## Level format
ASCII grid strings in `lib/game/levels_data.dart`. Legend: `#` solid, `.` empty,
`S` start, `E` exit, `C` checkpoint, plus trap tiles above. Tile size 48 px,
fixed-resolution camera 960×540 following the player, clamped to level bounds.

## Screens (Flutter widgets, notebook theme)
1. Title screen — logo, Play, Death Note, Leaderboard, sound toggle.
2. Level select — grid with stars, locks, best time / deaths.
3. Game screen — Flame `GameWidget` + overlays: HUD (controls, deaths, timer),
   pause, death overlay (cause + witty line), level-complete (stars, stats).
4. Death Note book — every logged death: level, cause, count; totals page.
5. Leaderboard — per-level top list from Firestore (needs internet + config).
6. First-launch nickname dialog.

## Services
- `SaveService` (shared_preferences): unlocked levels, stars, best time/deaths,
  death log (aggregated counts + recent entries), sound on/off, nickname.
- `FirebaseService`: anonymous sign-in, submit best scores
  (`scores/{uid}_{level}` → nick, timeMs, deaths), sync progress (`users/{uid}`),
  fetch top-20 leaderboard per level. Detects placeholder config and degrades to
  offline silently. Real config arrives via `flutterfire configure` overwriting
  `lib/firebase_options.dart`.
- `AudioService`: synthesized WAV SFX (jump, death, checkpoint, win, click) via
  flame_audio; respects sound toggle.

## Accounts, ranking & FCM (revision 2026-07-02b, project `stickman-deadink`)
Two-tier identity:
- **Tier 1 — anonymous (no sign-in):** on first launch, silent
  `signInAnonymously`. Immediately write `users/{uid}` with `isAnonymous:true`
  and the FCM token. Player can play everything; scores stay local only.
- **Tier 2 — Google upgrade:** a "Sign in with Google" action calls
  `linkWithCredential` (preserves the anon uid and all progress), captures the
  **email only**, then a **name + country selector** screen fills the profile.
  Only Tier-2 players appear on the global leaderboard.

Firestore data model:
- `users/{uid}`: `isAnonymous`, `email?`, `name?`, `country?` (ISO code),
  `fcmToken?`, `createdAt`, `updatedAt`.
- `scores/{uid}_{level}`: `uid`, `level` (0–9), `deaths`, `timeMs`, `name`,
  `country`, `updatedAt`. One row per player per chapter.

Ranking:
- The local death log (witty causes) is **never uploaded** — only `deaths` and
  `timeMs` per chapter go to the cloud.
- **Keep-best**: a score row is overwritten only when the new run has fewer
  deaths (tie-break faster `timeMs`).
- Board query per chapter: `scores where level == N orderBy deaths, timeMs`,
  showing name + country flag.

FCM: `firebase_messaging` — request notification permission (Android 13+
`POST_NOTIFICATIONS`), store token on the user doc at anon sign-in, refresh on
rotation.

Dependencies to add: `firebase_messaging`, `google_sign_in` (pin ^6.2.x),
country list bundled in-app (no extra dependency). Security rules: owner-only
`users`, signed-in read + own-row write on `scores` (see README).

## Error handling
- No Firebase config / no network → all cloud features hidden or show
  "offline" note; game never blocks. Anonymous play is always available.
- Save writes are fire-and-forget with try/catch; corrupted prefs reset safely.

## Testing
- Unit tests: physics helpers (AABB resolution), star rating, save round-trip,
  level data validation (every level has S and E, is rectangular).
- `flutter analyze` clean; release APK build as final gate.

## Known notes
- "Death Note" is an existing anime trademark — fine for personal use; rename
  before any Play Store release.
