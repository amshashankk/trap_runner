# Trap Runner — Play Store Release Runbook

A self-contained guide to publish **Trap Runner** to Google Play. Written so a
fresh Claude session ("cowork") or the developer can execute it end-to-end.

> Status: Play Console account is **created & verified**. Package ID, signing,
> and a release App Bundle are **already prepared** (see "Current state"). The
> remaining work is Play Console setup + listing assets + submission.

---

## 0. Project facts (do not guess — these are current)

| Thing | Value |
|---|---|
| App name | **Trap Runner** |
| Application ID | **`com.amshashankk.traprunner`** (permanent — never change) |
| Dev flavor ID | `com.amshashankk.traprunner.dev` (separate app, for testing) |
| Version | `1.0.1+2` in `pubspec.yaml` → versionName `1.0.1`, versionCode `2` |
| minSdk / targetSdk | 24 / 36 (Flutter defaults — meets Play's target-API rule) |
| Engine | Flutter (Homebrew SDK `/opt/homebrew/share/flutter`, 3.44.4) |
| Upload keystore | `android/app/trap-runner-release.jks` (**git-ignored, local only**) |
| Keystore creds | `android/key.properties` (**git-ignored, local only**) |
| Keystore alias / pass | `traprunner` / `TrapRunner2026` |
| Repo | private — `github.com/amshashankk/trap_runner` |

### Build commands
```bash
# Play Store upload artifact (App Bundle):
flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --no-tree-shake-icons
#   -> build/app/outputs/bundle/prodRelease/app-prod-release.aab

# Sideload/test APK (prod):
flutter build apk --flavor prod --dart-define=FLAVOR=prod --no-tree-shake-icons
#   -> build/app/outputs/flutter-apk/app-prod-release.apk

# Dev flavor (bypass button, level-skip, all levels unlocked) for QA:
flutter build apk --flavor dev --dart-define=DEV_MODE=true --dart-define=FLAVOR=dev --no-tree-shake-icons
```

> ⚠️ **Build gotcha:** incremental rebuilds can reuse a **stale Dart snapshot**
> (a suspiciously fast ~5s build that ships old UI). If a build seems to not
> contain recent code changes, run `flutter clean && flutter pub get` first,
> then rebuild (a real build takes ~25–35s).

> ⚠️ **Sideload gotcha:** release-signed APKs won't install over a
> debug-signed install (signature mismatch). `adb uninstall <id>` first.

---

## 1. Current state (already done)

- [x] Real application ID set (`com.amshashankk.traprunner`); `com.example.*` removed.
- [x] Release signing wired: `signingConfigs.release` reads `android/key.properties`;
      release buildType uses it (verified V2-signed, `CN=Trap Runner`).
- [x] Launcher icon set from `assets/icon/app_icon.png` (all densities + adaptive).
- [x] App label shows "Trap Runner".
- [x] Production `.aab` builds cleanly.
- [x] Play Console account created & verified.

---

## 2. CRITICAL — back up the upload key first

The keystore is **local-only and git-ignored**. If lost, you can recover via
Play (since you'll use Play App Signing) but it's painful. Before anything:

```bash
# copy to a safe place (password manager / encrypted backup)
cp android/app/trap-runner-release.jks ~/secure-backup/
cp android/key.properties ~/secure-backup/
```
Record: alias `traprunner`, store/key password `TrapRunner2026`.

---

## 3. Play Console — create the app

1. [play.google.com/console](https://play.google.com/console) → **Create app**.
2. App name **Trap Runner** · default language · app type **Game** · **Free**.
3. Accept the developer program & US export declarations.

---

## 4. Upload to Internal testing (do this BEFORE production)

1. **Test and release → Testing → Internal testing → Create new release**.
2. On first upload, accept **Play App Signing** (Google manages the signing key;
   your `.jks` is the *upload* key).
3. Upload `build/app/outputs/bundle/prodRelease/app-prod-release.aab`.
4. Release name auto-fills (`2 (1.0.1)`). Add brief release notes.
5. **Save → Review release → Start rollout to Internal testing**.
6. Under **Testers**, add your Google account / a tester list, copy the opt-in
   link, install on a device, and smoke-test all the flows in §7.

---

## 5. Complete required declarations (Play blocks publishing without these)

Under **Policy and programs / App content**:

- **Privacy policy** — paste a hosted URL. *Required.* (Trap Runner currently
  collects **no** personal data — see Data safety below. A simple policy page is
  enough; ask Claude to generate one + host on GitHub Pages.)
- **Data safety** — current truthful answers:
  - Does your app collect/share user data? **No** (only local `shared_preferences`
    for progress/settings, which stays on device and is not transmitted).
  - Data encrypted in transit / deletable: N/A (no collection).
  - ⚠️ Revisit this when **Phase 4 (AdMob + IAP)** lands — ads/IAP collect data.
- **Content rating** — fill the questionnaire (casual platformer, no violence/
  gambling → expect "Everyone").
- **Target audience and content** — pick age groups; if **not** targeting
  children, declare so (avoids Families policy obligations).
- **Ads** — declare **No ads** for now (change when Phase 4 ships).
- **Government apps / financial / health** — No.
- **App access** — "All functionality available without restrictions" (no login).

---

## 6. Store listing (Main store listing)

| Asset | Spec | Status |
|---|---|---|
| App icon | 512×512 PNG (32-bit) | generate from `assets/icon/app_icon.png` |
| Feature graphic | 1024×500 PNG/JPG | needs creating |
| Phone screenshots | 2–8, 16:9 or 9:16, ≥320px | capture from emulator (see below) |
| Short description | ≤80 chars | draft below |
| Full description | ≤4000 chars | draft below |

Suggested copy:
- **Short:** `A precision platformer where the traps learn how you play.`
- **Full:** Describe the adaptive-trap hook, 100 levels, 4 characters, tight
  controls. Lead with "the level fights back."

Capture screenshots from the running emulator:
```bash
adb -s emulator-5554 exec-out screencap -p > shot.png
```
Good shots: menu, character select, an early level, a trap-heavy level, a
level-clear overlay.

---

## 7. Pre-submission smoke test (on the internal-testing build)

- [ ] App launches, shows "Trap Runner" name + custom icon.
- [ ] Menu → two sound toggles (music + sfx) work independently.
- [ ] PLAY → Character Select → all 4 characters selectable → START.
- [ ] Level plays; jump/move feel right; death → respawn; out-of-lives overlay.
- [ ] Level complete → next; Level select unlocks progressively (prod build).
- [ ] Full-screen (no black bars) in landscape.
- [ ] Sounds differ per character; music loops.

---

## 8. Promote to Production

1. **Production → Create new release** → reuse the same bundle (or upload a new one).
2. Add release notes → **Review** → **Start rollout to Production**.
3. First review usually takes a few days. You can do a **staged rollout** (e.g. 20%).

---

## 9. Shipping an update later

1. Bump version in `pubspec.yaml` (e.g. `1.0.2+3` — **versionCode must increase**).
2. `flutter clean && flutter pub get`
3. `flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --no-tree-shake-icons`
4. Upload the new `.aab` to a track → review → rollout.

---

## 10. What Claude can generate on request

- Privacy policy text + a `docs/privacy.html` page (host via GitHub Pages).
- 512×512 store icon + 1024×500 feature graphic (PIL, from the game art).
- A batch of clean store screenshots from the emulator.
- The Data safety / content-rating answers in a fill-in checklist.

Ask: "generate the Play Store listing assets" to produce the above.
