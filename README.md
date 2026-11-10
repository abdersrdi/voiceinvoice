<p align="center"><img src="assets/icon.png" width="160" alt="VoiceInvoice PRO icon"></p>

# VoiceInvoice PRO

Hands-free invoicing for small merchants on iPhone and iPad. Dictate line items, get a finished invoice with your stamp and signature, share it as a PDF.

- [Summary](VoiceInvoice_Project_Summary.md)
- [Full v1 specification](VoiceInvoice_Complete_Project_Total_Specifications.md)
- [Privacy policy (draft)](PRIVACY.md)

## What works

| Area | Status |
|---|---|
| Invoices, customers, tax, discount, numbering, PDF export and share | Built, unit-tested |
| Shop profile, logo, signature (PencilKit), stamp scanning (camera, transparent PNG, clean-up slider) | Built, unit-tested |
| Dictation and line-item parsing: English, French, Spanish, Italian, Simplified Chinese | Built, unit-tested on written phrases |
| Freemium paywall: 5 free invoices a month, Pro monthly and yearly (StoreKit 2) | Built, needs App Store Connect products |
| Siri ("New invoice in VoiceInvoice"), Home/Lock Screen widget, Control Center control and Action Button | Built, needs a real device |
| Voice profiles: enrollment with consent, up to 3 voices, speaker identification, per-line attribution | Built (lightweight on-device model), needs real-voice testing |
| Localization: UI, PDF labels, permission prompts in 5 languages | Built (machine-written translations, review before release) |

## Known limits

- **Speaker identification** uses a small MFCC-based model, tested on synthetic voices only. It identifies who started a dictation; it does not separate overlapping speakers or gate the transcript by voice, and there is no always-on wake-phrase mode. Accuracy in noisy shops is unmeasured. It is a convenience label, not security.
- **Siri phrases** are English only. Other languages need a localized App Shortcuts file.
- **Foundation Models** parsing (Apple Intelligence) is not wired in yet; every device uses the rule-based parser.
- **Widgets and controls** need iOS 18. The app itself runs on iOS 17.
- Translations were written by an AI and should be reviewed by native speakers.

## Build

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
open VoiceInvoice.xcodeproj
```

GitHub Actions (`.github/workflows/ios.yml`) builds and runs the unit tests on every push.

String catalogs are generated from `tools/translations.txt`:

```bash
python tools/build_catalogs.py
```

## Releasing (Codemagic to TestFlight)

`codemagic.yaml` builds a signed `.ipa` (app and widget extension) and uploads it to TestFlight. Before the first run:

1. **Apple Developer Program** membership and App IDs in the developer portal:
   - `com.abdersrdi.voiceinvoice` with **iCloud (CloudKit)** and **App Groups**
   - `com.abdersrdi.voiceinvoice.widgets` with **App Groups**
   - iCloud container `iCloud.com.abdersrdi.voiceinvoice` and app group `group.com.abdersrdi.voiceinvoice`
2. An **App Store Connect** app record for the main bundle ID.
3. In App Store Connect, a subscription group with products `com.abdersrdi.voiceinvoice.pro.monthly` ($4.99/month) and `com.abdersrdi.voiceinvoice.pro.yearly` ($39.99/year, 7-day free trial).
4. An **App Store Connect API key** (Users and Access > Integrations), added in Codemagic under Teams > Integrations > App Store Connect, named `VoiceInvoice`.
5. A Codemagic variable group `signing` containing a secure variable `CERTIFICATE_PRIVATE_KEY` (an RSA private key, for example from `ssh-keygen -t rsa -b 2048 -m PEM -f cert_key -q -N ""`).
6. Add this repo in Codemagic, choose `codemagic.yaml`, set `APP_STORE_APPLE_ID` in the file to the app's numeric Apple ID, and start the `ios-testflight` workflow manually.
