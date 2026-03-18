import Foundation

// MARK: - PlistPatcher
// Swift port of patch_ultrawide_plist() from wifi_patcher.py.
// Injects UILaunchImages entries for common ultrawide iPhone/iPad sizes
// and removes UILaunchStoryboardName so the game fills the full screen.

struct PlistPatcher {

    var log: (String) -> Void = { _ in }

    mutating func patch(plistURL: URL) throws {
        guard FileManager.default.fileExists(atPath: plistURL.path) else {
            log("  [UW] Info.plist not found – skipping ultrawide patch.")
            return
        }

        log("  [UW] Applying Ultrawide constraints to Info.plist...")

        // Read existing plist
        let rawData = try Data(contentsOf: plistURL)
        guard var plist = try PropertyListSerialization.propertyList(
            from: rawData,
            options: [],
            format: nil
        ) as? [String: Any] else {
            log("  [UW] Warning: could not parse Info.plist – skipping.")
            return
        }

        // Remove launch storyboard so UILaunchImages takes effect
        plist.removeValue(forKey: "UILaunchStoryboardName")

        // Screen sizes matching Python original (portrait logical points)
        let sizes: [String] = [
            "{375, 812}", "{414, 896}", "{390, 844}", "{428, 926}",
            "{393, 852}", "{430, 932}", "{402, 874}", "{440, 956}",
            "{834, 1194}", "{1024, 1366}"
        ]

        var uwImages: [[String: String]] = []
        for size in sizes {
            uwImages.append([
                "UILaunchImageMinimumOSVersion": "8.0",
                "UILaunchImageName":             "LaunchImage",
                "UILaunchImageOrientation":      "Landscape",
                "UILaunchImageSize":             size
            ])
            uwImages.append([
                "UILaunchImageMinimumOSVersion": "8.0",
                "UILaunchImageName":             "LaunchImage-Landscape",
                "UILaunchImageOrientation":      "Landscape",
                "UILaunchImageSize":             size
            ])
        }

        plist["UILaunchImages"] = uwImages

        // Enable File Sharing so the app appears in iOS Files & iTunes
        plist["UIFileSharingEnabled"] = true
        plist["LSSupportsOpeningDocumentsInPlace"] = true

        // Write binary plist back
        let outData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .binary,
            options: 0
        )
        try outData.write(to: plistURL, options: .atomic)
        log("  [UW] Info.plist updated for Ultrawide + File Sharing ✓")
    }
}
