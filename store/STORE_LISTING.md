# Trap Runner — Play Store Listing Pack

Everything to paste/upload in Play Console. Pairs with
[`../docs/PLAYSTORE_RELEASE.md`](../docs/PLAYSTORE_RELEASE.md).

## Assets in this folder (ready to upload)
| File | Use | Spec |
|---|---|---|
| `icon_512.png` | App icon (listing) | 512×512 |
| `feature_graphic.png` | Feature graphic | 1024×500 |
| `screenshots/1_menu.png` | Phone screenshot | landscape |
| `screenshots/2_character_select.png` | Phone screenshot | landscape |
| `screenshots/3_gameplay.png` | Phone screenshot | landscape |
| `screenshots/4_level_select.png` | Phone screenshot | landscape |
| `privacy.html` | Privacy policy page (host it, paste the URL) | — |

> Hosting the privacy policy: the repo is private, so GitHub Pages needs a
> public repo or a Pro plan. Easiest options: paste the HTML into a free host
> (e.g. a public GitHub Gist "raw" URL, Netlify drop, or Cloudflare Pages), or
> a one-page site on dalvoy.com. Any public URL serving this page works.

## Text

**App name:** Trap Runner

**Short description (≤80):**
`A precision platformer where the traps learn how you play.`

**Full description (≤4000):**
```
The level fights back.

Trap Runner is a precision 2D platformer with a twist: the traps adapt to how
you play. Die the same way twice and the level shifts its timing to catch you —
you have to out-think it, not just memorize it.

• 100 hand-tuned levels of rising difficulty
• A reactive trap system that learns your habits and adjusts on every retry
• Spikes, crushers, moving platforms, gates, and walls that move and break
• 4 unlockable characters, each with their own look and sound
• Tight, responsive controls built for one-more-try runs
• Quick sessions, endless replay — perfect for a few minutes or a long sit

Reach the door. Mind the traps. They're watching.
```

## Data safety (answers)
- Collects user data? **No**
- Shares user data? **No**
- Data stored on device only (progress/settings via local storage)? **Yes — not collection**
- Encryption in transit / deletion request: **N/A (no data leaves the device)**
- ⚠️ Update when Phase 4 (AdMob + IAP) ships — ads/IAP SDKs collect data.

## Content rating (questionnaire guidance)
- Category: **Game**
- Violence / blood / gore: **No** (abstract shapes; "death" is a respawn)
- Sexual content, language, drugs, gambling: **No**
- User-to-user communication / shares location: **No**
- Expected result: **Everyone / PEGI 3**

## App content declarations
- Ads: **No** (currently). Change when Phase 4 lands.
- Target audience: select adult/teen age bands; declare **not** primarily
  directed at children to avoid Families policy requirements.
- App access: **All functionality available without special access** (no login).
- Government / financial / health app: **No**

## Build to upload
```
flutter clean && flutter pub get
flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --no-tree-shake-icons
# -> build/app/outputs/bundle/prodRelease/app-prod-release.aab
```
