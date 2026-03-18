# RaymanPatcher – iOS Xcode Setup Guide

A native iOS (SwiftUI) port of the Python/batch Rayman Classic Patcher.  
Applies the full 5-layer Wi-Fi fix + Ultrawide plist patch directly on your iPhone.

---

## 1 — Create the Xcode Project (on your macOS VM)

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App** → Next
3. Fill in:
   - **Product Name**: `RaymanPatcher`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Bundle Identifier**: anything you like, e.g. `com.yourname.RaymanPatcher`
4. Save to Desktop (or anywhere convenient)
5. **Delete** the auto-generated `ContentView.swift` that Xcode creates

---

## 2 — Add Swift Files

Copy these 5 files from `iOS_Xcode_Project/RaymanPatcher/` into your Xcode project  
(drag them onto the project navigator, tick **"Copy items if needed"**):

| File | Description |
|------|-------------|
| `RaymanPatcherApp.swift` | App entry point |
| `ContentView.swift` | SwiftUI UI — dark themed, file picker, live log |
| `PatchEngine.swift` | All 5 binary patch layers (ARM64 byte patches) |
| `PlistPatcher.swift` | Ultrawide Info.plist inject |
| `IPAProcessor.swift` | Unzip → patch → rezip orchestrator |

---

## 3 — Add ZipFoundation (Swift Package)

The app uses [ZipFoundation](https://github.com/weichsel/ZipFoundation) for unzipping and repacking the IPA.

1. In Xcode: **File → Add Package Dependencies…**
2. Paste URL: `https://github.com/weichsel/ZipFoundation`
3. Set version rule: **Up to Next Major** from `0.9.0`
4. Click **Add Package** → select the `ZipFoundation` library → **Add to RaymanPatcher**

---

## 4 — Info.plist Entries

In your project's `Info.plist` (or via Xcode's **Signing & Capabilities / Info** tab) add:

```xml
<key>UIFileSharingEnabled</key><true/>
<key>LSSupportsOpeningDocumentsInPlace</key><true/>
<key>UISupportsDocumentBrowser</key><true/>
<key>NSDocumentsFolderUsageDescription</key>
<string>Needed to read and save the Rayman .ipa file.</string>
```

---

## 5 — Build and Run

- Select your iPhone (or iOS Simulator) as the run destination
- Press **⌘R** to Build & Run
- On a real device you need a **free Apple ID** in Signing & Capabilities → Team, with automatic signing enabled

---

## 6 — Using the App

1. Get a Rayman Classic `.ipa` onto your device (e.g. via AltStore, Filza, or any file sharing app)
2. Tap **Select Rayman .ipa** → pick the file
3. Tap **Start Patch**
4. Watch the live log — all 5 layers + ultrawide plist will be applied
5. Tap **Share / Export IPA** to send the patched IPA to AltStore, Sideloadly, etc.

---

## How the Patch Works (Quick Reference)

| Layer | What | How |
|-------|------|-----|
| 1 | Spark Engine null-pointer guard | Overwrite 40 bytes at `0x3e5eb0` + `0x3e5f20` |
| 2 | Kill Reachability + Analytics | Write `mov x0,#0; ret` (8 bytes) at 21 addresses |
| 3 | Hijack telemetry domains | Find/replace byte strings (e.g. `ubi.com→xxx.com`) |
| 4 | CBZ ifa_addr null checks | Overwrite 24 bytes at 6 `getifaddrs` loop sites |
| 5 | Sever C-network stubs | Write `mov x0,#-1; ret` (8 bytes) at 4 Mach-O stubs |
| UW | Ultrawide screen unlock | Inject `UILaunchImages` in `Info.plist`, remove storyboard key |
