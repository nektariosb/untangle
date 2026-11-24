# Roadmap & status

_Last updated: 2026-11-24_

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

- New puzzle asks before discarding progress once a dot was moved (it got hit by
  accident).
- **Pinch zoom** (two fingers on empty board; dots keep their size; one finger pans when
  zoomed; fit button) and **full screen** (HUD button; Back exits).
- The puzzle in progress is saved and restored if the OS kills the app; the timer pauses
  in the background.
- A grabbed dot keeps its offset from the finger instead of jumping under it.
- **Group move**: hold empty board 0.5 s, circle dots, drag any of them to move all. The
  next touch that isn't on a selected dot clears the selection.
- On solve the view eases out to the whole board.

Added 2026-11-24 because level 11 got too easy, **not yet tried on a phone**:

- **Levels 12–20, mesh puzzles** (25 → 81 dots): random triangulated dots instead of
  lines, so no regular pattern. They start **scattered** over the board, not on a circle.
  An existing player must beat level 11 once more to unlock 12.
- **Optional time limit** (switch at the top of the level sheet and in ⚙, off by
  default): your average of the last 5 solves on that level minus 10%; a size estimate
  the first time. Counts down in the HUD, then shows "+0:12" in terracotta. You can
  still finish; the solved card says "You beat the time limit" or "Time limit was …".
  The clock starts at the first dot grab, so looking and zooming are free.
- Tried on the phone the same day, then changed from the owner's notes:
  - **No bottom bar**, more board. One HUD row: level | 🎲 New puzzle | full screen |
    ⚙ menu (Dark theme, Sound, Time limit, Hide info in full screen).
  - **Reshuffle removed**: to the player it felt the same as New puzzle.
  - Crossings chip floats on the board's top-right corner.
  - The instructions box closes on tap, without starting the clock.
  - **Hide info in full screen** (⚙): only the exit button stays.
  - Debug builds install as "Untangle Dev" (`com.basdekis.untangle.dev`), next to the
    Play version.
- Tuning knobs if it's too hard or too easy: dot counts and the edge-drop ratio
  (1/5) in `levels.dart` / `Puzzle.generateMesh`, the 10% in `Levels.limit`.
- Store texts (store_listing.md, fastlane) updated; **the Play Console listing still
  has the old text**, so update it with the next release.

## Next tasks

1. **Publish on Google Play**: see "Current state" and "Next steps" in
   [PLAY_STORE.md](PLAY_STORE.md). Closed test (12 testers × 14 days) done.
   **Applied for production access 2026-11-23**, waiting for Google (usually ≤ 7 days).
   Next: production release.
2. **Publish on F-Droid**: MIT license, fastlane metadata and build recipe added
   2026-11-10. Merge request !56687 closed the same day: F-Droid wants 3+ months of
   maintenance. **Resubmit after 2027-02-03**, see [FDROID.md](FDROID.md).
3. Install on a second phone (adb over USB, or send the release APK).
4. **Keep the screen awake while playing** (owner liked it 2026-11-24).
5. **Colour-blind-friendly crossing lines**: draw crossing lines thicker or dashed, not
   only in terracotta (owner liked it 2026-11-24).

Features can be built while Play reviews production access, but don't upload a new
build until approval arrives; ship them in the first production release or right after.

## Parked: what does "improving a level" mean?

Owner said to leave this for now. Earlier proposals: neatness stars (1–3) for how tidy the
solved layout is, and/or a solved count per level. Not by time or moves.

## Rejected by the owner (don't propose again)

- Best time / fewest moves per level, time-based scoring. (The opt-in time limit,
  added 2026-11-24 at the owner's request, is the one exception.)
- Daily puzzle and streaks.
- Undo. Hints.
- Extra game modes (time attack, zen).
- Orange/blue/bright-red palette during play (replaced by the olive palette in CLAUDE.md).
