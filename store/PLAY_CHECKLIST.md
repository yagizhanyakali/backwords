# Publishing checklist (Google Play Console)

Upload file: `build/app/outputs/bundle/release/app-release.aab`
(rebuild: `flutter build appbundle --release`; bump `version:` in pubspec.yaml, e.g. 1.0.1+2, for every new upload)

## Keep safe
- Upload keystore: `~/backwords-keys/upload-keystore.jks`, passwords in `android/key.properties`.
  Back both up somewhere private (password manager / encrypted drive). Play App Signing holds the real
  app-signing key, so a lost upload key can be reset via Play support, but it is slow.

## Console steps
1. Create app: name, default language, App (not game), Free, accept declarations.
2. Set up your app > App content:
   - Privacy policy: host `store/privacy-policy.md` publicly (e.g. GitHub Pages) and paste the URL.
   - Ads: No.
   - App access: all functionality available without login.
   - Content rating questionnaire (expect Everyone).
   - Target audience: 13+ is simplest (avoids Families policy requirements).
   - Data safety: collects no data; data processed on-device only; no data shared. The microphone
     recording is not collected or sent off device. (Sharing is user-initiated via the system share sheet.)
   - Government app / financial / health: No.
3. Store listing: texts from `listing.md`, icon, feature graphic, screenshots.
4. Testing: personal developer accounts created after Nov 2023 must run a closed test with at least
   12 testers opted in for 14 continuous days before applying for production access.
5. Release: Testing > Closed testing (or Production) > Create release > upload the .aab > release notes > review > roll out.
