# VoiceInvoice PRO: v1 Specification (rev. 2)

Hands-free invoicing for small merchants. The user dictates line items, the app builds the invoice, adds the shop's stamp and signature, and exports a PDF. Everything runs on-device; data syncs through the owner's own iCloud account. No backend.

Platform: iPhone and iPad (SwiftUI). Apple-only by design.

## 1. Decisions locked in

| Topic | Decision |
|---|---|
| Storage and sync | SwiftData + CloudKit private database, one iCloud account per shop (owner or sales lead). The owner decides who uses devices signed into it. No `CKShare`, no server. |
| Store profiles | One store profile per install/account in v1. |
| Voice profiles | Up to 3 enrolled voices per shop. The app identifies who is speaking and responds to one or several voices in a session. |
| Entry points | Siri (App Intents), Action Button, Control Center control, Home and Lock Screen widgets. |
| Languages | English, French, Spanish, Italian, Simplified Chinese at launch. Model-based parsing so later languages cost testing and localization, not new grammar (section 5). |
| Parsing engine | Both: Foundation Models on Apple Intelligence devices, rule-based fallback elsewhere. |
| Voiceprint sync | Yes. Voiceprints sync through the shop's iCloud so employees enroll once, with explicit consent and per-employee opt-out and deletion. |
| Monetization | Freemium with monthly and yearly subscriptions. Free tier: 5 invoices per month. |
| Platform | iOS and iPadOS only. No Android. |
| Brand | App icon recolored to the iPhone 18 Pro palette (Burgundy background, Glacier Blue glyph). See `assets/icon.png`. |
| Reference setup | Shared counter iPad plus the owner's iPhone, same iCloud account. |

## 2. Target users

Shop owners and sales staff with up to 3 people dictating at a counter. They need to produce invoices quickly while their hands are busy, then review and resend them later from another Apple device.

## 3. Core features (v1)

1. **Voice dictation to line items.** Product, quantity, unit price, from natural speech ("two shirts at 20 each and a pair of pants for 40"). Editable list, with manual entry always available.
2. **Invoice basics.** Invoice numbers, tax rate and tax lines, discounts, customer name and details, payment terms and notes, currency, totals.
3. **Store profile.** Name, address, tax ID, logo, default tax rate, currency, header and footer text.
4. **Company stamp.** Camera scan using VisionKit, then background removal (Vision foreground-instance masking) to produce a transparent PNG. A manual cleanup step (crop, threshold, erase) is required. Do not assume automatic results are clean.
5. **Digital signature.** PencilKit canvas, stored as a transparent PNG.
6. **PDF export and sharing.** Generate the PDF on any device and share through the share sheet (WhatsApp, Mail, Messages, AirDrop, Files).
7. **Invoice history.** Search and filter, view and re-share any past invoice on any synced device.
8. **Voice profiles** (section 4).

## 4. Voice profiles and speaker identification

### Goal
With up to three employees near one device, the app works out who is speaking, attributes the invoice to them, and ignores other voices (customers, passers-by).

### Constraints
- Apple's Speech framework returns text only. It has no speaker identification, and Siri does not tell third-party apps who spoke.
- iOS does not allow continuous background listening or custom wake words outside the foreground app.
- A voiceprint is only a convenience filter, never a security boundary. It must not gate editing, deleting or exporting invoices.

### Design
- **Enrollment.** Each employee records a few short samples, including a fixed wake phrase. Consent is recorded at enrollment.
- **Embeddings.** An on-device speaker-embedding Core ML model, converted from an open model after a license check. We do not train our own model.
- **Identification.** The speaker is matched on the wake phrase, where text-dependent matching is far more accurate than arbitrary speech.
- **Session locking.** After a match the session binds to that employee. Later audio segments are checked against the same voice. Segments from other voices are excluded from the transcript.
- **Multiple active voices.** An invoice session can be started by one voice and optionally opened to others ("active voices" list), for example when two staff dictate one order. Each line item records who dictated it.
- **Counter mode.** On a shared iPad the app stays in the foreground with the screen on and listens for the wake phrase. Outside counter mode, a Siri or button start is required.
- **Fallback.** If confidence is low, the app asks "Who's speaking?" and the employee taps their name. This must be fast and is expected to happen often in noisy shops.
- **Attribution.** Every invoice stores `createdBy` (employee record). Voice-less starts (manual or Siri without a match) use the selected employee.

### Privacy
- Voiceprints are biometric data (GDPR special category; Illinois BIPA and similar laws). Collect explicit consent at enrollment and offer one-tap deletion per employee.
- Voiceprints sync through the shop's private CloudKit database so employees enroll once. Enrollment requires explicit, recorded consent that says the voiceprint is stored in the shop's iCloud account, which the account owner controls.
- Each employee can opt out of sync (voiceprint then stays on the enrolling device) and can delete their voiceprint in one tap, which removes it from all devices.
- Store the embedding only, never the raw enrollment audio.
- Disclose in the App Store privacy label.

### Accuracy
Expect degradation from noise, distance, colds and overlapping speech. No accuracy figure is promised until tested on real shop audio. Target for the test plan: reliable identification among 3 voices in typical counter conditions, with a graceful fallback otherwise.

## 5. Speech recognition and parsing

### Pipeline
1. **Transcription.** On-device via `SpeechAnalyzer` / `SFSpeechRecognizer` where the locale supports on-device recognition. Fall back to server recognition with a clear disclosure when a locale is not available offline. Do not claim "100% offline" for every language.
2. **Extraction.** Transcript to structured line items (`name`, `quantity`, `unitPrice`, `currency?`).
   - Primary: Apple's on-device Foundation Models framework, using guided generation into a typed structure.
   - Fallback: rule-based parser for common patterns on devices without Apple Intelligence.
