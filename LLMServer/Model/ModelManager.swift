import Foundation
import Combine

struct ModelPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let parameterSize: String
    let quantization: String
    let downloadSize: String
    let ramRequirement: String
    let recommendation: String
    let isRecommendedForLowRAM: Bool
    let downloadURL: String
    let defaultFilename: String
}

struct LocalModelFile: Identifiable, Hashable {
    var id: String { fileName }
    let fileName: String
    let path: String
    let fileSize: Int64
    let formattedSize: String
    let modificationDate: Date?
}

final class ModelManager: NSObject, ObservableObject, @unchecked Sendable {

    static let presets: [ModelPreset] = [
        ModelPreset(
            id: "qwen-2.5-0.5b",
            name: "Qwen 2.5 0.5B Instruct",
            parameterSize: "0.5B",
            quantization: "Q4_K_M",
            downloadSize: "398 MB",
            ramRequirement: "~650 MB RAM",
            recommendation: "Recommended for iPhone SE2 (3GB RAM) — Fast & ultra-light",
            isRecommendedForLowRAM: true,
            downloadURL: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf",
            defaultFilename: "qwen2.5-0.5b-instruct-q4_k_m.gguf"
        ),
        ModelPreset(
            id: "llama-3.2-1b",
            name: "Llama 3.2 1B Instruct",
            parameterSize: "1B",
            quantization: "Q4_K_M",
            downloadSize: "800 MB",
            ramRequirement: "~1.2 GB RAM",
            recommendation: "Recommended for 3GB RAM — Great balance of speed & quality",
            isRecommendedForLowRAM: true,
            downloadURL: "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf",
            defaultFilename: "Llama-3.2-1B-Instruct-Q4_K_M.gguf"
        ),
        ModelPreset(
            id: "qwen-2.5-1.5b",
            name: "Qwen 2.5 1.5B Instruct",
            parameterSize: "1.5B",
            quantization: "Q4_K_M",
            downloadSize: "986 MB",
            ramRequirement: "~1.5 GB RAM",
            recommendation: "High capability — Near limit for 3GB RAM devices",
            isRecommendedForLowRAM: false,
            downloadURL: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf",
            defaultFilename: "qwen2.5-1.5b-instruct-q4_k_m.gguf"
        ),
        ModelPreset(
            id: "qwen-3.5-2b",
            name: "Qwen 3.5 2B",
            parameterSize: "2B",
            quantization: "Q4_K_M",
            downloadSize: "1.5 GB",
            ramRequirement: "~2.2 GB RAM",
            recommendation: "Heavy — Recommended for 4GB+ RAM devices",
            isRecommendedForLowRAM: false,
            downloadURL: "https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf",
            defaultFilename: "Qwen3.5-2B-Q4_K_M.gguf"
        )
    ]

    static let defaultModelURL = presets[0].downloadURL
    static let modelFileName = presets[0].defaultFilename

    enum DownloadState: Equatable {
        case idle
        case downloading(progress: Double, fileName: String, bytesWritten: Int64, totalBytes: Int64)
        case completed(fileName: String, path: String)
        case failed(String)
    }

    @Published var downloadState: DownloadState = .idle
    @Published var modelExists = false
    @Published var modelSizeFormatted = ""
    @Published var localModels: [LocalModelFile] = []
    @Published var lastDownloadedModelPath: String?

    private var downloadTask: URLSessionDownloadTask?
    private var session: URLSession?
    private let targetFilenameLock = NSLock()
    private var _targetFilename: String?

    var currentTargetFilename: String? {
        get {
            targetFilenameLock.lock()
            defer { targetFilenameLock.unlock() }
            return _targetFilename
        }
        set {
            targetFilenameLock.lock()
            defer { targetFilenameLock.unlock() }
            _targetFilename = newValue
        }
    }

    var isDownloading: Bool {
        if case .downloading = downloadState { return true }
        return false
    }

    var modelPath: String {
        if let lastPath = lastDownloadedModelPath, FileManager.default.fileExists(atPath: lastPath) {
            return lastPath
        }
        if let first = localModels.first {
            return first.path
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(Self.modelFileName).path
    }

    var onLog: ((String) -> Void)?

    override init() {
        super.init()
        checkModelExists()
    }

    func checkModelExists() {
        refreshLocalModels()
        modelExists = !localModels.isEmpty
        if let first = localModels.first {
            modelSizeFormatted = first.formattedSize
        } else {
            modelSizeFormatted = ""
        }
    }

    func refreshLocalModels() {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            localModels = []
            return
        }

        guard let urls = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else {
            localModels = []
            return
        }

        let ggufURLs = urls.filter { $0.pathExtension.lowercased() == "gguf" }

        localModels = ggufURLs.compactMap { url -> LocalModelFile? in
            let path = url.path
            let fileName = url.lastPathComponent
            let attrs = try? fm.attributesOfItem(atPath: path)
            let size = (attrs?[.size] as? Int64) ?? 0
            let date = attrs?[.modificationDate] as? Date
            let formatted = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            return LocalModelFile(
                fileName: fileName,
                path: path,
                fileSize: size,
                formattedSize: formatted,
                modificationDate: date
            )
        }.sorted { $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending }
    }

    func findGGUFFiles() -> [String] {
        refreshLocalModels()
        return localModels.map { $0.fileName }
    }

