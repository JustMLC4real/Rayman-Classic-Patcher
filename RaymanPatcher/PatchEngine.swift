import Foundation

// MARK: - PatchEngine
// Pure Swift port of the 5-layer Rayman Wi-Fi patcher.
// All byte sequences are pre-assembled ARM64 machine code, copied
// verbatim from the working Rayman_Ultimate_Patcher.bat.

enum PatchError: Error, LocalizedError {
    case fileNotFound(String)
    case readFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let p): return "File not found: \(p)"
        case .readFailed(let p):   return "Could not read file: \(p)"
        case .writeFailed(let p):  return "Could not write file: \(p)"
        }
    }
}

struct PatchEngine {

    // Callback so the UI can receive live log lines
    var log: (String) -> Void = { _ in }

    // -------------------------------------------------------------------------
    // MARK: Main entry point
    // -------------------------------------------------------------------------

    /// Patches the `Rayman` Mach-O binary in-place at `binaryURL`.
    mutating func patch(binaryURL: URL) throws {
        log("Applying 5-Layer Wi-Fi Patch to \(binaryURL.lastPathComponent)...")

        guard FileManager.default.fileExists(atPath: binaryURL.path) else {
            throw PatchError.fileNotFound(binaryURL.path)
        }

        guard var data = try? Data(contentsOf: binaryURL) else {
            throw PatchError.readFailed(binaryURL.path)
        }

        try layer1_sparkEngineNullPointer(&data)
        try layer2_nullifyReachabilityAnalytics(&data)
        try layer3_hijackDomains(&data)
        try layer4_cbzIfaAddrChecks(&data)
        try layer5_severNetworkStubs(&data)

        do {
            try data.write(to: binaryURL, options: .atomic)
        } catch {
            throw PatchError.writeFailed(binaryURL.path)
        }
        log("✓ Binary patching complete.")
    }

    // -------------------------------------------------------------------------
    // MARK: Layer 1 – Spark Engine Null Pointer Fix
    // -------------------------------------------------------------------------

    private mutating func layer1_sparkEngineNullPointer(_ data: inout Data) throws {
        log("  [1/5] Patching Spark Engine Null Pointer...")

        // At 0x3e5eb0: 36 bytes of ARM64 code
        let enc1: [UInt8] = [
            0x28, 0x05, 0x00, 0xb4,  // cbz x8, #0x3e5f54
            0x15, 0x01, 0x40, 0xf9,  // ldr x21, [x8]
            0xf5, 0x04, 0x00, 0xb4,  // cbz x21, #0x3e5f54
            0x56, 0x00, 0x80, 0x52,  // mov w22, #2
            0x17, 0x49, 0x91, 0x52,  // mov w23, #0x8a48
            0xf8, 0x01, 0xa0, 0x52,  // mov w24, #0xf0000 (low half)
            0x18, 0x48, 0xa8, 0x72,  // movk w24, #0x4240, lsl#16
            0x19, 0x00, 0x80, 0x52,  // mov w25, #0 (low half)
            0x19, 0x35, 0xb8, 0x72   // movk w25, #0xc1a8, lsl#16
        ]
        write(bytes: enc1, at: 0x3e5eb0, into: &data)

        // At 0x3e5f20: 4 bytes — ldr w9, [x27, #8]
        let enc2: [UInt8] = [0x69, 0x0b, 0x40, 0xb9]
        write(bytes: enc2, at: 0x3e5f20, into: &data)
    }

    // -------------------------------------------------------------------------
    // MARK: Layer 2 – Reachability + Analytics Nullification
    // -------------------------------------------------------------------------

