import Foundation
import ZIPFoundation

// MARK: - IPAProcessor
// Orchestrates the full IPA patch workflow:
//   1. Unzip the .ipa into a temp directory
//   2. Locate Payload/*.app/
//   3. Patch the Rayman binary
//   4. Patch Info.plist (ultrawide)
//   5. Rezip back into *_Ultimate_Patched.ipa
//   6. Clean up temp files

enum IPAError: Error, LocalizedError {
    case noPayload
    case noAppBundle
    case zipFailed(String)

    var errorDescription: String? {
        switch self {
        case .noPayload:         return "No Payload/ directory found inside the IPA."
        case .noAppBundle:       return "No .app bundle found inside Payload/."
        case .zipFailed(let m):  return "Zip operation failed: \(m)"
        }
    }
}

struct IPAProcessor {

    var log: (String) -> Void = { _ in }

    // -------------------------------------------------------------------------
    // MARK: Main entry
    // -------------------------------------------------------------------------

    /// - Parameters:
    ///   - ipaURL: The source .ipa file URL (original, unpatched)
    /// - Returns: URL of the newly written *_Ultimate_Patched.ipa
    @discardableResult
    mutating func process(ipaURL: URL) throws -> URL {

        // ---- Prepare temp directory -----------------------------------------
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        // ---- Unzip IPA -------------------------------------------------------
        log("Extracting IPA \(ipaURL.lastPathComponent)...")
        guard let archive = try? Archive(url: ipaURL, accessMode: .read, pathEncoding: .utf8) else {
            throw IPAError.zipFailed("Could not open \(ipaURL.lastPathComponent) as ZIP.")
        }
        for entry in archive {
            let destURL = tempDir.appendingPathComponent(entry.path)
            let destDir  = destURL.deletingLastPathComponent()
            if !fm.fileExists(atPath: destDir.path) {
                try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            }
            _ = try archive.extract(entry, to: destURL)
        }

        // ---- Find Payload/*.app ---------------------------------------------
        let payloadURL = tempDir.appendingPathComponent("Payload", isDirectory: true)
        guard fm.fileExists(atPath: payloadURL.path) else {
            throw IPAError.noPayload
        }

        let appBundleURL: URL = try {
            let contents = try fm.contentsOfDirectory(
                at: payloadURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            guard let app = contents.first(where: { $0.pathExtension == "app" }) else {
                throw IPAError.noAppBundle
            }
            return app
        }()

        log("Found app bundle: \(appBundleURL.lastPathComponent)")

        // ---- Patch Rayman binary --------------------------------------------
        let binaryURL = appBundleURL.appendingPathComponent("Rayman")
        if fm.fileExists(atPath: binaryURL.path) {
            var engine = PatchEngine()
            engine.log = log
            try engine.patch(binaryURL: binaryURL)
        } else {
            log("⚠️  Warning: 'Rayman' binary not found inside .app – skipping binary patch.")
        }

        // ---- Patch Info.plist -----------------------------------------------
        let plistURL = appBundleURL.appendingPathComponent("Info.plist")
        var plistPatcher = PlistPatcher()
        plistPatcher.log = log
        try plistPatcher.patch(plistURL: plistURL)

        // ---- Repack into new IPA --------------------------------------------
        let outputName = ipaURL.deletingPathExtension().lastPathComponent
            + "_Ultimate_Patched.ipa"
        let outputURL = ipaURL.deletingLastPathComponent()
            .appendingPathComponent(outputName)

        log("Repacking → \(outputName)...")
        if fm.fileExists(atPath: outputURL.path) {
            try fm.removeItem(at: outputURL)
        }

        // ZipFoundation: create archive from tempDir contents
        guard let outArchive = try? Archive(url: outputURL, accessMode: .create, pathEncoding: .utf8) else {
            throw IPAError.zipFailed("Could not create output archive.")
        }

        // Walk every file under tempDir and add it to the archive
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
        let enumerator = fm.enumerator(
            at: tempDir,
            includingPropertiesForKeys: resourceKeys,
            options: [],
            errorHandler: nil
        )!
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            if resourceValues.isDirectory == true { continue } // directories are implicit

            // Build relative path inside the ZIP (mirrors original IPA structure)
            let relativePath = String(
                fileURL.path.dropFirst(tempDir.path.count + 1)  // remove tempDir prefix + "/"
            )

            try outArchive.addEntry(
                with: relativePath,
                fileURL: fileURL,
                compressionMethod: .none   // IPA must use Store for the binary
            )
        }

        log("✅ SUCCESS! Patched IPA saved to:\n   \(outputURL.path)")
        return outputURL
    }
}
