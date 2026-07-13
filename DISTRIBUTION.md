# Distributing Simple Window Snap

Everything in the main [README](README.md) covers running the app locally
via Xcode, which is all that's needed for development. This document is
for when you're ready to hand a build to someone else (or run it on a
different Mac) without them needing Xcode or an Apple Developer account
themselves.

## Why this is more than "just build it"

macOS's Gatekeeper blocks unsigned/unnotarized apps from launching on
other people's Macs with only a scary warning and no easy way to run
anyway. To avoid that, the build needs to be:

1. Signed with a **Developer ID Application** certificate (not the free
   "Apple Development" certificate this project currently uses for local
   builds - see the signing gotcha in the main README).
2. **Notarized** - submitted to Apple's automated scanning service, which
   staples a ticket to the app vouching it's not obviously malicious.

Both require a **paid Apple Developer Program membership** ($99/year).
There's no way around this for distributing outside the Mac App Store;
the free "Personal Team" tier this project currently signs with cannot
produce a Developer ID certificate.

## One-time setup

1. Enroll at [developer.apple.com/programs](https://developer.apple.com/programs/) if you haven't already.
2. In Xcode: **Settings… → Accounts** → select your Apple ID → **Manage
   Certificates…** → **+** → **Developer ID Application**. This only
   appears once your account has an active paid membership.
3. Find your Team ID for the paid account: `security find-identity -v -p codesigning` (same command used to find the Team ID in the main README's
   signing setup) - look for the new "Developer ID Application: ..." entry
   and note the ID in parentheses. It may differ from the free-tier
   `DEVELOPMENT_TEAM` currently in `project.yml` if the paid membership is
   under a different Apple ID/organization.
4. Update `project.yml`:
   ```yaml
   settings:
     base:
       DEVELOPMENT_TEAM: <your Developer ID team ID>
       CODE_SIGN_IDENTITY: "Developer ID Application"
       ENABLE_HARDENED_RUNTIME: true   # required for notarization
   ```
   Hardened Runtime doesn't restrict Accessibility API usage (that's
   governed by TCC/user consent, not code-signing runtime protections),
   but this hasn't been verified against an actual notarized build - worth
   a real end-to-end test the first time through this process.
5. Regenerate the project: `xcodegen generate`.

## Building a release

```sh
# Archive
xcodebuild -project SimpleWindowSnap.xcodeproj -scheme SimpleWindowSnap \
  -configuration Release archive -archivePath build/SimpleWindowSnap.xcarchive

# Export the signed .app from the archive
xcodebuild -exportArchive -archivePath build/SimpleWindowSnap.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist
```

`ExportOptions.plist` needs to specify `method: developer-id`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>
</plist>
```

## Notarizing

```sh
# One-time: store credentials in the keychain so you don't need to pass
# them every time (an app-specific password, not your Apple ID password -
# generate one at appleid.apple.com > Sign-In and Security).
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "your-apple-id@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"

# Zip the exported .app and submit
ditto -c -k --keepParent "build/export/Simple Window Snap.app" build/SimpleWindowSnap.zip
xcrun notarytool submit build/SimpleWindowSnap.zip \
  --keychain-profile "notarytool-profile" --wait

# Staple the notarization ticket to the .app itself (so it works offline too)
xcrun stapler staple "build/export/Simple Window Snap.app"

# Verify Gatekeeper is satisfied
spctl -a -vvv -t install "build/export/Simple Window Snap.app"
```

If `notarytool submit --wait` reports rejection, `xcrun notarytool log <submission-id> --keychain-profile "notarytool-profile"` shows why.

## Packaging for distribution

Once stapled, zip or `.dmg` the `.app` for distribution:

```sh
ditto -c -k --keepParent "build/export/Simple Window Snap.app" "SimpleWindowSnap-0.1.0.zip"
```

A proper `.dmg` with a nicer installer experience (drag-to-Applications
background, etc.) is a further nice-to-have not covered here - tools like
[`create-dmg`](https://github.com/create-dmg/create-dmg) handle that well
if/when it's worth the extra polish.

## Automated releases (GitHub Actions)

`.github/workflows/release.yml` does everything above automatically:
push a tag like `v0.2.0` and it archives, signs, notarizes, staples, and
attaches the resulting zip to a GitHub Release.

It needs these repo secrets (**Settings → Secrets and variables →
Actions**):

| Secret | What it is |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Your Developer ID Application cert + private key, exported from Keychain Access as a `.p12`, then `base64 -i cert.p12 \| pbcopy`. |
| `P12_PASSWORD` | The password you set when exporting that `.p12`. |
| `KEYCHAIN_PASSWORD` | Any random string - just used to protect the throwaway keychain created during the CI run. |
| `APPLE_API_KEY_ID` | Key ID of an App Store Connect API key (**Users and Access → Integrations → App Store Connect API** on appstoreconnect.apple.com). Create one with the "Developer" role. |
| `APPLE_API_ISSUER` | The Issuer ID shown on that same API Keys page. |
| `APPLE_API_KEY_BASE64` | The downloaded `AuthKey_<KEY_ID>.p8` file, base64-encoded (`base64 -i AuthKey_XXXX.p8 \| pbcopy`). Apple only lets you download this once, so save the original `.p8` somewhere safe. |

An API key is used instead of an Apple ID + app-specific password because
it doesn't depend on 2FA/session state, which suits unattended CI runs.

To cut a release:

```sh
git tag v0.2.0
git push origin v0.2.0
```

The team ID (`GK5YMCRFZN`) is hardcoded in the workflow and in
`ExportOptions.plist` - update both if you ever sign with a different
Developer ID team.
