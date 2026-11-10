# Roadmap & status

_Last updated: 2026-11-04_

## Goal

Free on Google Play, **no ads, no paywalls, no data collected**.

## Current state

Tried on a phone by the owner and liked: generation, multi-touch drag, crossing detection,
levels 1–11, solved card, olive light/dark themes, persistence (theme, level, unlocked,
mute), solve animation, sound with mute, icon and splash.

- **Persistence** (`lib/game/store.dart`): level 1 starts open; beating the highest
  unlocked level unlocks the next. Locked levels show a lock in the picker.
- **Solve animation**: green wave from the last-moved dot, then a soft spark burst; the
  solved card appears at ~1.3 s.
- **Sound** (`lib/game/sfx.dart`): click on grab, chime on solve. Synthesized by
  `tool/gen_sounds.dart` into `assets/sounds/`. Mixes with music, respects iOS silent switch.
- **Store prep**: icon by `tool/gen_icon_test.dart` (`flutter test tool/gen_icon_test.dart`),
  applied with `dart run flutter_launcher_icons`; splash with
  `dart run flutter_native_splash:create`. App id `com.basdekis.untangle`. Store texts in
  [store_listing.md](store_listing.md).

Added 2026-11-03 from the owner's play notes, **not yet tried on a phone**:

- Reshuffle / New puzzle ask before discarding progress once a dot was moved (they sat
  under the board and got hit by accident).
- **Pinch zoom** (two fingers on empty board; dots keep their size; one finger pans when
  zoomed; fit button) and **full screen** (bottom-bar button; Back exits).
- The puzzle in progress is saved and restored if the OS kills the app; the timer pauses
  in the background.
- A grabbed dot keeps its offset from the finger instead of jumping under it.
- **Group move**: hold empty board 0.5 s, circle dots, drag any of them to move all. The
  next touch that isn't on a selected dot clears the selection.
- On solve the view eases out to the whole board.

## Next tasks

1. **Publish on Google Play**: see "Current state" and "Next steps" in
   [PLAY_STORE.md](PLAY_STORE.md). Closed test (12 testers) **sent for Google review
   2026-11-04**. Next: send the opt-in link once approved, 14 days of testing, apply for
   production.
2. **Publish on F-Droid**: MIT license, fastlane metadata and build recipe added
   2026-11-10. Next: owner opens the merge request on fdroiddata, see
   [FDROID.md](FDROID.md).
3. Install on a second phone (adb over USB, or send the release APK).

## Ideas not picked yet

- Keep the screen awake while playing.
- Colour-blind-friendly crossing lines (thicker or dashed).

## Parked: what does "improving a level" mean?

Owner said to leave this for now. Earlier proposals: neatness stars (1–3) for how tidy the
solved layout is, and/or a solved count per level. Not by time or moves.

## Rejected by the owner (don't propose again)

- Best time / fewest moves per level, any time-based challenge or scoring.
- Daily puzzle and streaks.
- Undo. Hints.
- Extra game modes (time attack, zen).
- Orange/blue/bright-red palette during play (replaced by the olive palette in CLAUDE.md).
