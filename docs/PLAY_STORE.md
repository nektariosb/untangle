# Publishing Untangle on Google Play

_Plan agreed 2026-11-02. Free app, no ads, no in-app purchases, no data collected._

First Play release for the owner: walk through each step together, one at a time.

## Current state (2026-11-06): closed test live, testers opting in

**Approved.** Release `1 (1.0.0)` on "Closed testing - Alpha" was published on
2026-11-04 ("Available to selected testers"). Join link
<https://play.google.com/apps/testing/com.basdekis.untangle> was emailed to all 12
testers on 2026-11-06. Dashboard that evening: **2 testers opted in**. The 14 days start
at 12. The Dashboard shows only the count, not who joined.

Done:

- [x] 1. Personal developer account. Public email `opapasopaxys@pm.me` verified. Identity
  and phone verification passed. Trader status: non-trader (free, no income; nothing
  personal shown on the store page).
- [x] 2. Upload key outside the repo (path in the gitignored `android/key.properties`).
  `flutter build appbundle --release` is signed with it. One key per app. Play App
  Signing is on (Google-managed app key).
- [x] 3. `docs/privacy.html`, live on GitHub Pages:
  <https://nektariosb.github.io/untangle/privacy.html>.
- [x] 4. `docs/store/`: icon_512, feature_graphic, screenshot_1..5 (cropped to < 2:1).
- [x] 5. App created: "Untangle", `com.basdekis.untangle`, Game, Free, en-US.
- [x] 6. All "Finish setting up" forms: privacy policy URL, app access (nothing
  restricted), ads (none), content rating (IARC, Everyone / PEGI 3), target audience
  **all ages incl. under 13** (Families policy; not in Teacher Approved), data safety
  (nothing collected/shared), government/financial/health (none), category Puzzle,
  store contact `opapasopaxys@pm.me`, **advertising ID: No** (the merged release manifest
  has no `AD_ID` permission; re-check if a plugin is ever added).
- [x] 7. Default store listing: texts from store_listing.md, icon, feature graphic,
  5 phone screenshots, AI label: none.
- [x] 8. Closed testing track **"Closed testing - Alpha"**:
  - Countries: all 178.
  - Testers: email list **"Untangle testers"**, 12 Gmail accounts (the list lives only in
    the console, not in this public repo). Feedback channel `opapasopaxys@pm.me`.
  - Release `1 (1.0.0)`, versionCode 1, API 24+, target SDK 36, 8.2 MB install.
    Notes: "First test release."
  - Release `2 (1.0.1)` (2026-11-08): step-by-step start hint (line colours, drag, hold
    and circle to group-select, pinch on big levels). Full rollout to Alpha, sent for
    review 2026-11-08; release 1 not carried over. Approved, live since 2026-11-08 19:07.
  - 2026-11-10: Dashboard shows **12 testers opted in for 1 day**, so the 14 days end
    around **2026-11-23**. Then apply for production.

## Next steps

1. ~~Wait for approval~~ Approved 2026-11-04.
2. **Recommended now:** add 2–3 spare testers to "Untangle testers" (Alpha track → Testers
   → arrow next to the list). With exactly 12, one dropout restarts the 14 days.
3. **After approval:** Alpha track → Testers tab → **Copy link** ("Join on the web"). Send
   it to every tester with these instructions:
   - Open the link on the Android phone, signed in with the Gmail that's on the list.
   - Tap "Become a tester", then install Untangle from Play (from the link).
   - Keep it installed for at least 14 days; open it now and then.
4. Owner: uninstall the debug/sideloaded build first (different signature), then install
   from Play. Saved progress resets.
5. **Count 14 days** from when the 12th tester opts in. The Dashboard shows "x testers
   currently opted in". Expected earliest: ~2026-11-20 if approval and opt-ins are quick.
6. **Apply for production** (Dashboard → Production → "Apply for production"). Answer the
   questions about the test (who tested, feedback received, changes made). Then step 8
   below: a production release, another Google review.
7. Any new build during the test: bump `version:` in `pubspec.yaml` (`1.0.1+2`, the
   `+N` must go up), `flutter build appbundle --release`, Alpha track → Create new release.
   Updating doesn't restart the 14 days.

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
- The owner **backs up the `.jks` file and passwords** somewhere safe.
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
  account email. They must **opt in through the test
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
