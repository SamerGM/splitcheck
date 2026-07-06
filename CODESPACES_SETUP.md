# SplitCheck — Run in GitHub Codespaces

Step-by-step. Follow in exact order.

---

## Step 1 — Open Codespace

1. Go to your GitHub repo
2. Click the green **Code** button
3. Click **Codespaces** tab
4. Click **Create codespace on main**
5. Wait ~1 minute for VS Code to open in your browser

---

## Step 2 — Install Flutter

Open the terminal (Ctrl + `) and run these one at a time:

```bash
git clone https://github.com/flutter/flutter.git -b stable --depth 1 ~/flutter
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
flutter precache --android
flutter doctor
```

Wait about 5 minutes. You should see green checkmarks for Flutter and Android toolchain.

---

## Step 3 — Get packages

```bash
cd /workspaces/splitcheck
flutter pub get
```

---

## Step 4 — Run as web app (test immediately, no phone needed)

```bash
flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0
```

Codespaces will show a popup **"Open in Browser"** — click it.
SplitCheck opens in a new tab. Voice input works in Chrome.

Note: ML Kit OCR does not work in the web build — it only works on Android.
The rest of the app (names, items, extras, split, share) works fully.

---

## Step 5 — Build Android APK (test on real phone)

```bash
flutter build apk --debug
```

File location: `build/app/outputs/flutter-apk/app-debug.apk`

To download:
- In the Codespace file explorer (left sidebar)
- Navigate to `build/app/outputs/flutter-apk/`
- Right-click `app-debug.apk` → **Download**

To install on your phone:
1. Copy the APK to your Android phone (via USB or send to yourself)
2. On your phone: Settings → Security → Allow install from unknown sources
3. Open the APK file on your phone → Install

---

## Step 6 — Build release AAB for Play Store

First, generate your signing keystore (do this once only — save the file!):

```bash
keytool -genkey -v \
  -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -alias upload
```

Fill in: your name, organisation (can be anything), city, country.
Set a password — remember it, you'll need it forever.

Create `android/key.properties`:

```
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=/root/upload-keystore.jks
```

Build the AAB:

```bash
flutter build appbundle --release
```

File: `build/app/outputs/bundle/release/app-release.aab`
Download this file — this is what you upload to Play Store.

---

## Step 7 — Submit to Play Store

1. Go to play.google.com/console
2. Click **Create app**
3. Fill in: App name = SplitCheck, language, free, not for children
4. Under **Release** → **Production** → **Create release**
5. Upload the `.aab` file
6. Fill in store listing:
   - Short description (80 chars)
   - Full description
   - Screenshots (at least 2 phone screenshots)
   - App icon (512×512 PNG, no rounded corners — Google adds them)
7. Complete the content rating questionnaire
8. Set pricing: Free
9. Select countries
10. Click **Submit for review**

Review takes 3–7 days for new developer accounts.

---

## Important — save your keystore!

Download `upload-keystore.jks` from the Codespace before you close it.
If you lose this file you can NEVER update your app on Play Store.

In the file explorer: find `/root/upload-keystore.jks`
Right-click → Download
Store it somewhere safe (Google Drive, email to yourself, USB drive).

---

## Stop the Codespace when done

Go to github.com/codespaces
Click the `...` menu next to your codespace → **Stop codespace**
This stops the free hour counter.

Free tier: 60 hours/month — more than enough.
