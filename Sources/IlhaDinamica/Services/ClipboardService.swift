import AppKit
import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    var copiedAt: Date
    var isPinned: Bool
    let isURL: Bool

    init(
        id: UUID = UUID(),
        text: String,
        copiedAt: Date = Date(),
        isPinned: Bool = false,
        isURL: Bool = false
    ) {
        self.id = id
        self.text = text
        self.copiedAt = copiedAt
        self.isPinned = isPinned
        self.isURL = isURL
    }
}

@MainActor
final class ClipboardService: ObservableObject {
    private enum Keys {
        static let items = "clipboard.items"
    }

    @Published private(set) var items: [ClipboardItem] = []
    @Published var recentlyCopiedId: UUID?

    private let defaults: UserDefaults
    private var pollTimer: Timer?
    private var lastChangeCount: Int
    private var feedbackTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.lastChangeCount = NSPasteboard.general.changeCount
        loadItems()

        if let initial = NSPasteboard.general.string(forType: .string) {
            recordIfValid(initial)
        }

        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
        feedbackTask?.cancel()
    }

    func copy(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        lastChangeCount = pasteboard.changeCount

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].copiedAt = Date()
            sortAndTrim()
            saveItems()
        }

        recentlyCopiedId = item.id
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard !Task.isCancelled, let self else { return }
            if self.recentlyCopiedId == item.id {
                self.recentlyCopiedId = nil
            }
        }
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        sortAndTrim()
        saveItems()
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    func clearUnpinned() {
        items.removeAll { !$0.isPinned }
        saveItems()
    }

    private func startPolling() {
        let timer = Timer(timeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPasteboard()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        if let str = pasteboard.string(forType: .string) {
            recordIfValid(str)
        }
    }

    private func recordIfValid(_ rawText: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let existingIndex = items.firstIndex(where: { $0.text == rawText }) {
            items[existingIndex].copiedAt = Date()
        } else {
            let looksLikeURL = isLikelyURL(trimmed)
            let newItem = ClipboardItem(text: rawText, copiedAt: Date(), isPinned: false, isURL: looksLikeURL)
            items.insert(newItem, at: 0)
        }

        sortAndTrim()
        saveItems()
    }

    private func isLikelyURL(_ trimmed: String) -> Bool {
        guard !trimmed.contains("\n"), !trimmed.contains(" "),
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased() else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }

    private func sortAndTrim() {
        let pinned = items.filter(\.isPinned).sorted { $0.copiedAt > $1.copiedAt }
        let unpinned = items.filter { !$0.isPinned }.sorted { $0.copiedAt > $1.copiedAt }
        let combined = pinned + unpinned
        items = Array(combined.prefix(25))
    }

    private func loadItems() {
        guard let data = defaults.data(forKey: Keys.items),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            return
        }
        items = decoded
        sortAndTrim()
    }

    private func saveItems() {
        guard let encoded = try? JSONEncoder().encode(items) else { return }
        defaults.set(encoded, forKey: Keys.items)
    }
}
