# Shipping Apostle Anchor to TestFlight

The project is TestFlight-ready: automatic signing, a 1024 pt app icon,
`ITSAppUsesNonExemptEncryption = NO` (standard HTTPS only, so no export
compliance questionnaire), and no entitlements beyond the defaults.

## One-time setup
1. Join the [Apple Developer Program](https://developer.apple.com/programs/) ($99/yr).
2. In Xcode → Settings → Accounts, sign in; select your team on the
   `ApostleAnchor` target (Signing & Capabilities). The team ID replaces the
   placeholder currently in the project.
3. In [App Store Connect](https://appstoreconnect.apple.com), create the app:
   bundle ID `com.jlanej.ApostleAnchor`, name "Apostle Anchor" (or your pick).

## Each build
```bash
# Bump the build number first (CURRENT_PROJECT_VERSION in project settings), then:
xcodebuild -project ApostleAnchor.xcodeproj -scheme ApostleAnchor \
  -destination 'generic/platform=iOS' archive \
  -archivePath build/ApostleAnchor.xcarchive
```
Then Xcode → Organizer → Distribute App → TestFlight & App Store (or
`xcodebuild -exportArchive` with an export options plist for CI).

## Before inviting boaters
- App Store Connect → TestFlight → add "What to Test" notes.
- App privacy: the app collects **no user data** — forecasts and observations
  are fetched anonymously from Open-Meteo, NOAA/NWS, and NDBC; nothing leaves
  the device. Declare "Data Not Collected."
- Keep the "Not for navigation" disclaimer prominent in the description.
- External testers (up to 10,000) need a short Beta App Review — the
  disclaimer and data-source credits already in the About tab cover the
  usual questions.
