import AppKit
import CoreImage
import Foundation
import SwiftUI

enum MusicPlayerKind: String, Equatable {
    case none
    case spotify
    case appleMusic

    var displayName: String {
        switch self {
        case .none:
            return "Nenhum player"
        case .spotify:
            return "Spotify"
        case .appleMusic:
            return "Apple Music"
        }
    }

    var bundleIdentifier: String? {
        switch self {
        case .none:
            return nil
        case .spotify:
            return "com.spotify.client"
        case .appleMusic:
            return "com.apple.Music"
        }
    }

    var defaultAccentColor: Color {
        switch self {
        case .none:
            return Color.white
        case .spotify:
            return Color(red: 0.11, green: 0.84, blue: 0.38)
        case .appleMusic:
            return Color(red: 0.98, green: 0.24, blue: 0.42)
        }
    }
}

@MainActor
final class MusicService: ObservableObject {
    @Published private(set) var player: MusicPlayerKind = .none
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var title: String = ""
    @Published private(set) var artist: String = ""
    @Published private(set) var album: String = ""
    @Published private(set) var duration: Double = 0
    @Published private(set) var elapsedTime: Double = 0
    @Published private(set) var artwork: NSImage?
    @Published private(set) var accentColor: Color = Color(red: 0.11, green: 0.84, blue: 0.38)
    @Published private(set) var hasTrack: Bool = false
    @Published private(set) var automationDenied: Bool = false
    @Published var isScrubbing: Bool = false
    @Published var scrubSeconds: Double = 0
    @Published var isHoveringTrack: Bool = false

    var onTrackChanged: ((String, String, Color) -> Void)?

    private var distributedObservers: [NSObjectProtocol] = []
    private var interpolationTimer: Timer?
    private var pollCounter: Int = 0
    private var isFetching = false
    private var hasCompletedInitialPoll = false
    private var lastTrackSignature: String = ""
    private var lastArtworkKey: String = ""
    private var artworkCache: [String: (NSImage, Color)] = [:]
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    init() {
        setupObservers()
        startTimers()
        Task { await pollNow() }
    }

    deinit {
        interpolationTimer?.invalidate()
        let center = DistributedNotificationCenter.default()
        for observer in distributedObservers {
            center.removeObserver(observer)
        }
    }

