import AppKit
@preconcurrency import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Equatable {
    enum MediaKind: Equatable {
        case image
        case video
        case file
    }

    let id: UUID
    let url: URL
    let name: String
    let sizeText: String
    let mediaKind: MediaKind
    let addedAt: Date

    var hasVisualPreview: Bool {
        mediaKind == .image || mediaKind == .video
    }

    init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        sizeText: String,
        mediaKind: MediaKind,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.sizeText = sizeText
        self.mediaKind = mediaKind
        self.addedAt = addedAt
    }
}

@MainActor
final class ShelfService: ObservableObject {
    private enum Keys {
        static let savedPaths = "shelf.savedPaths"
    }

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "heif", "webp", "gif", "tiff", "tif", "bmp"
    ]

    private static let videoExtensions: Set<String> = [
        "mov", "mp4", "m4v", "webm", "avi", "mkv"
    ]

    @Published private(set) var items: [ShelfItem] = []
    @Published private(set) var thumbnails: [String: NSImage] = [:]
    @Published private(set) var videoDurations: [String: String] = [:]
    @Published private(set) var pendingDropCount: Int = 0
    @Published private(set) var highlightedItemID: UUID?
    @Published var isDropTargeted: Bool = false
    @Published var isAirDropDropTargeted: Bool = false
    @Published private(set) var airDropStatusText: String?

    var onFilesAdded: ((Int) -> Void)?

    private let defaults: UserDefaults
    private var iconCache: [String: NSImage] = [:]
    private var generatingPaths: Set<String> = []
    private var highlightResetTask: Task<Void, Never>?
    private var airDropStatusTask: Task<Void, Never>?
    private let promiseQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.leonardo.ilhadinamica.shelfPromises"
        q.maxConcurrentOperationCount = 2
        return q
    }()

    private let storageDirectory: URL

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.storageDirectory = appSupport.appendingPathComponent("IlhaDinamica/Shelf", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        loadSavedItems()
    }

    deinit {
        highlightResetTask?.cancel()
        airDropStatusTask?.cancel()
    }

    func previewImage(for item: ShelfItem) -> NSImage? {
        thumbnails[item.url.path]
    }

    func durationText(for item: ShelfItem) -> String? {
        videoDurations[item.url.path]
    }

    func fallbackIcon(for url: URL) -> NSImage {
        let path = url.path
        if let cached = iconCache[path] {
            return cached
        }
        let img = NSWorkspace.shared.icon(forFile: path)
        img.size = NSSize(width: 48, height: 48)
        if iconCache.count > 40 {
            iconCache.removeAll()
        }
        iconCache[path] = img
        return img
    }

    func ensurePreviewLoaded(for item: ShelfItem) {
        guard item.hasVisualPreview else { return }
        let path = item.url.path
        if thumbnails[path] != nil || generatingPaths.contains(path) {
            return
        }

        generatingPaths.insert(path)
        let url = item.url
        let kind = item.mediaKind

        Task.detached(priority: .userInitiated) { [weak self] in
            let cgImage: CGImage?
            let duration: String?

            switch kind {
            case .image:
                cgImage = Self.generateImageThumbnail(url: url, maxPixel: 280)
                duration = nil
            case .video:
                let videoResult = await Self.generateVideoPreview(url: url, maxPixel: 280)
                cgImage = videoResult.image
                duration = videoResult.duration
            case .file:
                cgImage = nil
                duration = nil
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.generatingPaths.remove(path)
                guard self.items.contains(where: { $0.url.path == path }) else { return }

                if let cgImage {
                    let size = NSSize(width: cgImage.width, height: cgImage.height)
                    self.thumbnails[path] = NSImage(cgImage: cgImage, size: size)
                }
                if let duration {
                    self.videoDurations[path] = duration
                }
            }
        }
    }

    private func extractFileURLs(from pb: NSPasteboard) -> [URL] {
        if let urls = pb.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !urls.isEmpty {
            return urls
        }

        if let filenames = pb.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String],
           !filenames.isEmpty {
            return filenames.map { URL(fileURLWithPath: $0) }
        }

        if let itemURLs = pb.pasteboardItems?.compactMap({ item -> URL? in
            guard let str = item.string(forType: .fileURL),
                  let url = URL(string: str) else {
                return nil
            }
            let standardized = url.standardizedFileURL
            return standardized.isFileURL ? standardized : nil
        }), !itemURLs.isEmpty {
            return itemURLs
        }

        return []
    }

    func handleDraggingInfo(_ sender: NSDraggingInfo) -> Bool {
        if sender.draggingSource != nil {
            return false
        }

        let pb = sender.draggingPasteboard

        // 1. Direct file URLs (Finder, Desktop, saved files)
        let urls = extractFileURLs(from: pb)
        if !urls.isEmpty {
            addFiles(urls, emitCallback: false)
            return true
        }

        // 2. File promises (macOS floating screenshot thumbnails Cmd+Shift+3/4, Photos, Mail, etc.)
        if let receivers = pb.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver],
           !receivers.isEmpty {
            try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            pendingDropCount += receivers.count
            for receiver in receivers {
                receiver.receivePromisedFiles(
                    atDestination: storageDirectory,
                    options: [:],
                    operationQueue: promiseQueue
                ) { [weak self] fileURL, error in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.pendingDropCount = max(0, self.pendingDropCount - 1)
                        if error == nil {
                            self.addFiles([fileURL], emitCallback: false)
                        }
                    }
                }
            }
            return true
        }

        // 3. Raw image data (browser drags, clipboard/image drags without file URL)
        if let pngData = extractPNGData(from: pb) {
            try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
            let filename = "Print_\(formatter.string(from: Date())).png"
            let destURL = storageDirectory.appendingPathComponent(filename)
            do {
                try pngData.write(to: destURL, options: .atomic)
                addFiles([destURL], emitCallback: false)
                return true
            } catch {
                return false
            }
        }

        return false
    }

    func addFiles(_ urls: [URL], emitCallback: Bool = true, highlight: Bool = true) {
        var addedCount = 0
        var newestItem: ShelfItem?

        for rawURL in urls {
            let url = rawURL.standardizedFileURL
            guard FileManager.default.fileExists(atPath: url.path) else { continue }

            if let existingIndex = items.firstIndex(where: { $0.url.standardizedFileURL.path == url.path }) {
                let existing = items.remove(at: existingIndex)
                items.insert(existing, at: 0)
                thumbnails.removeValue(forKey: existing.url.path)
                videoDurations.removeValue(forKey: existing.url.path)
                ensurePreviewLoaded(for: existing)
                newestItem = existing
                continue
            }

            let item = makeShelfItem(for: url)
            items.insert(item, at: 0)
            ensurePreviewLoaded(for: item)
            newestItem = item
            addedCount += 1
        }

        if items.count > 20 {
            let overflow = Array(items.dropFirst(20))
            items = Array(items.prefix(20))
            for old in overflow {
                thumbnails.removeValue(forKey: old.url.path)
                videoDurations.removeValue(forKey: old.url.path)
                iconCache.removeValue(forKey: old.url.path)
                deleteIfManagedCopy(old.url)
            }
        }

        if highlight, let newestItem {
            markHighlighted(newestItem.id)
        }

        if addedCount > 0 {
            savePaths()
            if emitCallback {
                onFilesAdded?(addedCount)
            }
        }
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        deleteIfManagedCopy(item.url)
        iconCache.removeValue(forKey: item.url.path)
        thumbnails.removeValue(forKey: item.url.path)
        videoDurations.removeValue(forKey: item.url.path)
        if highlightedItemID == item.id {
            highlightedItemID = nil
        }
        savePaths()
    }

    func clearAll() {
        let removed = items
        items.removeAll()
        iconCache.removeAll()
        thumbnails.removeAll()
        videoDurations.removeAll()
        highlightedItemID = nil
        for item in removed {
            deleteIfManagedCopy(item.url)
        }
        savePaths()
    }

    func copyToClipboard(_ item: ShelfItem) {
        let pb = NSPasteboard.general
        pb.clearContents()

        if item.mediaKind == .image {
            let pbItem = NSPasteboardItem()
            pbItem.setString(item.url.absoluteString, forType: .fileURL)
            if item.url.pathExtension.lowercased() == "png",
               let pngData = try? Data(contentsOf: item.url) {
                pbItem.setData(pngData, forType: .png)
            } else if let img = NSImage(contentsOf: item.url),
                      let tiff = img.tiffRepresentation {
                pbItem.setData(tiff, forType: .tiff)
            }
            pb.writeObjects([pbItem])
        } else {
            pb.writeObjects([item.url as NSURL])
        }
    }

    func revealInFinder(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func openFile(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.url)
    }

    // MARK: - AirDrop

    func sendViaAirDrop(_ urls: [URL]) {
        let validURLs = urls
            .map(\.standardizedFileURL)
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !validURLs.isEmpty else {
            setAirDropStatus("Nenhum arquivo válido")
            return
        }

        guard let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: validURLs) else {
            openAirDropWindow()
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: validURLs)
        setAirDropStatus(validURLs.count == 1 ? "AirDrop pronto" : "AirDrop (\(validURLs.count))")
    }

    func sendItemViaAirDrop(_ item: ShelfItem) {
        sendViaAirDrop([item.url])
    }

    func sendAllViaAirDrop() {
        sendViaAirDrop(items.map(\.url))
    }

    func openAirDropWindow() {
        let airDropURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app/Contents/Applications/AirDrop.app")
        NSWorkspace.shared.open(airDropURL)
        setAirDropStatus("AirDrop aberto")
    }

    func pickFilesForAirDrop() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.title = "Escolher arquivos para enviar via AirDrop"
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, !panel.urls.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.sendViaAirDrop(panel.urls)
            }
        }
    }

    func handleAirDropDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        let typeID = "public.file-url"
        for provider in providers where provider.hasItemConformingToTypeIdentifier(typeID) {
            provider.loadItem(forTypeIdentifier: typeID, options: nil) { [weak self] item, _ in
                let resolvedURL: URL?
                if let url = item as? URL {
                    resolvedURL = url
                } else if let data = item as? Data {
                    resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
                } else if let str = item as? String {
                    resolvedURL = URL(string: str)
                } else {
                    resolvedURL = nil
                }
                guard let resolvedURL else { return }
                Task { @MainActor [weak self] in
                    self?.sendViaAirDrop([resolvedURL])
                }
            }
        }
        return true
    }

    func handleExternalDropToAirDrop(_ sender: NSDraggingInfo) -> Bool {
        guard sender.draggingSource == nil else { return false }
        let urls = extractFileURLs(from: sender.draggingPasteboard)
        if !urls.isEmpty {
            addFiles(urls, emitCallback: false)
            sendViaAirDrop(urls)
            return true
        }
        let handled = handleDraggingInfo(sender)
        if handled, let newest = items.first {
            sendViaAirDrop([newest.url])
        }
        return handled
    }

    private func setAirDropStatus(_ text: String) {
        airDropStatusTask?.cancel()
        airDropStatusText = text
        airDropStatusTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled, let self else { return }
            if self.airDropStatusText == text {
                self.airDropStatusText = nil
            }
        }
    }

    private func markHighlighted(_ id: UUID) {
        highlightResetTask?.cancel()
        highlightedItemID = id
        highlightResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_500_000_000)
            guard !Task.isCancelled, let self else { return }
            if self.highlightedItemID == id {
                self.highlightedItemID = nil
            }
        }
    }

    private func deleteIfManagedCopy(_ url: URL) {
        let standardized = url.standardizedFileURL
        if standardized.deletingLastPathComponent().path == storageDirectory.standardizedFileURL.path {
            try? FileManager.default.removeItem(at: standardized)
        }
    }

    private func extractPNGData(from pb: NSPasteboard) -> Data? {
        if let directPNG = pb.data(forType: .png) {
            return directPNG
        }
        if let image = NSImage(pasteboard: pb),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff) {
            return rep.representation(using: .png, properties: [:])
        }
        return nil
    }

    nonisolated private static func generateImageThumbnail(url: URL, maxPixel: Int) -> CGImage? {
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel
            ]
            if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                return cgImage
            }
        }
        if let nsImage = NSImage(contentsOf: url) {
            var rect = NSRect(origin: .zero, size: nsImage.size)
            return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        return nil
    }

    nonisolated private static func generateVideoPreview(url: URL, maxPixel: Int) async -> (image: CGImage?, duration: String?) {
        let asset = AVURLAsset(url: url)

        var durationSeconds: Double = 0
        var formattedDuration: String?
        if let cmDuration = try? await asset.load(.duration) {
            let secs = CMTimeGetSeconds(cmDuration)
            if secs.isFinite && secs > 0 {
                durationSeconds = secs
                let rounded = max(1, Int(secs.rounded()))
                let mins = rounded / 60
                let rem = rounded % 60
                formattedDuration = String(format: "%d:%02d", mins, rem)
            }
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixel, height: maxPixel)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)

        let preferredSecond = durationSeconds > 0 ? min(0.3, durationSeconds * 0.15) : 0
        let candidateTimes: [CMTime] = preferredSecond > 0.02
            ? [CMTime(seconds: preferredSecond, preferredTimescale: 600), .zero]
            : [.zero]

        for time in candidateTimes {
            if let result = try? await generator.image(at: time) {
                return (result.image, formattedDuration)
            }
        }
        return (nil, formattedDuration)
    }

    private func loadSavedItems() {
        let paths = defaults.stringArray(forKey: Keys.savedPaths) ?? []
        var loaded: [ShelfItem] = []
        for path in paths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)
            loaded.append(makeShelfItem(for: url))
        }
        items = loaded
        for item in loaded {
            ensurePreviewLoaded(for: item)
        }
        if loaded.count != paths.count {
            savePaths()
        }
    }

    private func savePaths() {
        defaults.set(items.map { $0.url.path }, forKey: Keys.savedPaths)
    }

    private func makeShelfItem(for url: URL) -> ShelfItem {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .localizedNameKey])
        let name = values?.localizedName ?? url.lastPathComponent
        let isDir = values?.isDirectory ?? false
        let ext = url.pathExtension.lowercased()

        let mediaKind: ShelfItem.MediaKind
        if isDir {
            mediaKind = .file
        } else if Self.imageExtensions.contains(ext) {
            mediaKind = .image
        } else if Self.videoExtensions.contains(ext) {
            mediaKind = .video
        } else {
            mediaKind = .file
        }

        let sizeText: String
        if isDir {
            sizeText = "Pasta"
        } else if let size = values?.fileSize {
            sizeText = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        } else {
            sizeText = "Arquivo"
        }

        return ShelfItem(url: url, name: name, sizeText: sizeText, mediaKind: mediaKind)
    }
}
