import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    @State private var customURL = ""
    @State private var customFilename = ""
    @State private var fileToDelete: String?
    @State private var showDeleteAlert = false
    @State private var isCustomDownloadExpanded = false
    @State private var selectedSnippetIndex = 0
    @State private var copiedSnippet = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    serverStatusCard
                    modelSection
                    controlsSection
                    apiDocumentationCard
                    settingsSection
                    logSection
                }
                .padding()
            }
            .navigationTitle("Pirate LLM Server")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("by pinperepette")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .alert("Delete Model", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let file = fileToDelete {
                    let base = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
                    if appState.isModelLoaded && appState.engine.modelName == base {
                        appState.stopServer()
                        appState.engine.unloadModel()
                        appState.isModelLoaded = false
                    }
                    try? appState.modelManager.deleteModel(named: file)
                }
            }
        } message: {
            Text("Delete \(fileToDelete ?? "")? This cannot be undone.")
        }
    }

    // MARK: - Server Status Card

    private var serverStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(appState.isServerRunning ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(appState.isServerRunning ? "Server Running" : "Server Stopped")
                    .font(.headline)
                Spacer()
                if appState.isServerRunning {
                    Text("Port 8080")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }

            if appState.isServerRunning, !appState.serverURL.isEmpty {
                VStack(spacing: 6) {
                    Text(appState.serverURL)
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundColor(.blue)
                        .textSelection(.enabled)

                    Button {
                        UIPasteboard.general.string = appState.serverURL
                    } label: {
                        Label("Copy Server URL", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    Text("Use this URL with OpenAI-compatible clients")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            memoryIndicator
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var memoryIndicator: some View {
        let mem = NetworkInfo.getMemoryUsage()
        let usedPct = mem.total > 0 ? Double(mem.used) / Double(mem.total) : 0

        return VStack(spacing: 4) {
            HStack {
                Text("RAM Usage")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(NetworkInfo.formatBytes(mem.used)) / \(NetworkInfo.formatBytes(mem.total))")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            ProgressView(value: usedPct)
                .tint(usedPct > 0.85 ? .red : usedPct > 0.7 ? .orange : .blue)
        }
    }

    // MARK: - Model Section

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "cpu")
                Text("Model Management")
                    .font(.headline)
                Spacer()
            }

            if appState.isModelLoaded {
                loadedModelBanner
            }

            localModelsList

            downloadStatusBanner

            presetsList

            customDownloadView
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var loadedModelBanner: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.engine.modelName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text("Loaded in Memory")
                    .font(.caption2)
                    .foregroundColor(.green)
            }

            Spacer()

            Button {
                appState.engine.unloadModel()
                appState.isModelLoaded = false
                if appState.isServerRunning {
                    appState.stopServer()
                }
            } label: {
                Label("Unload", systemImage: "eject")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .padding(10)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var localModelsList: some View {
        let localFiles = appState.modelManager.localModels

        VStack(alignment: .leading, spacing: 8) {
            Text("Local GGUF Models (\(localFiles.count))")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            if localFiles.isEmpty {
                Text("No local models found. Download a preset below or load via iTunes/USB.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(localFiles) { file in
                    let isLoaded = appState.isModelLoaded &&
                        appState.engine.modelName == URL(fileURLWithPath: file.fileName).deletingPathExtension().lastPathComponent

                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(isLoaded ? .green : .blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.fileName)
                                .font(.caption.bold())
                                .lineLimit(1)
                            Text(file.formattedSize)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if isLoaded {
                            Text("Active")
                                .font(.caption2.bold())
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(4)
                        } else {
                            Button("Load") {
                                appState.loadModel(path: file.path)
                            }
                            .buttonStyle(.borderedProminent)
                            .font(.caption)
                        }

                        Button {
                            fileToDelete = file.fileName
                            showDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .padding(8)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }
            }
        }
    }

    @ViewBuilder
    private var downloadStatusBanner: some View {
        switch appState.modelManager.downloadState {
        case .idle:
            EmptyView()

        case .downloading(let progress, let fileName, let bytesWritten, let totalBytes):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Downloading: \(fileName)")
                        .font(.caption.bold())
                        .lineLimit(1)
                    Spacer()
                    Button("Cancel") {
                        appState.modelManager.cancelDownload()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }

                ProgressView(value: progress)

                HStack {
                    if totalBytes > 0 {
                        Text("\(ByteCountFormatter.string(fromByteCount: bytesWritten, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)) (\(Int(progress * 100))%)")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(ByteCountFormatter.string(fromByteCount: bytesWritten, countStyle: .file)) downloaded")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(10)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

        case .completed(let fileName, let path):
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Download Complete")
                        .font(.caption.bold())
                    Text(fileName)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Load") {
                    appState.loadModel(path: path)
                    appState.modelManager.resetDownloadState()
                }
                .buttonStyle(.borderedProminent)
                .font(.caption)

                Button("Dismiss") {
                    appState.modelManager.resetDownloadState()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
            .padding(10)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)

        case .failed(let error):
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Download Failed")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                    Spacer()
                    Button("Dismiss") {
                        appState.modelManager.resetDownloadState()
                    }
                    .font(.caption)
                }
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Button("Retry") {
                    appState.modelManager.retryLastDownload()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
            .padding(10)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private var presetsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            HStack {
                Image(systemName: "square.and.arrow.down.on.square")
                Text("Model Presets")
                    .font(.subheadline.bold())
                Spacer()
                Text("3GB RAM Tested")
                    .font(.caption2)
                    .foregroundColor(.green)
            }

            Text("Models marked with 🌟 fit safely within the 3GB RAM ceiling of devices such as iPhone SE2.")
                .font(.caption2)
                .foregroundColor(.secondary)

            ForEach(ModelManager.presets) { preset in
                presetCard(preset)
            }
        }
    }

    private func presetCard(_ preset: ModelPreset) -> some View {
        let isDownloaded = appState.modelManager.isModelDownloaded(preset: preset)
        let isCurrent = appState.isModelLoaded &&
            appState.engine.modelName == URL(fileURLWithPath: preset.defaultFilename).deletingPathExtension().lastPathComponent

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(preset.name)
                    .font(.subheadline.bold())

                Spacer()

                if preset.isRecommendedForLowRAM {
                    Text("🌟 3GB RAM")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                } else {
                    Text("⚠️ 4GB+ RAM")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }

            HStack(spacing: 8) {
                Label(preset.downloadSize, systemImage: "arrow.down.circle")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Label(preset.ramRequirement, systemImage: "memorychip")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(preset.quantization)
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
            }

            Text(preset.recommendation)
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack {
                Spacer()
                if isCurrent {
                    Label("Loaded in Memory", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                } else if isDownloaded {
                    HStack(spacing: 8) {
                        Label("Installed", systemImage: "checkmark")
                            .font(.caption)
                            .foregroundColor(.green)

                        Button("Load") {
                            let path = appState.modelManager.pathForModel(named: preset.defaultFilename)
                            appState.loadModel(path: path)
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.caption)
                    }
                } else {
                    Button {
                        appState.modelManager.downloadPreset(preset)
                    } label: {
                        Label("Download (\(preset.downloadSize))", systemImage: "arrow.down.circle")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .disabled(appState.modelManager.isDownloading)
                }
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private var customDownloadView: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup("Custom Model Download (URL)", isExpanded: $isCustomDownloadExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Download any GGUF quantized model via HTTPS. The filename will be dynamically resolved from the URL.")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    TextField("https://huggingface.co/.../model.gguf", text: $customURL)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.caption)

                    TextField("Target File Name (optional, e.g. custom.gguf)", text: $customFilename)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.caption)

                    Button {
                        let filename = customFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? nil
                            : customFilename.trimmingCharacters(in: .whitespacesAndNewlines)
                        appState.modelManager.downloadModel(from: customURL, targetFilename: filename)
                    } label: {
                        Label("Download Model", systemImage: "arrow.down.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.caption.bold())
                    .disabled(customURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.modelManager.isDownloading)
                }
                .padding(.top, 4)
            }
            .font(.caption.weight(.semibold))
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "play.circle")
                Text("Server Controls")
                    .font(.headline)
                Spacer()
            }

            Button {
                if appState.isServerRunning {
                    appState.stopServer()
                } else {
                    appState.startServer()
                }
            } label: {
                HStack {
                    Image(systemName: appState.isServerRunning ? "stop.fill" : "play.fill")
                    Text(appState.isServerRunning ? "Stop Server" : "Start Server")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(appState.isServerRunning ? .red : .green)
            .disabled(!appState.isModelLoaded)

            if !appState.isModelLoaded {
                Text("Load a model first to start the server")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - OpenAI Compatible API Card

    private var apiDocumentationCard: some View {
        let baseURL = appState.isServerRunning && !appState.serverURL.isEmpty
            ? "\(appState.serverURL)/v1"
            : "http://<IP>:8080/v1"

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "network")
                Text("OpenAI Compatible API")
                    .font(.headline)
                Spacer()
                if appState.isServerRunning {
                    Text("Ready")
                        .font(.caption2.bold())
                        .foregroundColor(.green)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Base URL")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                HStack {
                    Text(baseURL)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = baseURL
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                }
                .padding(8)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(6)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Available Endpoints")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    endpointRow(method: "GET", path: "/v1/models", description: "List loaded model")
                    endpointRow(method: "POST", path: "/v1/chat/completions", description: "Chat completions (streaming & non-streaming)")
                    endpointRow(method: "GET", path: "/", description: "Web status page")
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Integration Example")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("Language", selection: $selectedSnippetIndex) {
                        Text("cURL").tag(0)
                        Text("Python").tag(1)
                        Text("Node.js").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }

                let snippet = codeSnippet(for: selectedSnippetIndex, baseURL: baseURL)

                VStack(alignment: .trailing, spacing: 4) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(snippet)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(8)
                            .textSelection(.enabled)
                    }
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(6)

                    Button {
                        UIPasteboard.general.string = snippet
                        copiedSnippet = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copiedSnippet = false
                        }
                    } label: {
                        Label(copiedSnippet ? "Copied!" : "Copy Code", systemImage: copiedSnippet ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Low-Memory Device Guidance (iPhone SE2 3GB RAM)")
                        .font(.caption.bold())
                }
                Text("• Set max_tokens <= 512 for optimal responsiveness.\n• Default context window is 2048 tokens.\n• Enable 'Keep Screen On' to prevent background process termination.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func endpointRow(method: String, path: String, description: String) -> some View {
        HStack(spacing: 6) {
            Text(method)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundColor(method == "POST" ? .green : .blue)
                .frame(width: 42, alignment: .leading)
            Text(path)
                .font(.system(.caption2, design: .monospaced))
            Spacer()
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func codeSnippet(for index: Int, baseURL: String) -> String {
        switch index {
        case 0:
            return """
            curl \(baseURL)/chat/completions \\
              -H "Content-Type: application/json" \\
              -d '{
                "messages": [
                  {"role": "user", "content": "Hello!"}
                ],
                "stream": true
              }'
            """
        case 1:
            return """
            from openai import OpenAI

            client = OpenAI(
                base_url="\(baseURL)",
                api_key="not-needed"
            )

            response = client.chat.completions.create(
                model="default",
                messages=[{"role": "user", "content": "Hello!"}],
                stream=True
            )

            for chunk in response:
                print(chunk.choices[0].delta.content or "", end="", flush=True)
            """
        default:
            return """
            import OpenAI from "openai";

            const openai = new OpenAI({
              baseURL: "\(baseURL)",
              apiKey: "not-needed"
            });

            const stream = await openai.chat.completions.create({
              model: "default",
              messages: [{ role: "user", content: "Hello!" }],
              stream: true
            });

            for await (const chunk of stream) {
              process.stdout.write(chunk.choices[0]?.delta?.content || "");
            }
            """
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "gear")
                Text("Settings")
                    .font(.headline)
                Spacer()
            }

            Toggle(isOn: $appState.keepScreenOn) {
                HStack {
                    Image(systemName: "sun.max")
                    Text("Keep Screen On")
                }
            }

            HStack {
                Image(systemName: "speaker.wave.2")
                Text("Background Audio Keep-Alive")
                Spacer()
                Text("Enabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Log Section

    private var logSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "text.alignleft")
                Text("Logs")
                    .font(.headline)
                Spacer()
                if !appState.logMessages.isEmpty {
                    Button("Clear") {
                        appState.logMessages.removeAll()
                    }
                    .font(.caption)
                }
            }

            if appState.logMessages.isEmpty {
                Text("No log entries yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(appState.logMessages.suffix(50)) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text(entry.timeString)
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.secondary)
                            Text(entry.message)
                                .font(.caption2)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
