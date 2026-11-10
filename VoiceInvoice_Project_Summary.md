# Talkstamp: Summary

Hands-free invoicing for small merchants on iPhone and iPad. Dictate line items, the app builds the invoice, adds the shop's stamp and signature, and exports a PDF. On-device processing, synced through the shop's own iCloud account, no backend.

## Key decisions
- **Platform:** iOS and iPadOS only (SwiftUI).
- **Languages:** English, French, Spanish, Italian, Simplified Chinese.
- **Parsing:** Foundation Models on Apple Intelligence devices, rule-based fallback elsewhere.
- **Voice profiles:** up to 3 voices per shop, speaker identification on a wake phrase, voiceprints synced with consent.
- **Entry points:** Siri, Action Button, Control Center, widgets.
- **Sync:** SwiftData + CloudKit, one iCloud account per shop.
- **Business model:** freemium, 5 invoices per month free, monthly and yearly subscriptions.

Full details: [VoiceInvoice_Complete_Project_Total_Specifications.md](VoiceInvoice_Complete_Project_Total_Specifications.md)
