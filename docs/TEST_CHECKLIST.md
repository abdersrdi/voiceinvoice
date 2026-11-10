# Test checklist (first TestFlight build)

Tick each item and note anything that looks or behaves wrong. Screenshots help.

## First launch
- [ ] "Looking for your shop in iCloud…" shows briefly, then setup appears
- [ ] Create the shop (name, currency, tax); the invoice list appears
- [ ] The app looks right in light and dark mode, and with large text

## Invoices
- [ ] New invoice by hand: customer, items, discount, tax, due date; totals are right
- [ ] Saving gives a number like `INV-AB-0001`
- [ ] Open the invoice: the PDF preview shows your shop, items and totals
- [ ] Share the PDF to WhatsApp / Mail / Files and open it there
- [ ] A 30-item invoice makes a multi-page PDF
- [ ] Duplicate, delete (with the confirmation), and "Recent customers" in the editor
- [ ] Change status to Sent and Paid

## Shop
- [ ] Add a logo from Photos
- [ ] Draw a signature; it appears at the bottom of the PDF
- [ ] Scan your company stamp with the camera; adjust the slider; it appears on the PDF with a transparent background
- [ ] Change language of the phone to French, Spanish, Italian and Chinese: menus, PDF labels and permission prompts follow

## Dictation (use a real voice, in each language you care about)
- [ ] Say "two shirts at twenty each and a pair of pants for forty": two items with the right prices
- [ ] Mic permission and speech permission prompts appear once and work
- [ ] The top shows "On-device" or "Apple servers"
- [ ] "Use these items" opens the editor with the items filled in
- [ ] Wrong or missing prices are flagged "Check the price"

## Free plan and Pro
- [ ] The list shows "5 of 5 free invoices left", counting down after each saved invoice
- [ ] The 6th invoice opens the paywall; prices and the 7-day trial show
- [ ] Buy with a sandbox tester; the app switches to Pro and invoices are unlimited
- [ ] Restore Purchases works after reinstalling

## Team and voices
- [ ] Add 2 or 3 team members and enroll each voice (consent screen, 3 readings)
- [ ] Dictate as each person: is the right name picked after a few seconds? How often is it wrong?
- [ ] Correct a wrong guess with the chip at the top
- [ ] Delete a voice; turn off "Sync voice"

## Siri, widget, controls
- [ ] "Hey Siri, new invoice in VoiceInvoice" opens the app in dictation
- [ ] The Home Screen widget shows today's total; tapping it opens dictation
- [ ] Add the Lock Screen widget
- [ ] Add the Control Center control and assign it to the Action Button

## iCloud (needs the schema deployed, see APPLE_SETUP.md section 6)
- [ ] Install on a second device (or iPad) signed in to the same Apple ID: the shop and invoices appear
- [ ] Create an invoice on one device; it shows up on the other within a minute or two