    func pathForModel(named name: String) -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(name).path
    }

    func isModelDownloaded(preset: ModelPreset) -> Bool {
        return localModels.contains { $0.fileName == preset.defaultFilename }
    }

    static func sanitizeFilename(_ name: String) -> String {
        var cleaned = name
        if let decoded = cleaned.removingPercentEncoding {
            cleaned = decoded
        }
        if let queryIdx = cleaned.firstIndex(of: "?") {
            cleaned = String(cleaned[..<queryIdx])
        }
        if let hashIdx = cleaned.firstIndex(of: "#") {
            cleaned = String(cleaned[..<hashIdx])
        }
        let illegalChars = CharacterSet(charactersIn: "/\\?%*|\":<> ")
        var sanitized = cleaned.components(separatedBy: illegalChars).filter { !$0.isEmpty }.joined(separator: "_")
        if sanitized.isEmpty {
            sanitized = "model"
        }
        if !sanitized.lowercased().hasSuffix(".gguf") {
            sanitized += ".gguf"
        }
        return sanitized
    }

    static func resolveFilename(from url: URL, customName: String? = nil) -> String {
        if let customName = customName?.trimmingCharacters(in: .whitespacesAndNewlines), !customName.isEmpty {
            return sanitizeFilename(customName)
        }

        let lastPathComponent = url.lastPathComponent
        if !lastPathComponent.isEmpty && lastPathComponent.lowercased().hasSuffix(".gguf") {
            return sanitizeFilename(lastPathComponent)
        }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                if let val = item.value, val.lowercased().hasSuffix(".gguf") {
                    return sanitizeFilename(val)
                }
            }
        }

        if !lastPathComponent.isEmpty && lastPathComponent != "/" {
            return sanitizeFilename(lastPathComponent)
        }

        return "model.gguf"
    }

    func downloadPreset(_ preset: ModelPreset) {
        downloadModel(from: preset.downloadURL, targetFilename: preset.defaultFilename)
    }

    func retryLastDownload() {
        if let last = lastDownloadTarget {
            downloadModel(from: last.url, targetFilename: last.filename)
        } else {
            downloadModel(from: Self.defaultModelURL, targetFilename: Self.modelFileName)
        }
    }

    func downloadModel(from urlString: String? = nil, targetFilename: String? = nil) {
        let trimmed = urlString?.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlStr = (trimmed?.isEmpty == false) ? trimmed! : Self.defaultModelURL

        guard let url = URL(string: urlStr),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            downloadState = .failed("Invalid download URL: \(urlStr)")
            onLog?("Download failed: invalid URL \(urlStr)")
            return
        }

        let resolvedFilename = Self.resolveFilename(from: url, customName: targetFilename)
        currentTargetFilename = resolvedFilename
        lastDownloadTarget = (url: urlStr, filename: targetFilename)
        lastLogged100MBSlot = 0

        onLog?("Starting download: \(resolvedFilename) from \(urlStr)")
        downloadState = .downloading(progress: 0, fileName: resolvedFilename, bytesWritten: 0, totalBytes: 0)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 86400
        config.allowsCellularAccess = true

        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        downloadTask = session?.downloadTask(with: url)
        downloadTask?.resume()
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        session?.invalidateAndCancel()
        session = nil
        currentTargetFilename = nil
        downloadState = .idle
        onLog?("Download cancelled")
    }

    func resetDownloadState() {
        downloadState = .idle
    }

    func deleteModel(named name: String) throws {
        let path = pathForModel(named: name)
        let fm = FileManager.default
        if fm.fileExists(atPath: path) {
            try fm.removeItem(atPath: path)
            onLog?("Deleted model: \(name)")
        }
        checkModelExists()
    }

    func deleteModel() {
        if let first = localModels.first {
            try? deleteModel(named: first.fileName)
        } else {
            try? FileManager.default.removeItem(atPath: modelPath)
            checkModelExists()
        }
    }
}

extension ModelManager: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        var resolvedFilename = currentTargetFilename ?? ""
        if resolvedFilename.isEmpty {
            if let suggested = downloadTask.response?.suggestedFilename, !suggested.isEmpty, suggested != "resolve" {
                resolvedFilename = Self.sanitizeFilename(suggested)
            } else {
                resolvedFilename = "model.gguf"
            }
        }

        let destPath = pathForModel(named: resolvedFilename)
        let destURL = URL(fileURLWithPath: destPath)

        do {
            let fm = FileManager.default
            if fm.fileExists(atPath: destPath) {
                try fm.removeItem(atPath: destPath)
            }
            try fm.moveItem(at: location, to: destURL)

            DispatchQueue.main.async {
                self.lastDownloadedModelPath = destPath
                self.currentTargetFilename = nil
                self.onLog?("Download completed: \(resolvedFilename)")
                self.downloadState = .completed(fileName: resolvedFilename, path: destPath)
                self.checkModelExists()
            }
        } catch {
            DispatchQueue.main.async {
                self.currentTargetFilename = nil
                self.downloadState = .failed("Failed to save: \(error.localizedDescription)")
                self.onLog?("Save error: \(error.localizedDescription)")
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress: Double = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0
        let targetName = currentTargetFilename ?? "Model"
        let totalMB = Double(totalBytesWritten) / 1_000_000.0

        DispatchQueue.main.async {
            self.downloadState = .downloading(
                progress: progress,
                fileName: targetName,
                bytesWritten: totalBytesWritten,
                totalBytes: totalBytesExpectedToWrite
            )
            let slot = Int(Double(totalBytesWritten) / 104_857_600.0)
            if slot > self.lastLogged100MBSlot {
                self.lastLogged100MBSlot = slot
                self.onLog?("Downloaded \(slot * 100) MB for \(targetName)")
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                if (error as NSError).code != NSURLErrorCancelled {
                    self.onLog?("Download error: \(error.localizedDescription)")
                    self.downloadState = .failed(error.localizedDescription)
                }
                self.currentTargetFilename = nil
            }
        }
    }
}
