# Apple setup guide (no Mac needed)

Everything below is done in a web browser. Menu names are from memory of Apple's current
sites and may have moved slightly; the ideas stay the same.

Names used in this project (change them everywhere if you pick different ones):

| Item | Value |
|---|---|
| App bundle ID | `cc.voiceinvoice.app` |
| Widget bundle ID | `cc.voiceinvoice.app.widgets` |
| App Group | `group.cc.voiceinvoice.app` |
| iCloud container | `iCloud.cc.voiceinvoice.app` |
| Subscription products | `cc.voiceinvoice.app.pro.monthly`, `cc.voiceinvoice.app.pro.yearly` |

## 1. Join the Apple Developer Program

1. Go to <https://developer.apple.com/programs/enroll/> and sign in with your Apple ID (two-factor authentication must be on).
2. Choose **Individual** (fastest) or **Organization** (needs a D-U-N-S number).
3. Pay the yearly fee. Approval can take minutes to a couple of days.

## 2. Register the identifiers (App Group, iCloud container, two App IDs)

Open <https://developer.apple.com/account/resources/identifiers/list>.

### 2a. App Group
1. Click **+**, choose **App Groups**, Continue.
2. Description `VoiceInvoice`, Identifier `group.cc.voiceinvoice.app`. Continue, Register.

### 2b. iCloud container
1. Click **+**, choose **iCloud Containers**, Continue.
2. Description `VoiceInvoice`, Identifier `iCloud.cc.voiceinvoice.app`. Continue, Register.

### 2c. The app's App ID
1. Click **+**, choose **App IDs**, Continue, choose **App**, Continue.
2. Description `VoiceInvoice`. Bundle ID: **Explicit**, `cc.voiceinvoice.app`.
3. In Capabilities tick:
   - **App Groups**, then **Configure** and select `group.cc.voiceinvoice.app`.
   - **iCloud**, tick **Include CloudKit support**, then **Configure** and select `iCloud.cc.voiceinvoice.app`.
   - **In-App Purchase** is normally already on.
4. Continue, Register.

### 2d. The widget's App ID
1. Click **+**, **App IDs**, **App**.
2. Description `VoiceInvoice Widgets`, Bundle ID **Explicit** `cc.voiceinvoice.app.widgets`.
3. Tick **App Groups**, Configure, select `group.cc.voiceinvoice.app`. Continue, Register.

Microphone, speech recognition and camera need no capability: the app only declares usage descriptions.

## 3. Register your iPhone (for the development build)

1. On the iPhone: Settings > General > About, and find the **UDID** (or connect it to any computer and read it in a UDID lookup tool).
2. Developer portal > **Devices** > **+**, choose iOS, enter a name and the UDID.

## 4. Create the app in App Store Connect

1. <https://appstoreconnect.apple.com> > **Apps** > **+** > **New App**.
2. Platform iOS, Name `VoiceInvoice` (if taken, pick a variant such as `VoiceInvoice Pro`), Primary language English, Bundle ID `cc.voiceinvoice.app` from the dropdown, any SKU.
3. After creating it, open **App Information** and note the numeric **Apple ID**. Put it in `codemagic.yaml` as `APP_STORE_APPLE_ID`.

### Agreements, tax and banking (required for subscriptions)
**Business** (or **Agreements, Tax, and Banking**) > accept the **Paid Apps Agreement**, then add your bank account and tax forms.

### Subscriptions
1. In the app: **Monetization** > **Subscriptions** > create a group `VoiceInvoice Pro`.
2. Add `cc.voiceinvoice.app.pro.monthly`: duration 1 month, price $4.99.
3. Add `cc.voiceinvoice.app.pro.yearly`: duration 1 year, price $39.99.
4. On the yearly product add an **Introductory Offer**: Free, 1 week, all territories.
5. Fill the display name and description for each language you ship and add the review screenshot Apple asks for.

## 5. Connect Codemagic

1. **App Store Connect API key**: App Store Connect > **Users and Access** > **Integrations** > **App Store Connect API** > **Team Keys** > **+**. Name it, access **App Manager** (or Admin). Download the `.p8` file (only once), and note the **Issuer ID** and **Key ID**.
2. In Codemagic: **Teams** > **Integrations** > **App Store Connect** > **Connect**. Name it exactly `VoiceInvoice`, enter the Issuer ID and Key ID and upload the `.p8`.
3. **Certificate private key**: in a terminal (Windows 10/11 has `ssh-keygen`):

   ```bash
   ssh-keygen -t rsa -b 2048 -m PEM -f cert_key -q -N ""
   ```

   Open `cert_key` (the file without `.pub`) and copy the whole text including the BEGIN and END lines. Do not commit this file anywhere.
4. In Codemagic: **Teams** > **Global variables and secrets** > create a group `signing` with a **secure** variable `CERTIFICATE_PRIVATE_KEY` holding that text.
5. **Add application** in Codemagic, choose this GitHub repo, and pick **codemagic.yaml** as the configuration.

## 6. First run: the development build (important)

TestFlight and App Store builds use the **Production** iCloud environment, where the app cannot create its own iCloud record types. Record types are created automatically only by **development-signed** builds, in the **Development** environment. So:

1. In Codemagic, start the **ios-development** workflow. When it finishes, open the build page on your iPhone and tap **Install** (your iPhone must be registered in step 3). Trust the developer profile if iOS asks (Settings > General > VPN & Device Management).
2. Open the app, signed in to iCloud on the phone, and **use every part once**: create the shop, create an invoice with lines, add a team member and enroll a voice. Each kind of saved data creates its record type.
3. Wait a minute, then open the **CloudKit Console**: <https://icloud.developer.apple.com> > your container `iCloud.cc.voiceinvoice.app` > **Schema**. You should see record types such as `CD_Invoice`, `CD_InvoiceLine`, `CD_StoreProfile` and `CD_Employee` in the Development environment.
4. Click **Deploy Schema Changes...** (to Production) and confirm.

Skipping this means iCloud sync silently does nothing in TestFlight and App Store builds. The app still works, but only locally.

## 7. TestFlight

1. Start the **ios-testflight** workflow in Codemagic. It uploads the build.
2. In App Store Connect > **TestFlight**, add yourself as an internal tester. Install **TestFlight** on the iPhone and install the build.
3. Test with the checklist in `docs/TEST_CHECKLIST.md`.

## Common problems

| Problem | Cause and fix |
|---|---|
| Signing step fails with "No matching profile" | The App ID is missing a capability, or the widget App ID is not registered. Re-check section 2. |
| Development build cannot be installed | The iPhone UDID is not registered (section 3), or you registered it after the profile was created. Re-run the workflow. |
| Widget does not show data | The App Group is not ticked on both App IDs, or the two App IDs are not in the same group. |
| Sync does nothing in TestFlight | The schema was not deployed to Production (section 6, step 4). |
| "Maximum number of certificates reached" | Apple allows a few distribution certificates. Revoke an unused one in the developer portal and re-run. |
| Subscriptions show "Prices are not available" | Products not created or not approved yet, or the Paid Apps Agreement is not active. TestFlight can use them in sandbox once created. |
