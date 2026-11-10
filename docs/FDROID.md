# Publishing Untangle on F-Droid

_Started 2026-11-10._ F-Droid builds the app itself from this public repo and signs it
with its own key. Free, no account fees.

## In this repo (done)

- `LICENSE`: MIT (F-Droid only lists FOSS apps).
- `fastlane/metadata/android/en-US/`: title, descriptions, icon, feature graphic,
  5 screenshots, `changelogs/<versionCode>.txt`. F-Droid shows these on the app page.
- `docs/fdroid/com.basdekis.untangle.yml`: the build recipe to submit to F-Droid.
  Uses Flutter 3.44.4 and NDK r28c, removes the `signingConfig` line so the release APK
  is unsigned, builds a universal APK. Tested locally 2026-11-10: builds, unsigned, no
  Google Play Services / Play Core classes.
- Git tag `v1.0.1` = the commit F-Droid builds.

## Steps for the owner

1. Create a GitLab account at <https://gitlab.com/users/sign_up> (any username).
2. Fork <https://gitlab.com/fdroid/fdroiddata> (button "Fork", top right).
3. In your fork, on a new branch `com.basdekis.untangle`, add the file
   `metadata/com.basdekis.untangle.yml` with the content of
   [fdroid/com.basdekis.untangle.yml](fdroid/com.basdekis.untangle.yml)
   (web editor: "+" → "New file").
4. Open a merge request to `fdroid/fdroiddata` `master`. Pick the template
   **"App inclusion"** and tick its checklist. Allow commits from maintainers.
5. The CI pipeline builds the app. If it fails, paste the log here and fix the recipe.
6. A volunteer reviews it (days to weeks). After merge, the app appears in the F-Droid
   client within ~1–3 days.

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
