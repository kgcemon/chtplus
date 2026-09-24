# CHT Plus — mobile app

The Flutter client for **chtplus.xyz**: local services, blood donors, a
marketplace, matrimony biodata and doctor appointments for Khagrachari,
Rangamati and Bandarban.

It talks to the existing Next.js backend in `khagrachariPlusNackend` over the
REST routes under `/api`. **No new backend endpoint was added** — every screen
is built on a route that already existed.

---

## Running it

```bash
flutter pub get
flutter run
```

The API base URL defaults to `https://chtplus.xyz`. Point it somewhere else at
build time:

```bash
flutter run --dart-define=CHT_API_BASE=http://10.0.2.2:3000
```

(`10.0.2.2` is how the Android emulator reaches `localhost` on the host.)

---

## What's in the app

| Area | Screens |
| --- | --- |
| **Home** | Banners, quick links, and a section per feature ordered by the interests the user picked at sign-up. Welcome popup. |
| **Services** | Browse, search, category chips, district/area/sponsored filters, detail with photo gallery, reviews, call/WhatsApp. Add, edit, delete and boost your own. |
| **Blood donors** | Filter by group, district, area and availability. Donor detail with likes, reviews and call/SMS. Register or update your own donor profile. |
| **Marketplace** | Category and subcategory navigation, condition/area filters, sorting, detail with specifications, seller chat and call. Sell, edit, delete and promote your adverts. |
| **Matrimony** | Verified biodata list with gender/age/district/status filters, locked teaser + coin or package unlock, full record once unlocked, four-step submission wizard, my biodata. |
| **Doctors** | Search by name/specialty, department and hospital filters, doctor detail with chambers and next available dates, two-step serial booking, my appointments with cancel. |
| **Social** | Public profiles, follow/unfollow, followers and following lists, reviews with loves and replies, direct messaging with unread badges. |
| **Account** | Profile with cover and avatar upload, bio and per-field privacy (public / followers / only me), work and education, saved items, notifications, coins and subscription, settings, account deletion. |

---

## How it is built

```
lib/
  core/        config, theme, API client, storage, formatters, shared widgets
  models/      typed models parsed defensively from the API
  data/        one repository per backend area
  providers/   Riverpod providers (auth, catalog, home, per-feature)
  features/    one folder per screen area
  router.dart  GoRouter, with a five-branch bottom-nav shell
```

**Auth.** The backend issues a signed bearer token valid for 30 days. It is
stored in the platform keystore (`flutter_secure_storage`) and attached by a
Dio interceptor. A 401 from any call signs the user out, so a token that
outlived its account cannot get stuck. Browsing works signed out; only posting,
messaging, booking and the "my ..." screens require an account.

**Speed.** GET responses are cached on disk with a per-kind TTL — reference data
(categories, districts, departments) for 12 hours, feeds for 5 minutes — so a
warm start paints immediately and the network refresh happens behind it. On a
network failure a stale copy is used before showing an error. The home screen
fires its nine requests in parallel over one keep-alive connection pool rather
than sequentially. Images are cached to disk and decoded at the size actually
drawn. Lists use fixed extents and lazy builders, and loading states are
skeletons that match the final layout so nothing jumps.

**Release build.** R8 shrinking and resource shrinking are on, with keep rules
for OneSignal and Play Services auth. Icon fonts are tree-shaken (~99%). A real
device downloads about **22 MB** (arm64) / **20 MB** (armeabi-v7a) — the 60 MB
universal APK only looks large because it carries all three ABIs, and Play
serves the per-device split from the app bundle.

---

## Configuration

### Google Sign-In

The client ID comes from `/api/app-config`, which reads **Admin → Settings →
Google Sign-In** — the same value the website uses. The button hides itself when
it is not set.

For Android you additionally need to register the app's signing certificate in
Google Cloud Console, or `authenticate()` will fail:

