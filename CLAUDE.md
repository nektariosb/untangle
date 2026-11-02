# Untangle — Flutter planarity puzzle

Dots are connected by lines and scrambled. The player drags the dots until no two
lines cross. Original implementation of the planarity-puzzle genre.

**Before starting work, read [docs/ROADMAP.md](docs/ROADMAP.md)**. It holds the current
state, the agreed next tasks, ideas the owner rejected, and open questions.

## Run / verify

- `flutter run` (owner tests on a phone). Targets: **android, ios, web**.
- `flutter analyze` and `flutter test` must stay clean. Run `dart format lib test`.
- `android/gradle.properties` has `kotlin.incremental=false` on purpose: the project (E:)
  and pub cache (C:) are on different drives, which breaks Kotlin incremental builds.
- Windows **desktop** target was removed on purpose: plugins need symlinks, which need
  Windows Developer Mode (off on this PC). Don't re-add `windows/` unless asked.

## Code map

- [lib/main.dart](lib/main.dart): `UntangleApp`, owns `ThemeMode` and the light/dark `ThemeData`
  (olive seed `0xFF6B7B2C`, `DynamicSchemeVariant.fidelity`).
- [lib/game/puzzle.dart](lib/game/puzzle.dart): pure model, no Flutter widgets.
  - `Puzzle.generate(lineCount, rng)`: draws random lines. Every pairwise intersection
    becomes a vertex, and consecutive intersections along a line become edges. This is
    planar by construction, so every puzzle is solvable. Vertices = n(n-1)/2, edges = n(n-2).
  - `solution` keeps the original (crossing-free) layout, normalized to the unit square.
  - `scramble()` puts the vertices on a circle in random order, retrying until crossings > 0.
  - `recompute()` is an O(E²) segment-intersection test. Edges sharing an endpoint are
    skipped. Touching/collinear counts as a crossing.
  - Positions are **normalized 0..1**. The board maps them to pixels.
- [lib/game/game_screen.dart](lib/game/game_screen.dart): `GameScreen` (HUD, board, bottom bar,
  level picker sheet, solved card, first-move hint), `BoardColors` (dark/light palettes),
  `_BoardPainter` (CustomPainter).
  - Input is a raw `Listener` keyed by pointer id, so multi-touch drags several dots at once.
  - A win is declared only on pointer-up, once all fingers are lifted.
  - Level L uses `L + 3` lines (level 1 = 6 dots … level 11 = 91 dots). `_maxLevel = 11`.
  - Solve animation: `_solveAnim` (1.8 s) drives a green wave from the last-moved dot and
    a spark burst in `_BoardPainter`. The solved card appears at 70%.
- [lib/game/store.dart](lib/game/store.dart): `shared_preferences` wrapper (theme, level,
  unlocked, muted). `main()` loads it before `runApp`.
- [lib/game/sfx.dart](lib/game/sfx.dart): `audioplayers` pools for grab/solve. Silent until
  `init()` runs (only `main()` calls it, so tests stay silent).
- [tool/](tool/): `gen_sounds.dart` (WAVs) and `gen_icon_test.dart` (icon/splash PNGs).
- [test/widget_test.dart](test/widget_test.dart): puzzles for 4..14 lines are solvable and
  start tangled; saved level/unlock restore; solving level 1 by drags runs the animation
  and unlocks level 2 (`GameScreen.random` is seeded for this); mute is saved.

## Visual language (agreed with owner, keep it)

Olive-green theme, light and dark, with a sun/moon toggle in the HUD.

| Element | Dark | Light |
|---|---|---|
| Board | `#1C2114` | `#FAFBF3` |
| Normal line | `#6F7B4E` | `#A3AA86` |
| Crossing line | terracotta `#D9774B` | `#C0533A` |
| Dot | sand `#E6DDB8` | dark olive `#55611F` |
| Dragged dot | white, enlarged, glow | `#1F2314`, enlarged, glow |
| Connected to dragged | lime `#C8E25A`, larger, ring; their lines lime too | `#9DC02E` |
| Solved (whole board) | `#B5D96A` | `#5E8A1E` |

The owner rejected orange dots, blue highlights and bright red as off-theme. The
crossing-count chip uses `#B5523A`, or olive `#5B6E1C` at zero crossings.

## Owner preferences

- Likes tidying and arranging dots before solving. **No time pressure, no move/time
  scoring, no time challenges.** The timer and move counter are shown only as info.
- Wants a relaxed puzzle, not a competitive one. Rejected: daily puzzle/streaks, undo,
  hints, extra game modes (see ROADMAP).
- Prefers being shown things over long explanations. Keep replies short.
