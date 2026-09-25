# VOLTRA Companion — iOS / Apple Health release checklist

Everything in the code is done. What is left is account work and pressing
Build. Do the steps in order.

**Bundle ID (already set everywhere in the project):** `com.voltra.companion`

---

## Step 0 — Push the project to Git  ·  free  ·  10 min

Codemagic builds from a Git repository, so the project has to live on one.

1. Create an empty **private** repo on GitHub (`voltra_app`).
2. Run `VOLTRA_GIT.bat` in this folder. It runs `git init`, `git add .`,
   `git commit`. It does **not** push — it has no credentials.
3. Push it yourself:
   ```
   git remote add origin https://github.com/<you>/voltra_app.git
   git branch -M main
   git push -u origin main
   ```

---

## Step 1 — Free compile check on macOS  ·  free  ·  20 min

Do this **before** paying Apple anything. It proves the iOS + HealthKit code
compiles on a real Mac.

1. Sign up at codemagic.io with the GitHub account (free tier includes
   500 macOS build-minutes/month).
2. Add the `voltra_app` repository.
3. Codemagic reads `codemagic.yaml` automatically. Run the workflow
   **`VOLTRA iOS compile check (unsigned)`**.
4. Green = the code is correct and only signing is left.
   Red = send me the log and I fix it. No Apple account needed either way.

---

## Step 2 — Apple Developer Program  ·  **$99 / year**  ·  15 min + 24–48 h wait

Unavoidable. HealthKit on a physical device and TestFlight both require it.

1. developer.apple.com/programs → Enroll, with the Apple ID you use on the
   iPhone.
2. Enrol as an **Individual** (no D-U-N-S number, no company paperwork).
3. Pay $99. Approval is usually same-day, sometimes up to 48 hours.

---

## Step 3 — App Store Connect API key  ·  free  ·  5 min

1. appstoreconnect.apple.com → Users and Access → **Integrations** → App Store
   Connect API → **+**.
2. Access: **App Manager**. Create it.
3. Download the `.p8` file — **Apple lets you download it exactly once.**
4. Note the **Issuer ID** and the **Key ID** on that page.

---

## Step 4 — Wire the key into Codemagic  ·  free  ·  5 min

1. Codemagic → Teams → Integrations → **Developer Portal** → Connect.
2. Upload the `.p8`, paste the Issuer ID and Key ID.
3. Name the integration exactly: **`VOLTRA_ASC_KEY`**
   (that is the name already written in `codemagic.yaml`. If you name it
   something else, change the `app_store_connect:` line to match.)
4. Codemagic → App settings → Environment variables → create an empty
   variable group named **`voltra_ios`**.

You do **not** need to create the App ID, the certificate, the provisioning
profile, or enable the HealthKit capability by hand. The build step
`app-store-connect fetch-signing-files --create` reads
`ios/Runner/Runner.entitlements` and does all of it.

---

## Step 5 — Register the app in App Store Connect  ·  free  ·  5 min

appstoreconnect.apple.com → Apps → **+** → New App

| Field | Value |
|---|---|
| Platform | iOS |
| Name | VOLTRA Companion |
| Primary language | English (or Arabic) |
| Bundle ID | `com.voltra.companion` |
| SKU | `voltra-companion-001` |

---

## Step 6 — Build to TestFlight  ·  free  ·  25 min

Run the Codemagic workflow **`VOLTRA iOS -> TestFlight`**.

It analyses, installs pods, signs, builds the `.ipa` and uploads it.
You get an email when it lands.

---

## Step 7 — Install on the iPhone  ·  free  ·  10 min

1. App Store → install **TestFlight**.
2. App Store Connect → your app → TestFlight → **Internal Testing** → add your
   own Apple ID as a tester. Internal testers skip Beta App Review entirely —
   the build is available within minutes.
3. Accept the invite in TestFlight, install VOLTRA.

---

## Step 8 — Grant Health access  ·  free  ·  2 min

1. Open VOLTRA → **Apple Health** → **Connect Apple Health**.
2. In the Health sheet, switch **every** category on. If you leave one off,
   that metric shows `NO DATA` — the app will never invent a number for it.
3. Open **VITALS**. The banner must read *Live data — Apple Health*.

If a metric shows `NO DATA` while the Health app does have the data, check
Settings → Health → Data Access & Devices → VOLTRA.

---

## Total

| | |
|---|---|
| Money | **$99 / year** (Apple). Codemagic free tier is enough. |
| Your active time | ~1 hour 15 min |
| Waiting on Apple | 24–48 h for enrolment approval |

---

## What is NOT verified yet

The iOS code is complete and passes static analysis, but it has **never been
compiled by Xcode and never run on an iPhone**. Nothing here should be treated
as working until Step 8 shows live data on the device. Step 1 is deliberately
free so this gets caught before any money is spent.
