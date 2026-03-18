import SwiftUI
import UniformTypeIdentifiers



// MARK: - ContentView
// Main SwiftUI screen for the Rayman Classic Patcher iOS app.
// Styled with a dark, game-inspired UI.

struct ContentView: View {

    @State private var isPickerPresented = false
    @State private var isProcessing      = false
    @State private var logLines: [String] = []
    @State private var outputURL: URL?   = nil
    @State private var isSharePresented  = false
    @State private var errorMessage: String? = nil

    // The selected IPA URL (scoped security-scoped resource)
    @State private var selectedIPA: URL? = nil

    var body: some View {
        ZStack {
            // ---- Background gradient -----------------------------------------
            LinearGradient(
                colors: [Color(hex: "#0d0d1a"), Color(hex: "#1a0a2e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {

                // ---- Header --------------------------------------------------
                VStack(spacing: 6) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 54))
                        .foregroundColor(Color(hex: "#f5a623"))
                        .shadow(color: Color(hex: "#f5a623").opacity(0.6), radius: 12)

                    Text("Rayman Patcher")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("Wi-Fi Crash Fix + Ultrawide")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#a0a0c0"))
                }
                .padding(.top, 20)

                // ---- IPA Selector --------------------------------------------
                Button(action: { isPickerPresented = true }) {
                    HStack {
                        Image(systemName: selectedIPA == nil ? "doc.badge.plus" : "doc.fill")
                            .font(.title3)
                        Text(selectedIPA?.lastPathComponent ?? "Select Rayman .ipa")
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(hex: "#2a1f4a"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(hex: "#6644cc"), lineWidth: 1.5)
                            )
                    )
                }
                .fileImporter(
                    isPresented: $isPickerPresented,
                    allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        selectedIPA = urls.first
                        outputURL = nil
                        errorMessage = nil
                        logLines = []
                    case .failure(let err):
                        errorMessage = err.localizedDescription
                    }
                }

                // ---- Patch Button --------------------------------------------
                Button(action: startPatching) {
                    HStack(spacing: 10) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "flame.fill")
                        }
                        Text(isProcessing ? "Patching…" : "Start Patch")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                selectedIPA != nil && !isProcessing
                                    ? Color(hex: "#f5a623")
                                    : Color.gray.opacity(0.35)
                            )
                    )
                    .foregroundColor(selectedIPA != nil && !isProcessing ? .black : .gray)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .disabled(selectedIPA == nil || isProcessing)

                // ---- Log Console ---------------------------------------------
                if !logLines.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(Array(logLines.enumerated()), id: \.offset) { idx, line in
                                    Text(line)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(logColor(for: line))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(idx)
                                }
                            }
                            .padding(12)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 260)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "#0a0a16"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#2a2a4a"), lineWidth: 1)
                                )
                        )
                        .onChange(of: logLines.count) { _ in
                            withAnimation { proxy.scrollTo(logLines.count - 1, anchor: .bottom) }
                        }
                    }
                }

                // ---- Error Banner -------------------------------------------
                if let err = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(err).font(.footnote).lineLimit(3)
                    }
                    .foregroundColor(.red)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.15)))
                }

                // ---- Success / Share -----------------------------------------
                if let out = outputURL, !isProcessing {
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Patched IPA ready!")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }

                        Button(action: {
                            // Copy back to tmp with exact original name, because iOS Share Sheet
                            // cleans up tmp files automatically after the first share.
                            // The original name stops SideStore from Sandbox/parsing errors.
                            let fm = FileManager.default
                            let tempShareURL = fm.temporaryDirectory.appendingPathComponent(out.lastPathComponent)
                            try? fm.removeItem(at: tempShareURL)
                            try? fm.copyItem(at: out, to: tempShareURL)
                            isSharePresented = true
                        }) {
                            Label("Share / Export IPA", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(hex: "#1a3a1a"))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.green.opacity(0.5), lineWidth: 1.5)
                                        )
                                )
                                .foregroundColor(.green)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .sheet(isPresented: $isSharePresented) {
                            let fm = FileManager.default
                            let tempShareURL = fm.temporaryDirectory.appendingPathComponent(out.lastPathComponent)
                            ShareSheet(items: [tempShareURL])
                        }
                    }
                }

                Spacer()

                // ---- Footer --------------------------------------------------
                VStack(spacing: 4) {
                    Text("Made by JustMLC")
                        .font(.footnote)
                        .foregroundColor(Color(hex: "#a0a0c0"))
                    Link("GitHub Repository", destination: URL(string: "https://github.com/JustMLC4real/Rayman-Classic-Patcher")!)
                        .font(.footnote)
                        .foregroundColor(Color(hex: "#6644cc"))
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 20)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Actions
    // -------------------------------------------------------------------------

    private func startPatching() {
        guard let ipa = selectedIPA else { return }
        logLines = []
        outputURL = nil
        errorMessage = nil
        isProcessing = true

        Task.detached(priority: .userInitiated) {
            // Must start accessing the security-scoped resource
            let accessed = ipa.startAccessingSecurityScopedResource()
            defer { if accessed { ipa.stopAccessingSecurityScopedResource() } }

            // Copy IPA to a writable temp location first
            let fm = FileManager.default
            let tmpIPA = fm.temporaryDirectory.appendingPathComponent(ipa.lastPathComponent)
            try? fm.removeItem(at: tmpIPA)

            do {
                try fm.copyItem(at: ipa, to: tmpIPA)

                var processor = IPAProcessor()
                processor.log = { line in
                    Task { @MainActor in logLines.append(line) }
                }
                let result = try processor.process(ipaURL: tmpIPA)

                // Move result to documents so Files.app can see it
                let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let finalURL = docsURL.appendingPathComponent(result.lastPathComponent)
                try? fm.removeItem(at: finalURL)
                try fm.moveItem(at: result, to: finalURL)

                Task { @MainActor in
                    outputURL   = finalURL
                    isProcessing = false
                }
            } catch {
                Task { @MainActor in
                    errorMessage = error.localizedDescription
                    logLines.append("❌ Error: \(error.localizedDescription)")
                    isProcessing = false
                }
            }
        }
    }

    // ---- Log line color helper
    private func logColor(for line: String) -> Color {
        if line.hasPrefix("✅") || line.hasPrefix("✓") { return Color(hex: "#44ff88") }
        if line.hasPrefix("❌") || line.hasPrefix("⚠️") { return Color(hex: "#ff6655") }
        if line.hasPrefix("  [") { return Color(hex: "#c8aaff") }
        return Color(hex: "#a0bfff")
    }
}

// MARK: - UIActivityViewController wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Color hex helper

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        let int = UInt64(h, radix: 16) ?? 0
        let r = Double((int >> 16) & 0xff) / 255
        let g = Double((int >>  8) & 0xff) / 255
        let b = Double( int        & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
