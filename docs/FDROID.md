# Publishing Untangle on F-Droid

_Started 2026-11-10._ F-Droid builds the app itself from this public repo and signs it
with its own key. Free, no account fees.

## In this repo (done)

- `LICENSE`: MIT (F-Droid only lists FOSS apps).
- `fastlane/metadata/android/en-US/`: title, descriptions, icon, feature graphic,
  5 screenshots, `changelogs/<versionCode>.txt`. F-Droid shows these on the app page.
- `docs/fdroid/com.basdekis.untangle.yml`: copy of the submitted build recipe.
  Flutter 3.44.4 (srclib), NDK r28c, removes the `signingConfig` line so the APKs are
  unsigned, `--split-per-abi`: one APK per ABI (~17 MB each), version codes
  1000/2000/4000 + build number (Flutter's own scheme). Category "Puzzle Game".
  Tested locally 2026-11-10: builds, unsigned, arm64 APK has only arm64 libs, no Google
  Play Services / Play Core classes; `fdroid lint` and `fdroid rewritemeta` clean.
- Git tag `v1.0.1` = commit `0c5dadc9…` that F-Droid builds.

## Submission (2026-11-10)

- GitLab account `marstons`, fork <https://gitlab.com/marstons/fdroiddata> (public),
  branch `com.basdekis.untangle`.
- Merge request **!56687** "New app: Untangle":
  <https://gitlab.com/fdroid/fdroiddata/-/merge_requests/56687>
- CI didn't start: GitLab wants identity verification (phone/card) on the fork. As F-Droid's
  template advises, not done; a comment asks a maintainer to trigger the pipeline.
- Not enabled: reproducible builds (F-Droid signs with its own key; can't be switched
  later). Flutter is a srclib, not a submodule; offered to switch if reviewers ask.

Next: wait for review (days to weeks). Answer reviewer comments; if the pipeline fails,
paste the log to Claude. After merge, the app appears in the F-Droid client in ~1–3 days.

## Later releases

Bump `version:` in `pubspec.yaml`, add `fastlane/.../changelogs/<versionCode>.txt`,
commit, and push a tag `vX.Y.Z`. F-Droid's bot sees the tag and builds it on its own
(`AutoUpdateMode: Version`, `UpdateCheckMode: Tags`).
If a release needs a newer Flutter, the `srclibs: flutter@...` line in fdroiddata must
be updated too (merge request on fdroiddata).

## Notes

- **Signature:** the F-Droid APK is signed by F-Droid, the Play APK by Google. They
  can't update each other; switching store means uninstall + reinstall (progress lost).
- No anti-features: no ads, tracking, network or non-free dependencies.
