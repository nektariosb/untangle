# Publishing Untangle on Google Play

_Plan agreed 2026-11-02. Free app, no ads, no in-app purchases, no data collected._

The owner has never published an app on Google Play themselves (their customers published
their earlier apps). Walk through each step together, one at a time, and explain as we go.

## Progress (2026-11-02)

- [ ] 1. Developer account
- [x] 2. Upload key at `C:\Users\basde\keys\untangle-upload.jks`, `android/key.properties`
  filled, `flutter build appbundle --release` is signed with it. Owner to back up the key.
- [x] 3. `docs/privacy.html` written (public email `opapasopaxys@pm.me`, a Proton alias).
  Not hosted yet: push, then enable GitHub Pages (main, `/docs`) →
  `https://nektariosb.github.io/untangle/privacy.html`.
- [x] 4. `docs/store/`: icon_512, feature_graphic, screenshot_1..5 (cropped to < 2:1).

## Costs

- **$25 one time** for a Google Play developer account (card payment at sign-up). No yearly fee.
- Publishing a free app costs nothing beyond that.

## Steps

Legend: **[Owner]** only the owner can do it · **[Claude]** done in this repo.

### 1. Developer account [Owner]

1. Go to <https://play.google.com/console> and sign up as a **personal** account.
2. Pay the $25 and complete **ID verification** (can take a few days).
3. Pick the **contact email** that will be shown publicly on the store page. Consider a
   separate address, not the main personal one.

### 2. Release signing [Claude + Owner]

- Create an upload keystore (`.jks`) with `keytool`. The owner picks the password.
- Store the passwords in `android/key.properties` (**must be gitignored**, the repo is public)
  and read it in `android/app/build.gradle.kts`.
- The owner **backs up the `.jks` file and passwords** somewhere safe (e.g. Proton Drive).
  With Play App Signing, Google holds the real app key, so a lost upload key can be reset,
  but it is slow.
- Build an **App Bundle**: `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`.
- Note: phones with the current debug-signed APK must uninstall it before installing the
  store version (saved progress resets).

### 3. Privacy policy [Claude]

- Required for every app, even one that collects nothing.
- Write a short page: no personal data collected or shared; progress and settings are stored
  only on the device; no ads, no analytics, no network use; contact email.
- Host it free with **GitHub Pages** from this repo (e.g. `docs/privacy.html` or a `gh-pages`
  branch) and use that URL in the Play Console.

### 4. Store graphics [Claude]

- Icon 512×512: downscale `assets/icon/icon.png`.
- Feature graphic 1024×500: generate like the icon (`tool/gen_icon_test.dart`).
- Screenshots: at least 2, ideally 4–5, from the phone via
  `adb -s <device> exec-out screencap -p` (crop the status bar). See the list in
  [store_listing.md](store_listing.md).

### 5. Store listing [Owner, text from Claude]

- Name, short and full description: drafted in [store_listing.md](store_listing.md).
- Category: Puzzle. Price: Free.

### 6. Play Console forms [Owner, ~15 min, Claude helps with answers]

- **Data safety**: no data collected, no data shared.
- **Content rating** (IARC questionnaire): no violence, chat, gambling, etc. → "Everyone".
- **Target audience**: pick the age groups. Including under-13 adds Families policy rules.
  The app already fits them (no ads, no data), but 13+ is simpler.
- **Ads**: "No ads".
- App access: no login needed.

### 7. Closed test: 12 testers for 14 days [Owner]

- Required for personal accounts created after Nov 2023, before applying for production.
- Upload the `.aab` to a **closed testing** track, add at least **12 testers** by Google
  account email (family, friends with Android phones). They must **opt in through the test
  link** and keep the app installed for **14 days in a row**.
- Then apply for **production access** in the console and answer a few questions about the test.

### 8. Production release [Owner + Claude]

- Promote the build to production. Google review usually takes a few days.
- For updates: bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2`, the `+N` must always go
  up), build a new `.aab`, upload.

Realistic total time from account creation to live: **3–4 weeks**, mostly the 14-day test.

## Sources (checked 2026-11-02; mostly third-party, verify in the Play Console)

- [Data safety section help (Google)](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
- [Play Console account fee guide](https://afkarsoftware.com/en/blog-detail/google-play-console-account-2026-one-time-25-fee/)
- [12 testers policy guide](https://theclosedtest.neerajlovecyber.com/blog/google-play-12-testers-policy)
- [Privacy policy requirements (Termly)](https://termly.io/resources/articles/google-play-store-privacy-policy-updates/)