3. **Review.** The merchant confirms or edits every line. Numbers are the highest-risk part of dictation, so the review step is mandatory in v1 and prices are shown prominently.

### Languages
- Coverage is limited by two things: the Speech locale list and the Foundation Models language list. Check Apple's current documentation for both before fixing the launch set.
- Launch set: English, French, Spanish, Italian, Simplified Chinese. Before development, verify that each has on-device speech recognition and Foundation Models support. Any language missing one of the two uses the fallback described below, and the app tells the user which mode is active.
- Language-specific edge cases to test: Chinese number words, French "soixante-dix / quatre-vingt-dix", Italian compound numbers and "euro/euri", Spanish regional number words, spoken decimals and thousands separators, currency words ("bucks", "euros").
- Each language needs a test corpus of spoken invoices, not just translated strings.

### Engine selection
Both engines ship. At runtime the app uses Foundation Models when the device and language support it, and the rule-based parser otherwise. The rule-based parser must cover the five launch languages for the common patterns (quantity, product, "at / each / for" price phrases); accuracy may be lower, which is why the review step is mandatory.

## 6. Apple ecosystem integration

### Siri and App Intents
- Intents: "Create a new invoice", "Add item", "Finish and share invoice", "Show today's total".
- "Create a new invoice" launches the app directly into dictation.
- Siri does not identify the speaker for the app. The app identifies the speaker after launch (section 4).

### Widgets, Action Button, controls
- Widgets (interactive, iOS 17+) cannot record audio or be touchless. They are quick-start surfaces: one tap opens the app already listening.
- Widget content: today's revenue, invoices created today, last invoice status.
- Control Center control and Action Button: start a new voice invoice in one press.
- Lock Screen widget: quick start.
- The truly touchless path is Siri and counter-mode wake phrase, not widgets.

### Live Activities (post-v1)
Optional running total in the Dynamic Island during dictation, updated locally from the foreground app. Not needed for v1.

### iCloud
- SwiftData with CloudKit private database.
- Model constraints: every property optional or defaulted, relationships optional, no unique constraints.
- Invoice numbers must tolerate two devices creating invoices offline, for example a per-device prefix or number assigned at finalize.
- Large images (stamp, signature, logo) use external storage.
- Test conflict handling and offline-then-sync paths explicitly.
- Invoices viewed or shared on another device regenerate the PDF locally from synced data.

### Regional defaults
- Currency and number format from `Locale.current`. No CoreLocation permission in v1.
- Default tax rate set in store profile (with suggested presets by region, user-confirmed).

### Not planned
Continuity Camera is a system feature, not something to build. Stamp scanning on iPad uses the iPad camera or the system Continuity Camera picker where available.

## 7. Data model (outline)

- `StoreProfile`: name, address, taxID, logo, stamp, signature, currency, defaultTaxRate, header, footer, numbering prefix.
- `Employee`: name, createdAt, voiceprint (device-local by default), consentRecordedAt.
- `Customer`: name, contact details.
- `Invoice`: number, date, customer, lines, tax, discount, total, notes, status, createdBy, pdf cache.
- `InvoiceLine`: name, quantity, unitPrice, dictatedBy, rawTranscriptSegment.

## 8. Architecture

- UI: SwiftUI (iOS and iPadOS).
- Voice: Speech framework, on-device where available.
- Speaker ID: Core ML embedding model plus enrollment store.
- Parsing: Foundation Models with rule-based fallback.
- Scanning: VisionKit and Vision.
- Signature: PencilKit.
- Storage: SwiftData + CloudKit.
- Entry points: App Intents, WidgetKit, controls.

## 9. Permissions

Microphone, Speech Recognition, Camera. No location. Each permission needs a clear usage string and a flow that works if it is denied (manual entry and tap-to-select employee).

## 10. Monetization (to decide)

Freemium with auto-renewing subscriptions (StoreKit 2), monthly and yearly.
- **Free:** 5 invoices per month.
- **Paid:** unlimited invoices. Which other features (voice profiles, iCloud sync, widgets) are free versus paid is still to be decided.
- Count invoices by creation month. Exports and re-shares of existing invoices never count and are never blocked, so a user who hits the cap can still send what they already made.
- Pricing and trial length: to be decided.

## 11. Risks, in order

1. Speaker identification accuracy in noisy shops with 3 voices.
2. Dictation accuracy for numbers across languages.
3. Language availability limited by Apple's frameworks.
4. Stamp background removal quality.
5. CloudKit sync edge cases (offline numbering, conflicts).
6. Biometric privacy compliance.

## 12. Suggested build order

1. Data model, store profile, manual invoice, PDF export and share.
2. Stamp and signature.
3. Dictation and extraction in one language, with review UI.
4. Siri intent, controls, widgets.
5. CloudKit sync and cross-device testing.
6. Voice profiles and counter mode.
7. More languages, then Live Activities.

## 13. Open decisions

- Verify Apple's current Speech and Foundation Models support for all five launch languages.
- Subscription pricing, trial length, and which features sit behind the paywall.
- Whether the free tier includes voice profiles and sync, or only basic dictation.
- Exact icon colors: the palette uses approximations of Apple's iPhone 18 Pro Burgundy and Glacier Blue (Apple does not publish hex values). Refine against real product imagery.

Closed: Apple Intelligence requirement (both engines ship), voiceprint sync (on, with consent), Android (out of scope).
