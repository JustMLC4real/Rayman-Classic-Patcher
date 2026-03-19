# Rayman Classic Patcher

A lightweight iOS patcher for **Rayman Classic** that fixes the well-known **Wi-Fi crash** and adds **ultrawide / full-screen support**.

The app imports a `.ipa`, patches the internal `Rayman` binary, updates `Info.plist` for modern screen sizes, and exports a new patched file named:

```text
<OriginalName>_Ultimate_Patched.ipa
```

## Features

- Fixes the Rayman Classic crash when Wi-Fi / networking is enabled
- Applies a **5-layer binary patch** to the `Rayman` executable
- Adds **ultrawide support** by patching `Info.plist`
- Rebuilds the modified app into a new `.ipa`
- Simple SwiftUI interface for importing and exporting patched files
- Supports iPhone and iPad
- Can also be installed directly from the **JustMLC SideStore Source**

## What this patcher does

The patcher performs two main actions.

### 1) Binary patching
The patcher locates the `Rayman` executable inside the `.ipa` and applies the Wi-Fi crash fix through a multi-layer binary patch.

The source code describes this as a **5-layer Rayman Wi-Fi patcher**.

### 2) Ultrawide `Info.plist` patching
The patcher updates the app's `Info.plist` to better support modern aspect ratios.

This includes:

- removing `UILaunchStoryboardName`
- injecting `UILaunchImages` entries for common ultrawide iPhone and iPad sizes
- enabling file sharing
- enabling opening documents in place

## How it works

1. Import the original `.ipa`
2. Extract the archive
3. Locate `Payload/*.app`
4. Patch the `Rayman` binary
5. Patch `Info.plist`
6. Repack everything into a new `.ipa`
7. Export the patched file

## Output

After a successful patch, the app writes a new file in this format:

```text
YourFile_Ultimate_Patched.ipa
```

## App usage

1. Open **Rayman Patcher** on your iPhone or iPad
2. Tap **Select Rayman .ipa**
3. Choose your original Rayman Classic `.ipa`
4. Tap **Start Patch**
5. Wait for the patch process to finish
6. Use **Share / Export IPA** to save or share the patched file

## Install via SideStore

You can also install **Rayman Classic Patcher** directly from the **JustMLC SideStore Source**.

### Source repo
- `https://github.com/JustMLC4real/JustMLC-Source`

### Raw source URL
- `https://raw.githubusercontent.com/JustMLC4real/JustMLC-Source/refs/heads/main/source.json`

### Add it in SideStore

1. Open **SideStore**
2. Go to **Sources**
3. Add this source URL:

```text
https://raw.githubusercontent.com/JustMLC4real/JustMLC-Source/refs/heads/main/source.json
```

4. Refresh sources
5. Search for **Rayman Classic Patcher**
6. Install it directly from the source

## Build requirements

- **Xcode 16.0**
- **iOS 15.0+** deployment target
- **Swift 5**
- Dependency: **ZIPFoundation**

## Building

1. Clone this repository
2. Open `RaymanPatcher.xcodeproj` in Xcode
3. Select your signing team
4. Build and run on your device

## Project structure

```text
Rayman-Classic-Patcher/
├─ RaymanPatcher.xcodeproj
├─ project.yml
└─ RaymanPatcher/
   ├─ ContentView.swift
   ├─ IPAProcessor.swift
   ├─ PatchEngine.swift
   ├─ PlistPatcher.swift
   ├─ RaymanPatcherApp.swift
   ├─ Info.plist
   └─ Assets.xcassets/
```

## Notes

- Use this only with software you are legally allowed to use
- If the expected `Rayman` binary is not found, the binary patch step is skipped
- If `Info.plist` is missing or invalid, the ultrawide patch step is skipped
- The patched file is exported with the suffix `_Ultimate_Patched.ipa`

## Credits

Created by **JustMLC**.

GitHub repo: `JustMLC4real/Rayman-Classic-Patcher`
