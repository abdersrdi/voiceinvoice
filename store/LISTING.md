# Talkstamp: App Store listing (English, US)

Everything below is ready to paste into App Store Connect. Items marked **YOU** need your input.

Character limits are Apple's. Counts are given so you can check them.

## App information

| Field | Value | Limit |
|---|---|---|
| Name | **YOU: the name you saved (I recommend `Talkstamp`)** | 30 |
| Subtitle | `Voice invoices with your stamp` (30) | 30 |
| Primary category | Business | |
| Secondary category | Productivity | |
| Age rating | 4+ (no objectionable content, no web access, no user-generated content shared with others) | |
| Price | Free, with in-app subscriptions | |
| Privacy policy URL | https://github.com/abdersrdi/voiceinvoice/blob/main/PRIVACY.md (draft: review it first) | |
| Support URL | **YOU** (a page or an email-based contact page; a GitHub issues page is acceptable: https://github.com/abdersrdi/voiceinvoice/issues) | |
| Marketing URL | optional | |
| Copyright | **YOU**: `2026 <your name>` | |

## Promotional text (170 max; can be changed without a new version)

```
Say the items and prices, review, and send a finished PDF invoice with your company stamp and signature. Works in five languages.
```
(129 characters)

## Keywords (100 max, comma-separated, no spaces after commas)

```
invoice,voice,dictation,stamp,signature,receipt,billing,small business,pdf,seal,freelance,shop
```
(94 characters). Rules followed: no app name, no competitor names, no category words Apple already indexes, no features the app doesn't have.

## Description (4000 max)

```
Talkstamp turns what you say into a finished invoice.

Say "two shirts at 20 each and a pair of pants for 40" and Talkstamp builds the line items for you. Check them, add your customer, and send a clean PDF with your logo, company stamp and signature on it.

SPEAK, DON'T TYPE
- Dictate items, quantities and prices in English, French, Spanish, Italian or Simplified Chinese.
- Understands spoken numbers ("one hundred and fifty", "quatre-vingt-dix", "treinta y cinco").
- Anything unclear is flagged so you can fix it before sending.
- On supported devices, Apple Intelligence helps read messy sentences.

YOUR STAMP AND SIGNATURE
- Scan your company stamp with the camera. Talkstamp removes the paper and keeps the ink.
- Draw your signature with your finger or Apple Pencil.
- Both appear on every PDF.

BUILT FOR A BUSY COUNTER
- Counter mode: leave the screen on and say "New invoice" to start.
- Voice profiles for up to three people, so each invoice shows who dictated it.
- Siri, a Home Screen and Lock Screen widget, and a Control Center button.

INVOICES YOUR CUSTOMERS CAN READ
- Write each invoice in English, French, Spanish, Italian or Simplified Chinese, whatever language your customer reads.
- Tax, discount, due date, notes and automatic numbering.
- Share the PDF by WhatsApp, Mail, Messages, AirDrop or Files.

PRIVATE BY DESIGN
- No account to create and no server of ours. Your data stays on your devices and in your own iCloud.
- Speech recognition runs on your device when your language supports it, and the app tells you which mode it is using.
- Voice profiles store a numeric voiceprint, never a recording, and only with the person's consent.

FREE TO START
- Create up to 5 invoices every month for free.
- Talkstamp Pro removes the limit. Subscribe monthly or yearly, with a 7-day free trial on the yearly plan. Everything you already made stays free to view, export and share.

Subscription details: payment is charged to your Apple ID at confirmation of purchase. Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Manage or cancel in your Apple ID settings. Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

**Check before you submit:** the "own iCloud" claim is only true once sync has been tested on a real device and the iCloud schema is deployed to Production (see `docs/APPLE_SETUP.md`, section 6). If that is not done by submission, delete "and in your own iCloud" and the sync mention in the paywall text, or the claim will be false.

## What's New (version 1.0)

```
First release.
```

## In-app purchases to create in App Store Connect

| Product ID | Type | Price | Notes |
|---|---|---|---|
| `cc.voiceinvoice.app.pro.monthly` | Auto-renewable, 1 month | $4.99 | |
| `cc.voiceinvoice.app.pro.yearly` | Auto-renewable, 1 year | $39.99 | Introductory offer: free, 1 week |

Display name for both: `Talkstamp Pro`. Description: `Unlimited invoices every month.` Each needs a review screenshot of the paywall (`store/screenshots/` has the app screens; take the paywall one from the screenshot tour, file `07-paywall.png`).

## App Review notes (paste into "Notes")

```
Talkstamp creates invoices from dictation. No account or sign-in is needed.

How to test without speaking:
1. Tap the microphone button at the bottom right of the Invoices tab.
2. Tap in the "What I heard" box and type: Two shirts at 20 each and a pair of pants for 40
3. Tap "Done", then "Use these items". The invoice editor opens with both items filled in.
4. Enter a customer name and tap Save, then open the invoice to see the PDF.

Other features to try:
- Shop tab: add a logo, scan or import a company stamp (the camera needs a real device), draw a signature.
- Counter mode (the radio-waves icon at the top left of Invoices): listens for the phrase "New invoice" while the screen is open. It needs the microphone and speech recognition permission.
- Team & voices (Shop tab): optional voice profiles for up to three people, with a consent screen.

Subscriptions: the free plan allows 5 invoices per month. "Talkstamp Pro" (monthly or yearly) removes the limit. Restore Purchases is on the subscription screen.

Privacy: data stays on the device and the user's own iCloud. Speech recognition uses Apple's Speech framework, on-device when the language supports it.

What makes the app different from other invoice apps: it puts the company stamp and a signature on the PDF, supports several voices at one counter, and writes each invoice in the customer's language.
```

## Screenshots

`store/screenshots/iphone-6.9/` (1320x2868, for the 6.9-inch iPhone slot) and `store/screenshots/ipad-13/` (2064x2752, for the 13-inch iPad slot). Upload in file-name order. App Store Connect scales them for the smaller sizes.

The iPhone Duo is not an App Store screenshot size yet, so it has no slot.

## Before you press Submit

- [ ] App name saved in App Store Connect, trademark searches done
- [ ] Privacy policy reviewed and the URL works
- [ ] Support URL set
- [ ] App Privacy ("nutrition label") answered: no tracking; data not collected from the app by the developer. Voice and audio are processed on device or by Apple's Speech service, not by us.
- [ ] Subscriptions created, a review screenshot added to each, and the subscription group localized
- [ ] Export compliance: the app already declares it uses no non-exempt encryption
- [ ] A build uploaded through Codemagic and selected for this version
- [ ] Sync claims removed from the text if iCloud sync has not been tested on a device
