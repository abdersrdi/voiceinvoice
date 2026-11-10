<p align="center"><img src="assets/icon.png" width="160" alt="VoiceInvoice PRO icon"></p>

# VoiceInvoice PRO

Hands-free invoicing for small merchants on iPhone and iPad. Dictate line items, get a finished invoice with your stamp and signature, share it as a PDF.

**Status:** in development. Working: invoices, PDF export, shop profile, signature, dictation and parsing (EN/FR/ES/IT/ZH), freemium paywall. Not yet built: stamp scanning, Siri/widgets/controls, voice profiles, localization.

- [Summary](VoiceInvoice_Project_Summary.md)
- [Full v1 specification](VoiceInvoice_Complete_Project_Total_Specifications.md)
- [Privacy policy (draft)](PRIVACY.md)

## Build

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
open VoiceInvoice.xcodeproj
```

GitHub Actions (`.github/workflows/ios.yml`) builds and runs the unit tests on every push.

## Releasing (Codemagic to TestFlight)

`codemagic.yaml` builds a signed `.ipa` and uploads it to TestFlight. Before the first run:

1. **Apple Developer Program** membership and an **App Store Connect** app record with bundle ID `com.abdersrdi.voiceinvoice`.
2. In the Apple Developer portal, enable the **iCloud (CloudKit)** capability on that App ID and create the container `iCloud.com.abdersrdi.voiceinvoice`.
3. In App Store Connect create the subscription group with products `com.abdersrdi.voiceinvoice.pro.monthly` ($4.99/month) and `com.abdersrdi.voiceinvoice.pro.yearly` ($39.99/year, 7-day free trial).
4. Create an **App Store Connect API key** (Users and Access > Integrations) and add it in Codemagic under Teams > Integrations > App Store Connect, named `VoiceInvoice`.
5. Add this repo in Codemagic, choose `codemagic.yaml`, and set `APP_STORE_APPLE_ID` in the file to the app's numeric Apple ID.
6. Start the `ios-testflight` workflow manually.