    private func setupObservers() {
        let center = DistributedNotificationCenter.default()
        let names = [
            Notification.Name("com.spotify.client.PlaybackStateChanged"),
            Notification.Name("com.apple.Music.playerInfo")
        ]

        for name in names {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    await self?.pollNow()
                }
            }
            distributedObservers.append(observer)
        }
    }

    private func startTimers() {
        interpolationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        if isPlaying && duration > 0 && !isScrubbing {
            elapsedTime = min(duration, elapsedTime + 0.5)
        }

        pollCounter += 1
        // Resync with player every 3 seconds (or every 5 seconds if idle)
        let intervalTicks = isPlaying ? 6 : 10
        if pollCounter >= intervalTicks {
            pollCounter = 0
            Task { await pollNow() }
        }
    }

    func togglePlayPause() {
        let target = activeControllablePlayer()
        guard target != .none else { return }
        isPlaying.toggle()
        Task {
            await runPlayerCommand(target, command: "playpause")
            try? await Task.sleep(nanoseconds: 120_000_000)
            await pollNow()
        }
    }

    func nextTrack() {
        let target = activeControllablePlayer()
        guard target != .none else { return }
        Task {
            await runPlayerCommand(target, command: "next track")
            try? await Task.sleep(nanoseconds: 180_000_000)
            await pollNow()
        }
    }

    func previousTrack() {
        let target = activeControllablePlayer()
        guard target != .none else { return }
        Task {
            await runPlayerCommand(target, command: "previous track")
            try? await Task.sleep(nanoseconds: 180_000_000)
            await pollNow()
        }
    }

    func seek(to seconds: Double) {
        let target = activeControllablePlayer()
        guard target != .none, duration > 0 else { return }
        let clamped = max(0, min(duration, seconds))
        elapsedTime = clamped
        Task {
            let formatted = String(format: "%.2f", clamped)
            let script: String
            switch target {
            case .spotify:
                script = "tell application \"Spotify\" to set player position to \(formatted)"
            case .appleMusic:
                script = "tell application \"Music\" to set player position to \(formatted)"
            case .none:
                return
            }
            _ = await Self.executeAppleScript(script)
            try? await Task.sleep(nanoseconds: 150_000_000)
            await pollNow()
        }
    }

    func openPlayer(_ kind: MusicPlayerKind) {
        guard let bundleId = kind.bundleIdentifier else { return }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: config)
        }
    }

    func openActivePlayer() {
        if player != .none {
            openPlayer(player)
        } else if isAppInstalled("com.spotify.client") {
            openPlayer(.spotify)
        } else if isAppInstalled("com.apple.Music") {
            openPlayer(.appleMusic)
        }
    }

    func isAppInstalled(_ bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    private func activeControllablePlayer() -> MusicPlayerKind {
        if player != .none { return player }
        if isRunning("com.spotify.client") { return .spotify }
        if isRunning("com.apple.Music") { return .appleMusic }
        return .none
    }

    private func isRunning(_ bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    func pollNow() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        let spotifyRunning = isRunning("com.spotify.client")
        let appleMusicRunning = isRunning("com.apple.Music")

        if !spotifyRunning && !appleMusicRunning {
            clearTrack(denied: false)
            hasCompletedInitialPoll = true
            return
        }

        var spotifyState: TrackSnapshot?
        var appleMusicState: TrackSnapshot?
        var sawDenied = false

        if spotifyRunning {
            let result = await fetchSpotifySnapshot()
            spotifyState = result.snapshot
            if result.denied { sawDenied = true }
        }

        if appleMusicRunning {
            let result = await fetchAppleMusicSnapshot()
            appleMusicState = result.snapshot
            if result.denied { sawDenied = true }
        }

        let chosen: TrackSnapshot?
        if let sp = spotifyState, sp.isPlaying {
            chosen = sp
        } else if let am = appleMusicState, am.isPlaying {
            chosen = am
        } else if player == .appleMusic, let am = appleMusicState {
            chosen = am
        } else if let sp = spotifyState {
            chosen = sp
        } else {
            chosen = appleMusicState
        }

        guard let snapshot = chosen else {
            clearTrack(denied: sawDenied)
            hasCompletedInitialPoll = true
            return
        }

        automationDenied = false

        let previousSignature = lastTrackSignature
        let newSignature = "\(snapshot.player.rawValue)|\(snapshot.title)|\(snapshot.artist)"
        let trackDidChange = !newSignature.isEmpty && newSignature != previousSignature

        player = snapshot.player
        isPlaying = snapshot.isPlaying
        title = snapshot.title
        artist = snapshot.artist
        album = snapshot.album
        duration = snapshot.duration
        elapsedTime = min(max(0, snapshot.elapsed), max(snapshot.duration, 0))
        hasTrack = !snapshot.title.isEmpty
        lastTrackSignature = newSignature

        await resolveArtwork(for: snapshot)

        if hasCompletedInitialPoll && trackDidChange && !snapshot.title.isEmpty {
            onTrackChanged?(snapshot.title, snapshot.artist, accentColor)
        }

        hasCompletedInitialPoll = true
    }

    private func clearTrack(denied: Bool) {
        player = .none
        isPlaying = false
        title = ""
        artist = ""
        album = ""
        duration = 0
        elapsedTime = 0
        artwork = nil
        accentColor = MusicPlayerKind.spotify.defaultAccentColor
        hasTrack = false
        automationDenied = denied
        lastTrackSignature = ""
        lastArtworkKey = ""
    }

    private struct TrackSnapshot {
        let player: MusicPlayerKind
        let isPlaying: Bool
        let title: String
        let artist: String
        let album: String
        let duration: Double
        let elapsed: Double
        let artworkURL: String?
        let artworkFilePath: String?
    }

    private struct ScriptResult {
        let output: String
        let errorOutput: String
        let exitCode: Int32

        var isPermissionDenied: Bool {
            errorOutput.contains("-1743")
                || errorOutput.localizedCaseInsensitiveContains("Not authorized to send Apple events")
        }
    }

    private func fetchSpotifySnapshot() async -> (snapshot: TrackSnapshot?, denied: Bool) {
        let script = """
        tell application "Spotify"
            set pState to player state as string
            if pState is "stopped" then
                return "STOPPED"
            end if
            try
                set tName to name of current track
                set tArtist to artist of current track
                set tAlbum to album of current track
                set tDur to (duration of current track) as string
                set tPos to (player position) as string
                set tArt to artwork url of current track
                return pState & "||~||" & tName & "||~||" & tArtist & "||~||" & tAlbum & "||~||" & tDur & "||~||" & tPos & "||~||" & tArt
            on error
                return "STOPPED"
            end try
        end tell
        """

        let res = await Self.executeAppleScript(script)
        if res.isPermissionDenied { return (nil, true) }
        guard res.exitCode == 0 else { return (nil, false) }

        let trimmed = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "STOPPED" { return (nil, false) }

        let parts = trimmed.components(separatedBy: "||~||")
        guard parts.count >= 6 else { return (nil, false) }

        let stateStr = parts[0].lowercased()
        let durMs = parseLocalizedDouble(parts[4])
        let posSec = parseLocalizedDouble(parts[5])
        let artURL = parts.count >= 7 ? parts[6] : nil

        let snapshot = TrackSnapshot(
            player: .spotify,
            isPlaying: stateStr == "playing",
            title: parts[1],
            artist: parts[2],
            album: parts[3],
            duration: durMs / 1000.0,
            elapsed: posSec,
            artworkURL: artURL,
            artworkFilePath: nil
        )
        return (snapshot, false)
    }

    private func fetchAppleMusicSnapshot() async -> (snapshot: TrackSnapshot?, denied: Bool) {
        let script = """
        tell application "Music"
            set pState to player state as string
            if pState is "stopped" then
                return "STOPPED"
            end if
            try
                set tName to name of current track
                set tArtist to artist of current track
                set tAlbum to album of current track
                set tDur to (duration of current track) as string
                set tPos to (player position) as string
                return pState & "||~||" & tName & "||~||" & tArtist & "||~||" & tAlbum & "||~||" & tDur & "||~||" & tPos
            on error
                return "STOPPED"
            end try
        end tell
        """

        let res = await Self.executeAppleScript(script)
        if res.isPermissionDenied { return (nil, true) }
        guard res.exitCode == 0 else { return (nil, false) }

        let trimmed = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "STOPPED" { return (nil, false) }

        let parts = trimmed.components(separatedBy: "||~||")
        guard parts.count >= 6 else { return (nil, false) }

        let stateStr = parts[0].lowercased()
        let title = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let durSec = parseLocalizedDouble(parts[4])
        let posSec = parseLocalizedDouble(parts[5])

        let artKey = "am|\(artist)|\(album)|\(title)"
        var artFilePath: String?
        if artworkCache[artKey] == nil {
            artFilePath = await exportAppleMusicArtwork(cacheKey: artKey)
        }

        let snapshot = TrackSnapshot(
            player: .appleMusic,
            isPlaying: stateStr == "playing",
            title: title,
            artist: artist,
            album: album,
            duration: durSec,
            elapsed: posSec,
            artworkURL: nil,
            artworkFilePath: artFilePath
        )
        return (snapshot, false)
    }

    private func exportAppleMusicArtwork(cacheKey: String) async -> String? {
        let safeHash = String(abs(cacheKey.hashValue))
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("ilha_am_art_\(safeHash).dat")
            .path

        let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Music"
            try
                if (count of artworks of current track) > 0 then
                    set artData to raw data of artwork 1 of current track
                    set fRef to open for access (POSIX file "\(escapedPath)") with write permission
                    set eof of fRef to 0
                    write artData to fRef
                    close access fRef
                    return "OK"
                end if
            on error
                try
                    close access (POSIX file "\(escapedPath)")
                end try
            end try
            return "NONE"
        end tell
        """

        let res = await Self.executeAppleScript(script)
        if res.output.trimmingCharacters(in: .whitespacesAndNewlines) == "OK" {
            return path
        }
        return nil
    }

    private func resolveArtwork(for snapshot: TrackSnapshot) async {
        let key: String
        if let urlStr = snapshot.artworkURL, !urlStr.isEmpty {
            key = "sp|\(urlStr)"
        } else if snapshot.player == .appleMusic {
            key = "am|\(snapshot.artist)|\(snapshot.album)|\(snapshot.title)"
        } else {
            key = ""
        }

        guard !key.isEmpty else {
            artwork = nil
            accentColor = snapshot.player.defaultAccentColor
            lastArtworkKey = ""
            return
        }

        if key == lastArtworkKey && artwork != nil {
            return
        }

        if let cached = artworkCache[key] {
            artwork = cached.0
            accentColor = cached.1
            lastArtworkKey = key
            return
        }

        var loadedImage: NSImage?
        if let urlStr = snapshot.artworkURL, let url = URL(string: urlStr) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                loadedImage = NSImage(data: data)
            } catch {
                loadedImage = nil
            }
        } else if let path = snapshot.artworkFilePath {
            loadedImage = NSImage(contentsOfFile: path)
            try? FileManager.default.removeItem(atPath: path)
        }

        if let loadedImage {
            let extracted = extractAccentColor(from: loadedImage) ?? snapshot.player.defaultAccentColor
            if artworkCache.count > 24 {
                artworkCache.removeAll()
            }
            artworkCache[key] = (loadedImage, extracted)
            artwork = loadedImage
            accentColor = extracted
            lastArtworkKey = key
        } else {
            artwork = nil
            accentColor = snapshot.player.defaultAccentColor
            lastArtworkKey = key
        }
    }

    private func extractAccentColor(from image: NSImage) -> Color? {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else {
            return nil
        }

        let extent = ciImage.extent
        guard extent.width > 0, extent.height > 0,
              let filter = CIFilter(name: "CIAreaAverage") else {
            return nil
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let r = CGFloat(bitmap[0]) / 255.0
        let g = CGFloat(bitmap[1]) / 255.0
        let b = CGFloat(bitmap[2]) / 255.0

        let nsColor = NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
        var hue: CGFloat = 0
        var sat: CGFloat = 0
        var bri: CGFloat = 0
        var alpha: CGFloat = 0
        nsColor.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)

        let boostedSat = sat < 0.12 ? sat : max(sat, 0.58)
        let boostedBri = max(bri, 0.78)
        return Color(hue: Double(hue), saturation: Double(boostedSat), brightness: Double(boostedBri))
    }

    private func runPlayerCommand(_ kind: MusicPlayerKind, command: String) async {
        let appName: String
        switch kind {
        case .spotify:
            appName = "Spotify"
        case .appleMusic:
            appName = "Music"
        case .none:
            return
        }
        _ = await Self.executeAppleScript("tell application \"\(appName)\" to \(command)")
    }

    private func parseLocalizedDouble(_ raw: String) -> Double {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }

    private static func executeAppleScript(_ source: String) async -> ScriptResult {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            do {
                try process.run()
            } catch {
                return ScriptResult(output: "", errorOutput: error.localizedDescription, exitCode: -1)
            }

            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let output = String(data: outData, encoding: .utf8) ?? ""
            let errOutput = String(data: errData, encoding: .utf8) ?? ""
            return ScriptResult(output: output, errorOutput: errOutput, exitCode: process.terminationStatus)
        }.value
    }
}