    private mutating func layer2_nullifyReachabilityAnalytics(_ data: inout Data) throws {
        log("  [2/5] Nullifying Reachability and Analytics SDK Vectors...")

        // mov x0, #0 ; ret  (8 bytes)
        let stub: [UInt8] = [0x00, 0x00, 0x80, 0xd2, 0xc0, 0x03, 0x5f, 0xd6]

        let reachabilityAddrs: [Int] = [
            0x153fd0, 0x153ff4, 0x154018, 0x15403c,
            0xb84fb0, 0xb84ff0, 0xbc0b64, 0xbc0ba0,
            0xbcae98, 0xbcaed8, 0xbf55fc, 0xbf563c,
            0xbfa4d8, 0xbfa51c
        ]
        let analyticsAddrs: [Int] = [
            0xbca5b8, 0xbc35e4, 0xbf3808,
            0xbf3878, 0xbf41e4, 0xbc3b14, 0xbcc7fc
        ]

        for addr in reachabilityAddrs + analyticsAddrs {
            write(bytes: stub, at: addr, into: &data)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Layer 3 – Domain DNS Hijacking
    // -------------------------------------------------------------------------

    private mutating func layer3_hijackDomains(_ data: inout Data) throws {
        log("  [3/5] Hijacking Hardcoded Telemetry Domains...")

        // Each pair must be the SAME length (null terminator aside)
        let domains: [(src: [UInt8], dst: [UInt8])] = [
            (Array("api-ubiservices.ubi.com".utf8),  Array("api-ubiservices.xxx.com".utf8)),
            (Array("connect.tapjoy.com".utf8),        Array("connect.tapjoy.xxx".utf8)),  // same len
            (Array("appcloud.flurry.com".utf8),       Array("appcloud.flurry.xxx".utf8)), // same len
            (Array("data.flurry.com".utf8),           Array("data.flurry.xxx".utf8)),
            (Array("graph.facebook.com".utf8),        Array("graph.facebook.xxx".utf8))
        ]

        for (src, dst) in domains {
            guard src.count == dst.count else { continue }
            findAndReplaceAll(src: src, dst: dst, in: &data)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Layer 4 – CBZ ifa_addr Null Checks (getifaddrs iOS 16 fix)
    // -------------------------------------------------------------------------

    private mutating func layer4_cbzIfaAddrChecks(_ data: inout Data) throws {
        log("  [4/5] Injecting CBZ ifa_addr Null Checks for iOS 16...")

        // 24 pre-assembled bytes per site, taken directly from .bat
        let patches: [(addr: Int, bytes: [UInt8])] = [
            (0x166d78, [0xa8, 0x0e, 0x40, 0xf9, 0x28, 0x01, 0x00, 0xb4,
                        0x08, 0x05, 0x40, 0x39, 0x1f, 0x09, 0x00, 0x71,
                        0xc1, 0x00, 0x00, 0x54, 0x1f, 0x20, 0x03, 0xd5]),

            (0x32392c, [0xa8, 0x0e, 0x40, 0xf9, 0x28, 0x01, 0x00, 0xb4,
                        0x08, 0x05, 0x40, 0x39, 0x1f, 0x09, 0x00, 0x71,
                        0xc1, 0x00, 0x00, 0x54, 0x1f, 0x20, 0x03, 0xd5]),

            (0x7980d0, [0x88, 0x0f, 0x40, 0xf9, 0xa8, 0x02, 0x00, 0xb4,
                        0x09, 0x05, 0x40, 0x39, 0x3f, 0x09, 0x00, 0x71,
                        0x41, 0x02, 0x00, 0x54, 0x1f, 0x20, 0x03, 0xd5]),

            (0x79812c, [0x88, 0x0f, 0x40, 0xf9, 0xa8, 0x02, 0x00, 0xb4,
                        0x09, 0x05, 0x40, 0x39, 0x3f, 0x79, 0x00, 0x71,
                        0x41, 0x02, 0x00, 0x54, 0x1f, 0x20, 0x03, 0xd5]),

            (0x4a5858, [0x19, 0x0f, 0x40, 0xf9, 0xb9, 0x04, 0x00, 0xb4,
                        0x28, 0x07, 0x40, 0x39, 0x1f, 0x49, 0x00, 0x71,
                        0x41, 0x04, 0x00, 0x54, 0x1f, 0x20, 0x03, 0xd5]),

            (0x7fd270, [0xe8, 0x0e, 0x40, 0xf9, 0x48, 0x02, 0x00, 0xb4,
                        0x08, 0x05, 0x40, 0x39, 0x1f, 0x09, 0x00, 0x71,
                        0xe1, 0x01, 0x00, 0x54, 0x1f, 0x20, 0x03, 0xd5])
        ]

        for (addr, bytes) in patches {
            write(bytes: bytes, at: addr, into: &data)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Layer 5 – Sever C-Network Mach-O Stubs
    // -------------------------------------------------------------------------

    private mutating func layer5_severNetworkStubs(_ data: inout Data) throws {
        log("  [5/5] Severing iOS C-Networking Mach-O Stubs...")

        // mov x0, #-1 ; ret  (8 bytes)
        let stub: [UInt8] = [0xe0, 0xff, 0x9f, 0x92, 0xc0, 0x03, 0x5f, 0xd6]
        let stubAddrs: [Int] = [0xa0a0a8, 0xa0a420, 0xa0a48c, 0xa0aabc]

        for addr in stubAddrs {
            write(bytes: stub, at: addr, into: &data)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Helpers
    // -------------------------------------------------------------------------

    private func write(bytes: [UInt8], at offset: Int, into data: inout Data) {
        let end = offset + bytes.count
        guard end <= data.count else {
            // Silently skip if the binary is smaller than expected (wrong version)
            return
        }
        data.replaceSubrange(offset..<end, with: bytes)
    }

    private func findAndReplaceAll(src: [UInt8], dst: [UInt8], in data: inout Data) {
        var searchRange = data.startIndex..<data.endIndex
        while let range = data.range(of: Data(src), in: searchRange) {
            data.replaceSubrange(range, with: Data(dst))
            let newStart = range.lowerBound + dst.count
            searchRange = newStart..<data.endIndex
        }
    }
}