```bash
# debug fingerprint
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Add an **Android** OAuth client with package name `com.chtplus.bd` and that
SHA-1, in the same Google Cloud project as the existing Web client. Repeat with
your release keystore's SHA-1 (and the Play App Signing SHA-1 once uploaded).

### Push notifications — configured ✅

Delivery chain: **Firebase (FCM) → OneSignal → app**. The backend already pushes
on *every* notification (`lib/notify.js` calls `sendPush` for reviews, replies,
follows, approvals; the chat route pushes separately), so nothing else has to be
wired up per activity type.

Live setup:

| Piece | Value |
| --- | --- |
| Firebase project | `khagrachari-plus` ("Khagrachari Plus") |
| FCM credential | Service-account JSON uploaded to OneSignal |
| OneSignal app | "CHT Plus" |
| OneSignal App ID | `0a4c3d9d-9e3d-4e3d-9a05-aa32adb7a3e9` |
| Android platform | Google Android (FCM) — **Active** |
| REST API key | Stored in Admin → Settings (never in this repo) |

The app reads the App ID from `/api/app-config` at startup, so an admin can
change it without a new release; when it is empty, push is skipped entirely. The
signed-in user id is set as the OneSignal *external id*, which is how
`lib/push.js` addresses a notification. Permission is requested after sign-in,
not on first launch.

**Tapping a notification opens the screen it refers to.** The backend puts a
site path in each push (`/chat/12`, `/donors?open=bd_1`, `/my-services?open=svc_1`,
…); `lib/core/utils/deep_links.dart` maps that onto an app route, and the same
mapper backs the in-app notification list so both behave identically. Two
details matter:

- `com.onesignal.suppressLaunchURLs` is set in the manifest — without it the SDK
  opens the URL in a browser instead of letting the app handle it.
- A tap can cold-start the app, so the handler waits (up to 4s) for the
  navigator to exist rather than dropping the route.

List links that carry an `?open=` id are redirected to the real detail screen
(`/donors?open=bd_1` → `/donors/bd_1`). Off-site links are never opened in-app.
The mapping is covered by `test/deep_links_test.dart` using the exact link
shapes the server emits.

The status-bar icon is `android/app/src/main/res/drawable/ic_stat_onesignal_default.xml`
(Android masks notification icons to a flat silhouette, so it is white-on-
transparent); the accent colour is set in the manifest.

Not set up yet: the **Web** platform in OneSignal, if you also want browser push
on chtplus.xyz.

### Release signing — configured ✅

The release keystore exists and `android/key.properties` points at it, so
`flutter build apk/appbundle --release` signs with it automatically.

| | |
| --- | --- |
| Keystore | `C:\Users\emon\keystores\chtplus-release.jks` |
| Alias | `chtplus` |
| Valid until | Feb 2054 |
| Password | in `chtplus-release-password.txt` beside the keystore — **not in this repo** |

`android/key.properties` holds the passwords and is git-ignored; the keystore
lives outside the project entirely so it can never be committed.

> **Losing the keystore means the app can never be updated on Play again.**
> Keep the `.jks` and its password backed up in at least two places.

Without `key.properties` the build falls back to the debug key, so a fresh
clone still runs.

### Signing certificates to register with Google Sign-In

Google Sign-In on Android only works when an **Android OAuth client** exists
for this package under the same Google Cloud project as the configured client
id — one per signing certificate:

| Build | SHA-1 |
| --- | --- |
| Debug (`flutter run`, `~/.android/debug.keystore`) | `43:B6:19:55:1C:9E:F9:9C:B2:59:C3:A0:16:38:40:43:A0:97:91:A6` |
| Release (the keystore above) | `F1:79:2B:74:E8:66:03:CA:91:5D:E8:06:08:B5:4A:15:E7:D2:0A:DD` |
| Play App Signing | read from Play Console → Setup → App signing **after the first upload** |

Play re-signs uploaded bundles with its own key, so the third one is what
installs from the Play Store actually carry. Register all three.

Re-read a fingerprint at any time with:

```bash
keytool -list -v -keystore C:\Users\emon\keystores\chtplus-release.jks -alias chtplus
```

---

## Google Play readiness

| Requirement | Status |
| --- | --- |
| Privacy policy URL | `https://chtplus.xyz/privacy-policy`, linked from Settings, About and the sign-up screen |
| In-app account deletion | Settings → Delete my account (two confirmations, then `DELETE /api/me/account`) |
| Permissions | See the full merged list below — the app declares two, the plugins add the rest. No storage permission (system photo picker) and camera is `required="false"` |
| Target SDK | 36, compiled against 36 — meets Play's current requirement |
| Payments | None in-app. Coins are paid for over bKash/Nagad outside the app and credited by an admin, so Play Billing does not apply. Do not describe them as an in-app purchase on the store listing |
| User-generated content | Every service, advert and biodata is admin-reviewed before it is public; safety notes appear on listing and matrimony screens |
| Data safety form | Declare: name, email, phone, photos, approximate location (district/area), messages — collected, linked to the user, used for app functionality, deletable in-app |
| App icon | **Still the Flutter placeholder — replace before publishing** (see below) |

### Permissions actually shipped

Verified with `aapt2 dump xmltree` against the built release APK — the manifest
merger adds plugin permissions on top of the two this project declares:

| Permission | Comes from |
| --- | --- |
| `INTERNET` | declared here |
| `POST_NOTIFICATIONS` | declared here |
| `USE_BIOMETRIC`, `USE_FINGERPRINT` | `flutter_secure_storage` (keystore-backed token) |
| `WAKE_LOCK`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED`, `READ_APP_BADGE`, `ACCESS_NETWORK_STATE`, `FOREGROUND_SERVICE` | `onesignal_flutter` |

None of these are in Play's "sensitive permissions" set, so no extra declaration
form is normally required. `FOREGROUND_SERVICE` is declared by OneSignal but no
service sets a `foregroundServiceType`, so it is not an actual foreground-service
use — if Play Console asks about it anyway, the answer is push-notification
delivery by the OneSignal SDK.

### Uploading to Play

Upload the **app bundle** (`flutter build appbundle --release`), not the
split APKs. The split APKs carry an ABI-prefixed `versionCode` (arm64 builds as
`2001`) which is a Flutter convention for direct-APK distribution; the bundle
uses the plain `versionCode` from `pubspec.yaml`.

### Remaining before you publish

1. **App icon and splash.** Replace `android/app/src/main/res/mipmap-*/ic_launcher.png`
   with the CHT Plus logo (`flutter_launcher_icons` is the easy route), and
   upload a 512×512 icon plus a 1024×500 feature graphic in Play Console.
2. **Screenshots** — at least two phone screenshots.
3. **Google Cloud SHA-1** for release signing, as above.
4. **Deep links (optional).** The manifest claims `chtplus.xyz` links with
   `autoVerify`. To make Android open them without a chooser, serve
   `/.well-known/assetlinks.json` from the site with the app's signing
   fingerprint.
