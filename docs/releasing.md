# Releasing Tracks

Tracks is not on the Play Store (owner's decision, 2026-10-24). Each release
is a signed APK on GitHub Releases; the page in `site/` (deployed on Vercel)
links to `releases/latest/download/tracks.apk`, so it always serves the
newest one without changing the page.

## Signing key

- Keystore: `C:\Users\krish\.tracks-signing\tracks-release.jks`, alias
  `tracks`. Its passwords are in `key.properties` next to it, copied to
  `android/key.properties` (gitignored).
- **Back up that folder** (e.g. to your own Drive). If the key is lost,
  installed copies can't be updated: people would have to uninstall
  (losing data unless backed up) and reinstall.
- Certificate SHA-256: `ca7143b8e365a457ffda4183684814c4601a39908ac028497c0b83540fee7cba`
  (shown on the download page).
- Without `key.properties` (another machine), release builds fall back to
  the debug key so `flutter run --release` still works; don't publish those.

## Steps

1. Bump `version:` in `pubspec.yaml` (the `+N` build number must go up, or
   Android won't install it over the old one).
2. `flutter analyze` and `flutter test`.
3. Build both APKs:
   ```
   flutter build apk --release
   copy build\app\outputs\flutter-apk\app-release.apk dist\tracks-universal.apk
   flutter build apk --release --target-platform android-arm64
   copy build\app\outputs\flutter-apk\app-release.apk dist\tracks.apk
   ```
   Don't use `--split-per-abi`: it multiplies the version code (2 becomes
   2002), so a phone with one APK could never install the other.
4. `powershell -ExecutionPolicy Bypass -File .\tool\release.ps1 -Tag v0.2.0`
   creates the release (or replaces its APKs) using Git's stored GitHub
   login. The download page picks it up at once.
5. Update the version shown in `site/index.html` and push; Vercel redeploys.
