# Roadmap & status

_Last updated: 2026-11-02_

## Current state

Tested on a phone by the owner: generation, multi-touch drag, crossing detection, levels
1–11, solved card, Reshuffle / New puzzle, olive light/dark themes.

Added 2026-11-02 (owner tried these on the phone and liked them):

- **Persistence** (`lib/game/store.dart`): theme mode, current level, mute, unlocked level.
  Level 1 starts open; beating the highest unlocked level unlocks the next. Locked levels
  show a lock in the picker. "Same level" is always available.
- **Solve animation**: lines and dots turn green in a wave from the last-moved dot (dots
  pop slightly as it passes), then a soft spark burst; the solved card appears at ~1.3 s.
- **Sound** (`lib/game/sfx.dart`, `audioplayers`): soft click on grab, two-note chime on
  solve, mute toggle in the HUD. Sounds are synthesized by `tool/gen_sounds.dart` into
  `assets/sounds/`. Audio mixes with the user's music and respects the iOS silent switch.
- **Store prep**:
  - Icon drawn by `tool/gen_icon_test.dart` (run with `flutter test tool/gen_icon_test.dart`)
    into `assets/icon/`, applied with `dart run flutter_launcher_icons` (adaptive +
    monochrome on Android, iOS, web).
  - Splash with `dart run flutter_native_splash:create` (light/dark, Android 12, web).
  - Label "Untangle" on Android, iOS and web. App id `com.basdekis.untangle`.
  - Draft store texts and a screenshot list in [store_listing.md](store_listing.md).

## Purpose (from the owner, 2026-11-02)

A personal app, for playing while travelling, installed directly (adb or APK file).
Later the same day the owner decided to **publish it free on Google Play** too, for anyone.
Owner tried a store app with the same name and disliked its ads and paywalls; keep this
one free of both.

Owner tried persistence, solve animation, sound, icon and splash on the phone and liked
all of it (2026-11-02). Icon graph enlarged 20% afterwards.

## Next tasks

1. **Publish on Google Play** (free): in progress, see the Progress section of
   [PLAY_STORE.md](PLAY_STORE.md). Signing, privacy policy, graphics and screenshots are
   done; the developer account exists and waits for Google's identity check. Next: phone
   verification, create the app, listing + forms, upload the `.aab`, 12-tester closed test.
2. Install on a second phone (adb over USB, or send the release APK).

## Parked: what does "improving a level" mean?

Owner said to leave this for now (2026-11-02). Earlier proposals: neatness stars (1–3)
for how tidy the solved layout is, and/or a solved count per level. Not by time or moves.

## Rejected by the owner (don't propose again)

- Best time / fewest moves per level, any time-based challenge or scoring.
- Daily puzzle and streaks.
- Undo. Hints.
- Extra game modes (time attack, zen).
- Orange/blue/bright-red palette during play (replaced by the olive palette in CLAUDE.md).
