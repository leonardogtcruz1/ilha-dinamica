import AppKit
import CoreAudio
import CoreImage
import Foundation
import IOKit.hidsystem
import SwiftUI

enum MusicPlayerKind: String, Equatable {
    case none
    case spotify
    case appleMusic
    case youtube
    case youtubeMusic
    case netflix
    case twitch
    case primeVideo
    case disneyPlus
    case maxVideo
    case globoplay
    case crunchyroll
    case soundcloud
    case deezer
    case tidal
    case vimeo
    case appleTV
    case podcasts
    case vlc
    case iina
    case quickTime
    case browser
    case otherApp

    var displayName: String {
        switch self {
        case .none:
            return "Nenhum player"
        case .spotify:
            return "Spotify"
        case .appleMusic:
            return "Apple Music"
        case .youtube:
            return "YouTube"
        case .youtubeMusic:
            return "YouTube Music"
        case .netflix:
            return "Netflix"
        case .twitch:
            return "Twitch"
        case .primeVideo:
            return "Prime Video"
        case .disneyPlus:
            return "Disney+"
        case .maxVideo:
            return "Max"
        case .globoplay:
            return "Globoplay"
        case .crunchyroll:
            return "Crunchyroll"
        case .soundcloud:
            return "SoundCloud"
        case .deezer:
            return "Deezer"
        case .tidal:
            return "Tidal"
        case .vimeo:
            return "Vimeo"
        case .appleTV:
            return "Apple TV"
        case .podcasts:
            return "Podcasts"
        case .vlc:
            return "VLC"
        case .iina:
            return "IINA"
        case .quickTime:
            return "QuickTime"
        case .browser:
            return "Navegador"
        case .otherApp:
            return "Mídia"
        }
    }

    var bundleIdentifier: String? {
        switch self {
        case .spotify:
            return "com.spotify.client"
        case .appleMusic:
            return "com.apple.Music"
        case .appleTV:
            return "com.apple.TV"
        case .podcasts:
            return "com.apple.podcasts"
        case .vlc:
            return "org.videolan.vlc"
        case .iina:
            return "com.colliderli.iina"
        case .quickTime:
            return "com.apple.QuickTimePlayerX"
        default:
            return nil
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
        case .youtube:
            return Color(red: 1.00, green: 0.18, blue: 0.22)
        case .youtubeMusic:
            return Color(red: 1.00, green: 0.22, blue: 0.26)
        case .netflix:
            return Color(red: 0.90, green: 0.08, blue: 0.14)
        case .twitch:
            return Color(red: 0.58, green: 0.28, blue: 0.98)
        case .primeVideo:
            return Color(red: 0.05, green: 0.66, blue: 0.92)
        case .disneyPlus:
            return Color(red: 0.12, green: 0.48, blue: 0.96)
        case .maxVideo:
            return Color(red: 0.24, green: 0.44, blue: 0.98)
        case .globoplay:
            return Color(red: 0.98, green: 0.24, blue: 0.16)
        case .crunchyroll:
            return Color(red: 0.96, green: 0.46, blue: 0.10)
        case .soundcloud:
            return Color(red: 1.00, green: 0.42, blue: 0.08)
        case .deezer:
            return Color(red: 0.64, green: 0.22, blue: 0.98)
        case .tidal:
            return Color(red: 0.26, green: 0.80, blue: 0.95)
        case .vimeo:
            return Color(red: 0.12, green: 0.72, blue: 0.96)
        case .appleTV:
            return Color(red: 0.42, green: 0.72, blue: 0.98)
        case .podcasts:
            return Color(red: 0.64, green: 0.26, blue: 0.96)
        case .vlc:
            return Color(red: 0.98, green: 0.48, blue: 0.10)
        case .iina:
            return Color(red: 0.20, green: 0.72, blue: 0.96)
        case .quickTime:
            return Color(red: 0.24, green: 0.64, blue: 0.98)
        case .browser:
            return Color(red: 0.36, green: 0.66, blue: 0.98)
        case .otherApp:
            return Color(red: 0.45, green: 0.62, blue: 0.98)
        }
    }

    var fallbackSymbolName: String {
        switch self {
        case .youtube:
            return "play.rectangle.fill"
        case .youtubeMusic:
            return "play.circle.fill"
        case .netflix, .primeVideo, .disneyPlus, .maxVideo, .globoplay, .crunchyroll, .vimeo, .appleTV, .vlc, .iina, .quickTime:
            return "film.fill"
        case .twitch:
            return "video.fill"
        case .podcasts:
            return "mic.fill"
        case .browser:
            return "globe"
        case .otherApp:
            return "speaker.wave.2.fill"
        case .spotify, .appleMusic, .soundcloud, .deezer, .tidal, .none:
            return "music.note"
        }
    }
}

private enum BrowserEngine {
    case chromium
    case safari
}

private struct SupportedBrowser {
    let bundleID: String
    let appName: String
    let engine: BrowserEngine
    let audioBundlePrefixes: [String]
}

private struct ActiveBrowserTarget {
    let bundleID: String
    let appName: String
    let engine: BrowserEngine
    let windowIndex: Int
    let tabIndex: Int
    let urlString: String
    let kind: MusicPlayerKind
    let sourceName: String
    let detectedAt: Date
}

private struct BrowserTabEntry {
    let windowIndex: Int
    let tabIndex: Int
    let isActiveTab: Bool
    let urlString: String
    let title: String
}

private struct BrowserDOMProbe {
    let isPaused: Bool
    let duration: Double
    let elapsed: Double
    let title: String
    let artist: String
    let album: String
    let artworkURL: String
}

private struct OEmbedMetadata {
    let title: String?
    let authorName: String?
    let thumbnailURL: String?
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
    @Published private(set) var sourceDisplayName: String = ""
    @Published private(set) var sourceBundleIdentifier: String? = nil
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

    private var lastActiveAudioBundles: Set<String> = []
    private var lastBrowserTarget: ActiveBrowserTarget?
    private var lastBrowserMediaTimestamp: Date = .distantPast
    private var browserAutomationDenied: Set<String> = []
    private var nativeAutomationDenied: Set<String> = []
    private var jsDeniedBrowsers: [String: Date] = [:]
    private var oEmbedCache: [String: OEmbedMetadata] = [:]
    private var oEmbedInFlight: Set<String> = []
    private var lastOtherAppBundleID: String?
    private var lastOtherAppTimestamp: Date = .distantPast
    private var lastNativeVideoKind: MusicPlayerKind?
    private var lastNativeVideoTimestamp: Date = .distantPast

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

        let currentAudioBundles = Self.activeAudioOutputBundleIDs()
        if currentAudioBundles != lastActiveAudioBundles {
            lastActiveAudioBundles = currentAudioBundles
            pollCounter = 0
            Task { await pollNow() }
            return
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
        if let browserTarget = lastBrowserTarget,
           hasTrack,
           sourceBundleIdentifier == browserTarget.bundleID {
            isPlaying.toggle()
            Task {
                let handled = await controlBrowserMedia(browserTarget, action: .playPause)
                if !handled {
                    Self.postSystemMediaKey(Int32(NX_KEYTYPE_PLAY))
                }
                try? await Task.sleep(nanoseconds: 140_000_000)
                await pollNow()
            }
            return
        }

        let target = activeControllablePlayer()
        guard target != .none else { return }
        isPlaying.toggle()
        Task {
            switch target {
            case .spotify, .appleMusic, .appleTV, .vlc, .quickTime:
                await runPlayerCommand(target, command: "playpause")
            case .podcasts, .iina, .otherApp, .browser,
                 .youtube, .youtubeMusic, .netflix, .twitch, .primeVideo,
                 .disneyPlus, .maxVideo, .globoplay, .crunchyroll,
                 .soundcloud, .deezer, .tidal, .vimeo, .none:
                Self.postSystemMediaKey(Int32(NX_KEYTYPE_PLAY))
            }
            try? await Task.sleep(nanoseconds: 140_000_000)
            await pollNow()
        }
    }

    func nextTrack() {
        if let browserTarget = lastBrowserTarget,
           hasTrack,
           sourceBundleIdentifier == browserTarget.bundleID {
            Task {
                let handled = await controlBrowserMedia(browserTarget, action: .next)
                if !handled {
                    Self.postSystemMediaKey(Int32(NX_KEYTYPE_NEXT))
                }
                try? await Task.sleep(nanoseconds: 220_000_000)
                await pollNow()
            }
            return
        }

        let target = activeControllablePlayer()
        guard target != .none else { return }
        Task {
            switch target {
            case .spotify, .appleMusic, .appleTV, .vlc, .quickTime:
                await runPlayerCommand(target, command: "next track")
            case .podcasts, .iina, .otherApp, .browser,
                 .youtube, .youtubeMusic, .netflix, .twitch, .primeVideo,
                 .disneyPlus, .maxVideo, .globoplay, .crunchyroll,
                 .soundcloud, .deezer, .tidal, .vimeo, .none:
                Self.postSystemMediaKey(Int32(NX_KEYTYPE_NEXT))
            }
            try? await Task.sleep(nanoseconds: 220_000_000)
            await pollNow()
        }
    }

    func previousTrack() {
        if let browserTarget = lastBrowserTarget,
           hasTrack,
           sourceBundleIdentifier == browserTarget.bundleID {
            Task {
                let handled = await controlBrowserMedia(browserTarget, action: .previous)
                if !handled {
                    Self.postSystemMediaKey(Int32(NX_KEYTYPE_PREVIOUS))
                }
                try? await Task.sleep(nanoseconds: 220_000_000)
                await pollNow()
            }
            return
        }

        let target = activeControllablePlayer()
        guard target != .none else { return }
        Task {
            switch target {
            case .spotify, .appleMusic, .appleTV, .vlc, .quickTime:
                await runPlayerCommand(target, command: "previous track")
            case .podcasts, .iina, .otherApp, .browser,
                 .youtube, .youtubeMusic, .netflix, .twitch, .primeVideo,
                 .disneyPlus, .maxVideo, .globoplay, .crunchyroll,
                 .soundcloud, .deezer, .tidal, .vimeo, .none:
                Self.postSystemMediaKey(Int32(NX_KEYTYPE_PREVIOUS))
            }
            try? await Task.sleep(nanoseconds: 220_000_000)
            await pollNow()
        }
    }

    func seek(to seconds: Double) {
        guard duration > 0 else { return }
        let clamped = max(0, min(duration, seconds))
        elapsedTime = clamped

        if let browserTarget = lastBrowserTarget,
           hasTrack,
           sourceBundleIdentifier == browserTarget.bundleID {
            Task {
                _ = await seekBrowserMedia(browserTarget, to: clamped)
                try? await Task.sleep(nanoseconds: 150_000_000)
                await pollNow()
            }
            return
        }

        let target = activeControllablePlayer()
        guard target != .none else { return }
        Task {
            let formatted = String(format: "%.2f", clamped)
            let script: String
            switch target {
            case .spotify:
                script = "tell application \"Spotify\" to set player position to \(formatted)"
            case .appleMusic:
                script = "tell application \"Music\" to set player position to \(formatted)"
            case .appleTV:
                script = "tell application \"TV\" to set player position to \(formatted)"
            case .vlc:
                script = "tell application \"VLC\" to set current time to \(Int(clamped))"
            case .quickTime:
                script = "tell application \"QuickTime Player\" to if (count of documents) > 0 then set current time of document 1 to \(formatted)"
            default:
                return
            }
            _ = await Self.executeAppleScript(script)
            try? await Task.sleep(nanoseconds: 150_000_000)
            await pollNow()
        }
    }

    func openPlayer(_ kind: MusicPlayerKind) {
        guard let bundleId = kind.bundleIdentifier else { return }
        openApplication(bundleIdentifier: bundleId)
    }

    func openActivePlayer() {
        if let browserTarget = lastBrowserTarget,
           hasTrack,
           sourceBundleIdentifier == browserTarget.bundleID {
            Task {
                await focusBrowserTarget(browserTarget)
            }
            return
        }

        if let bundleID = sourceBundleIdentifier ?? player.bundleIdentifier {
            openApplication(bundleIdentifier: bundleID)
        } else if player != .none {
            openPlayer(player)
        } else if isAppInstalled("com.spotify.client") {
            openPlayer(.spotify)
        } else if isAppInstalled("com.apple.Music") {
            openPlayer(.appleMusic)
        }
    }

    private func openApplication(bundleIdentifier: String) {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: config)
        }
    }

    func isAppInstalled(_ bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    private func activeControllablePlayer() -> MusicPlayerKind {
        if player != .none { return player }
        if isRunning("com.spotify.client") { return .spotify }
        if isRunning("com.apple.Music") { return .appleMusic }
        if let browserTarget = lastBrowserTarget, isRunning(browserTarget.bundleID) {
            return browserTarget.kind
        }
        return .none
    }

    private func isRunning(_ bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    func pollNow() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        let activeAudioBundles = Self.activeAudioOutputBundleIDs()
        lastActiveAudioBundles = activeAudioBundles

        let spotifyRunning = isRunning("com.spotify.client")
        let appleMusicRunning = isRunning("com.apple.Music")

        var spotifyState: TrackSnapshot?
        var appleMusicState: TrackSnapshot?
        var sawNativeMusicDenied = false

        if spotifyRunning {
            let result = await fetchSpotifySnapshot()
            spotifyState = result.snapshot
            if result.denied { sawNativeMusicDenied = true }
        }

        if appleMusicRunning {
            let result = await fetchAppleMusicSnapshot()
            appleMusicState = result.snapshot
            if result.denied { sawNativeMusicDenied = true }
        }

        let browserState = await fetchBrowserSnapshot(activeAudioBundles: activeAudioBundles)
        let nativeVideoState = await fetchNativeVideoSnapshot(activeAudioBundles: activeAudioBundles)
        let otherAppState = await fetchOtherAudioAppSnapshot(activeAudioBundles: activeAudioBundles)

        let playingCandidates = [spotifyState, appleMusicState, browserState, nativeVideoState, otherAppState].compactMap { $0 }.filter { $0.isPlaying }
        let chosen: TrackSnapshot?

        if let currentMatch = playingCandidates.first(where: { $0.player == player && $0.sourceBundleIdentifier == sourceBundleIdentifier }) {
            chosen = currentMatch
        } else if let browserPlaying = browserState, browserPlaying.isPlaying {
            chosen = browserPlaying
        } else if let spotifyPlaying = spotifyState, spotifyPlaying.isPlaying {
            chosen = spotifyPlaying
        } else if let appleMusicPlaying = appleMusicState, appleMusicPlaying.isPlaying {
            chosen = appleMusicPlaying
        } else if let nativePlaying = nativeVideoState, nativePlaying.isPlaying {
            chosen = nativePlaying
        } else if let otherPlaying = otherAppState, otherPlaying.isPlaying {
            chosen = otherPlaying
        } else if let browserPaused = browserState {
            chosen = browserPaused
        } else if let nativePaused = nativeVideoState, player == nativePaused.player {
            chosen = nativePaused
        } else if let otherPaused = otherAppState, player == .otherApp || sourceBundleIdentifier == otherPaused.sourceBundleIdentifier {
            chosen = otherPaused
        } else if player == .appleMusic, let am = appleMusicState {
            chosen = am
        } else if let sp = spotifyState {
            chosen = sp
        } else if let am = appleMusicState {
            chosen = am
        } else {
            chosen = nativeVideoState ?? otherAppState
        }

        guard let snapshot = chosen else {
            clearTrack(denied: sawNativeMusicDenied)
            hasCompletedInitialPoll = true
            return
        }

        automationDenied = false

        let resolvedSourceName = snapshot.sourceDisplayName.isEmpty ? snapshot.player.displayName : snapshot.sourceDisplayName
        let resolvedSourceBundle = snapshot.sourceBundleIdentifier ?? snapshot.player.bundleIdentifier

        let previousSignature = lastTrackSignature
        let newSignature = snapshot.signatureIdentity ?? "\(snapshot.player.rawValue)|\(snapshot.title)|\(snapshot.artist)"
        let trackDidChange = !newSignature.isEmpty && newSignature != previousSignature

        player = snapshot.player
        isPlaying = snapshot.isPlaying
        title = snapshot.title
        artist = snapshot.artist
        album = snapshot.album
        duration = snapshot.duration
        elapsedTime = snapshot.duration > 0 ? min(max(0, snapshot.elapsed), snapshot.duration) : 0
        hasTrack = !snapshot.title.isEmpty
        sourceDisplayName = resolvedSourceName
        sourceBundleIdentifier = resolvedSourceBundle
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
        sourceDisplayName = ""
        sourceBundleIdentifier = nil
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
        var artworkImage: NSImage? = nil
        var sourceDisplayName: String = ""
        var sourceBundleIdentifier: String? = nil
        var signatureIdentity: String? = nil
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
            key = "url|\(urlStr)"
        } else if snapshot.player == .appleMusic || snapshot.player == .appleTV {
            key = "\(snapshot.player.rawValue)|\(snapshot.artist)|\(snapshot.album)|\(snapshot.title)"
        } else if let filePath = snapshot.artworkFilePath, !filePath.isEmpty {
            key = "file|\(snapshot.player.rawValue)|\(snapshot.title)"
        } else if snapshot.artworkImage != nil {
            key = "img|\(snapshot.sourceBundleIdentifier ?? snapshot.player.rawValue)"
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
                let (data, response) = try await URLSession.shared.data(from: url)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 200
                if status < 400 {
                    loadedImage = NSImage(data: data)
                }
            } catch {
                loadedImage = nil
            }
        } else if let path = snapshot.artworkFilePath {
            loadedImage = NSImage(contentsOfFile: path)
            try? FileManager.default.removeItem(atPath: path)
        }

        if loadedImage == nil, let fallbackImage = snapshot.artworkImage {
            loadedImage = fallbackImage
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
        switch kind {
        case .spotify:
            _ = await Self.executeAppleScript("tell application \"Spotify\" to \(command)")
        case .appleMusic:
            _ = await Self.executeAppleScript("tell application \"Music\" to \(command)")
        case .appleTV:
            _ = await Self.executeAppleScript("tell application \"TV\" to \(command)")
        case .vlc:
            let vlcCmd: String
            switch command {
            case "playpause":
                vlcCmd = "play"
            case "next track":
                vlcCmd = "next"
            case "previous track":
                vlcCmd = "previous"
            default:
                return
            }
            _ = await Self.executeAppleScript("tell application \"VLC\" to \(vlcCmd)")
        case .quickTime:
            let qtScript: String
            switch command {
            case "playpause":
                qtScript = """
                tell application "QuickTime Player"
                    if (count of documents) > 0 then
                        if playing of document 1 then
                            pause document 1
                        else
                            play document 1
                        end if
                    end if
                end tell
                """
            case "next track":
                qtScript = """
                tell application "QuickTime Player"
                    if (count of documents) > 0 then
                        set d to duration of document 1
                        set t to current time of document 1
                        if t + 10 < d then
                            set current time of document 1 to (t + 10)
                        else
                            set current time of document 1 to d
                        end if
                    end if
                end tell
                """
            case "previous track":
                qtScript = """
                tell application "QuickTime Player"
                    if (count of documents) > 0 then
                        set t to current time of document 1
                        if t - 10 > 0 then
                            set current time of document 1 to (t - 10)
                        else
                            set current time of document 1 to 0
                        end if
                    end if
                end tell
                """
            default:
                return
            }
            _ = await Self.executeAppleScript(qtScript)
        default:
            return
        }
    }

    // MARK: - CoreAudio Process Audio Detection

    private static func activeAudioOutputBundleIDs() -> Set<String> {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size
        ) == noErr, size > 0 else {
            return []
        }

        let count = Int(size) / MemoryLayout<AudioObjectID>.stride
        var processObjects = [AudioObjectID](repeating: 0, count: count)
        var actualSize = size
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &actualSize,
            &processObjects
        ) == noErr else {
            return []
        }

        let validCount = min(count, Int(actualSize) / MemoryLayout<AudioObjectID>.stride)
        var activeBundles = Set<String>()

        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningOutput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var bundleAddress = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyBundleID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        for index in 0..<validCount {
            let objID = processObjects[index]
            var isRunningOutput: UInt32 = 0
            var runSize = UInt32(MemoryLayout<UInt32>.size)
            let runStatus = AudioObjectGetPropertyData(objID, &runningAddress, 0, nil, &runSize, &isRunningOutput)
            guard runStatus == noErr, isRunningOutput != 0 else { continue }

            var cfBundle: Unmanaged<CFString>?
            var bundleSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            let bundleStatus = withUnsafeMutablePointer(to: &cfBundle) { ptr in
                AudioObjectGetPropertyData(objID, &bundleAddress, 0, nil, &bundleSize, ptr)
            }
            if bundleStatus == noErr, let cfStr = cfBundle?.takeRetainedValue() {
                let rawBundle = (cfStr as String).trimmingCharacters(in: .whitespacesAndNewlines)
                if !rawBundle.isEmpty {
                    activeBundles.insert(rawBundle)
                }
            }
        }
        return activeBundles
    }

    private func isAudioActive(for browser: SupportedBrowser, in activeAudioBundles: Set<String>) -> Bool {
        let baseLower = browser.bundleID.lowercased()
        for active in activeAudioBundles {
            let lower = active.lowercased()
            if lower == baseLower || lower.hasPrefix(baseLower + ".helper") || lower.hasPrefix(baseLower + ".renderer") {
                return true
            }
            if browser.engine == .safari && (lower.hasPrefix("com.apple.webkit") || lower.hasPrefix(baseLower)) {
                return true
            }
        }
        return false
    }

    private func isAudioActive(bundlePrefix: String, in activeAudioBundles: Set<String>) -> Bool {
        let p = bundlePrefix.lowercased()
        return activeAudioBundles.contains { active in
            let lower = active.lowercased()
            return lower == p || lower.hasPrefix(p + ".")
        }
    }

    // MARK: - Browser Tab Scanning & Tier 2 JS

    private static let supportedBrowsers: [SupportedBrowser] = [
        SupportedBrowser(bundleID: "com.google.Chrome.canary", appName: "Google Chrome Canary", engine: .chromium, audioBundlePrefixes: ["com.google.Chrome.canary"]),
        SupportedBrowser(bundleID: "com.google.Chrome", appName: "Google Chrome", engine: .chromium, audioBundlePrefixes: ["com.google.Chrome"]),
        SupportedBrowser(bundleID: "company.thebrowser.Browser", appName: "Arc", engine: .chromium, audioBundlePrefixes: ["company.thebrowser.Browser"]),
        SupportedBrowser(bundleID: "com.brave.Browser", appName: "Brave Browser", engine: .chromium, audioBundlePrefixes: ["com.brave.Browser"]),
        SupportedBrowser(bundleID: "com.microsoft.edgemac", appName: "Microsoft Edge", engine: .chromium, audioBundlePrefixes: ["com.microsoft.edgemac"]),
        SupportedBrowser(bundleID: "com.operasoftware.Opera", appName: "Opera", engine: .chromium, audioBundlePrefixes: ["com.operasoftware.Opera"]),
        SupportedBrowser(bundleID: "com.vivaldi.Vivaldi", appName: "Vivaldi", engine: .chromium, audioBundlePrefixes: ["com.vivaldi.Vivaldi"]),
        SupportedBrowser(bundleID: "com.apple.Safari", appName: "Safari", engine: .safari, audioBundlePrefixes: ["com.apple.Safari", "com.apple.WebKit"]),
        SupportedBrowser(bundleID: "com.apple.SafariTechnologyPreview", appName: "Safari Technology Preview", engine: .safari, audioBundlePrefixes: ["com.apple.SafariTechnologyPreview", "com.apple.WebKit"])
    ]

    private func fetchBrowserSnapshot(activeAudioBundles: Set<String>) async -> TrackSnapshot? {
        let now = Date()
        let activeBrowsers = Self.supportedBrowsers.filter { browser in
            isRunning(browser.bundleID)
                && !browserAutomationDenied.contains(browser.bundleID)
                && isAudioActive(for: browser, in: activeAudioBundles)
        }

        let recentPausedBrowsers = Self.supportedBrowsers.filter { browser in
            isRunning(browser.bundleID)
                && !browserAutomationDenied.contains(browser.bundleID)
                && !isAudioActive(for: browser, in: activeAudioBundles)
                && lastBrowserTarget?.bundleID == browser.bundleID
                && now.timeIntervalSince(lastBrowserMediaTimestamp) < 180
        }

        for browser in activeBrowsers {
            if let snapshot = await scanBrowser(browser, audioIsActive: true) {
                return snapshot
            }
        }

        for browser in recentPausedBrowsers {
            if let snapshot = await scanBrowser(browser, audioIsActive: false) {
                return snapshot
            }
        }

        if let prev = lastBrowserTarget, !isRunning(prev.bundleID) || now.timeIntervalSince(lastBrowserMediaTimestamp) >= 180 {
            lastBrowserTarget = nil
        }
        return nil
    }

    private func scanBrowser(_ browser: SupportedBrowser, audioIsActive: Bool) async -> TrackSnapshot? {
        let tabsResult = await fetchBrowserTabs(for: browser)
        if tabsResult.denied {
            browserAutomationDenied.insert(browser.bundleID)
            if lastBrowserTarget?.bundleID == browser.bundleID {
                lastBrowserTarget = nil
            }
            return nil
        }

        let tabs = tabsResult.tabs
        guard !tabs.isEmpty else {
            if !audioIsActive && lastBrowserTarget?.bundleID == browser.bundleID {
                lastBrowserTarget = nil
            }
            return nil
        }

        let classified = tabs.map { entry -> (entry: BrowserTabEntry, meta: URLMediaClassification) in
            (entry, classifyMediaURL(entry.urlString, rawTitle: entry.title))
        }

        if !audioIsActive {
            guard let prev = lastBrowserTarget, prev.bundleID == browser.bundleID else { return nil }
            let matched = classified.first {
                $0.entry.urlString == prev.urlString
            } ?? classified.first {
                $0.entry.windowIndex == prev.windowIndex && $0.entry.tabIndex == prev.tabIndex && $0.meta.isKnownMedia
            }

            guard let found = matched else {
                lastBrowserTarget = nil
                return nil
            }

            return await buildBrowserSnapshot(
                browser: browser,
                tab: found.entry,
                classification: found.meta,
                audioIsActive: false
            )
        }

        if canExecuteJS(in: browser.bundleID) {
            var candidateIndices: [Int] = []
            if let activeFrontIdx = classified.firstIndex(where: { $0.entry.windowIndex == 1 && $0.entry.isActiveTab }) {
                candidateIndices.append(activeFrontIdx)
            }
            if let prev = lastBrowserTarget, prev.bundleID == browser.bundleID,
               let prevIdx = classified.firstIndex(where: { $0.entry.urlString == prev.urlString }),
               !candidateIndices.contains(prevIdx) {
                candidateIndices.append(prevIdx)
            }
            for (idx, item) in classified.enumerated() where item.meta.isKnownMedia {
                if !candidateIndices.contains(idx) {
                    candidateIndices.append(idx)
                }
                if candidateIndices.count >= 4 { break }
            }

            for idx in candidateIndices {
                let candidate = classified[idx]
                if let dom = await probeBrowserTabDOM(browser: browser, windowIndex: candidate.entry.windowIndex, tabIndex: candidate.entry.tabIndex),
                   !dom.isPaused {
                    return await buildBrowserSnapshot(
                        browser: browser,
                        tab: candidate.entry,
                        classification: candidate.meta,
                        audioIsActive: true,
                        domOverride: dom
                    )
                }
            }
        }

        let chosen: (entry: BrowserTabEntry, meta: URLMediaClassification)?
        if let frontKnown = classified.first(where: { $0.entry.windowIndex == 1 && $0.entry.isActiveTab && $0.meta.isKnownMedia }) {
            chosen = frontKnown
        } else if let otherWindowActiveKnown = classified.first(where: { $0.entry.isActiveTab && $0.meta.isKnownMedia }) {
            chosen = otherWindowActiveKnown
        } else if let prev = lastBrowserTarget, prev.bundleID == browser.bundleID,
                  let prevMatch = classified.first(where: { $0.entry.urlString == prev.urlString && $0.meta.isKnownMedia }) {
            chosen = prevMatch
        } else if let anyKnown = classified.first(where: { $0.meta.isKnownMedia }) {
            chosen = anyKnown
        } else if let frontActive = classified.first(where: { $0.entry.windowIndex == 1 && $0.entry.isActiveTab && !$0.entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            chosen = frontActive
        } else {
            chosen = classified.first(where: { !$0.entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        }

        guard let selected = chosen else { return nil }
        return await buildBrowserSnapshot(
            browser: browser,
            tab: selected.entry,
            classification: selected.meta,
            audioIsActive: true
        )
    }

    private func buildBrowserSnapshot(
        browser: SupportedBrowser,
        tab: BrowserTabEntry,
        classification: URLMediaClassification,
        audioIsActive: Bool,
        domOverride: BrowserDOMProbe? = nil
    ) async -> TrackSnapshot {
        var domProbe = domOverride
        if domProbe == nil && canExecuteJS(in: browser.bundleID) {
            domProbe = await probeBrowserTabDOM(browser: browser, windowIndex: tab.windowIndex, tabIndex: tab.tabIndex)
        }

        let oEmbed = oEmbedCache[classification.oEmbedCacheKey ?? ""]
        if let oEmbedKey = classification.oEmbedCacheKey,
           let oEmbedURL = classification.oEmbedEndpoint,
           oEmbed == nil {
            scheduleOEmbedFetch(cacheKey: oEmbedKey, endpointURL: oEmbedURL)
        }

        let resolvedIsPlaying: Bool
        if let dom = domProbe {
            resolvedIsPlaying = audioIsActive && !dom.isPaused
        } else {
            resolvedIsPlaying = audioIsActive
        }

        let cleanTitle: String
        if let domTitle = domProbe?.title, !domTitle.isEmpty {
            cleanTitle = stripPlatformSuffix(from: domTitle, kind: classification.kind)
        } else if let oTitle = oEmbed?.title, !oTitle.isEmpty {
            cleanTitle = oTitle
        } else if !classification.cleanedTitle.isEmpty {
            cleanTitle = classification.cleanedTitle
        } else {
            cleanTitle = browser.appName
        }

        let cleanArtist: String
        if let domArtist = domProbe?.artist, !domArtist.isEmpty {
            cleanArtist = domArtist
        } else if let oAuthor = oEmbed?.authorName, !oAuthor.isEmpty {
            cleanArtist = oAuthor
        } else if !classification.fallbackArtist.isEmpty {
            cleanArtist = classification.fallbackArtist
        } else {
            cleanArtist = browser.appName
        }

        let artworkURL: String?
        if let domArt = domProbe?.artworkURL, !domArt.isEmpty {
            artworkURL = domArt
        } else if let directThumb = classification.directArtworkURL {
            artworkURL = directThumb
        } else if let oThumb = oEmbed?.thumbnailURL, !oThumb.isEmpty {
            artworkURL = oThumb
        } else {
            artworkURL = nil
        }

        let browserIcon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }

        let now = Date()
        lastBrowserTarget = ActiveBrowserTarget(
            bundleID: browser.bundleID,
            appName: browser.appName,
            engine: browser.engine,
            windowIndex: tab.windowIndex,
            tabIndex: tab.tabIndex,
            urlString: tab.urlString,
            kind: classification.kind,
            sourceName: classification.sourceName,
            detectedAt: now
        )
        if resolvedIsPlaying {
            lastBrowserMediaTimestamp = now
        }

        let canonicalIdentity = classification.oEmbedCacheKey ?? "\(browser.bundleID)|\(tab.urlString)"

        return TrackSnapshot(
            player: classification.kind,
            isPlaying: resolvedIsPlaying,
            title: cleanTitle,
            artist: cleanArtist,
            album: domProbe?.album ?? "",
            duration: domProbe?.duration ?? 0,
            elapsed: domProbe?.elapsed ?? 0,
            artworkURL: artworkURL,
            artworkFilePath: nil,
            artworkImage: browserIcon,
            sourceDisplayName: classification.sourceName,
            sourceBundleIdentifier: browser.bundleID,
            signatureIdentity: canonicalIdentity
        )
    }

    private func fetchBrowserTabs(for browser: SupportedBrowser) async -> (tabs: [BrowserTabEntry], denied: Bool) {
        let script: String
        switch browser.engine {
        case .chromium:
            script = """
            tell application "\(browser.appName)"
                if (count of windows) is 0 then return ""
                set fSep to character id 31
                set rSep to character id 30
                set outText to ""
                set winCount to count of windows
                if winCount > 5 then set winCount to 5
                repeat with wIdx from 1 to winCount
                    try
                        set w to window wIdx
                        set activeTabIndex to 0
                        set activeTabURL to ""
                        try
                            set activeTabIndex to active tab index of w
                        on error
                            try
                                set activeTabURL to (URL of active tab of w) as string
                            end try
                        end try
                        set tabList to tabs of w
                        set tCount to count of tabList
                        if tCount > 40 then set tCount to 40
                        repeat with tIdx from 1 to tCount
                            try
                                set t to item tIdx of tabList
                                set tURL to ""
                                try
                                    set uVal to URL of t
                                    if uVal is not missing value then set tURL to uVal as string
                                end try
                                set tTitle to ""
                                try
                                    set ttlVal to title of t
                                    if ttlVal is not missing value then set tTitle to ttlVal as string
                                end try
                                set isAct to "0"
                                if tIdx is activeTabIndex or (activeTabIndex is 0 and activeTabURL is not "" and tURL is activeTabURL) then
                                    set isAct to "1"
                                end if
                                if tURL is not "" then
                                    set outText to outText & (wIdx as string) & fSep & (tIdx as string) & fSep & isAct & fSep & tURL & fSep & tTitle & rSep
                                end if
                            end try
                        end repeat
                    end try
                end repeat
                return outText
            end tell
            """
        case .safari:
            script = """
            tell application "\(browser.appName)"
                if (count of windows) is 0 then return ""
                set fSep to character id 31
                set rSep to character id 30
                set outText to ""
                set winCount to count of windows
                if winCount > 5 then set winCount to 5
                repeat with wIdx from 1 to winCount
                    try
                        set w to window wIdx
                        set activeTabIndex to 0
                        try
                            set activeTabIndex to index of current tab of w
                        end try
                        set tabList to tabs of w
                        set tCount to count of tabList
                        if tCount > 40 then set tCount to 40
                        repeat with tIdx from 1 to tCount
                            try
                                set t to item tIdx of tabList
                                set tURL to ""
                                try
                                    set uVal to URL of t
                                    if uVal is not missing value then set tURL to uVal as string
                                end try
                                set tTitle to ""
                                try
                                    set ttlVal to name of t
                                    if ttlVal is not missing value then set tTitle to ttlVal as string
                                end try
                                set isAct to "0"
                                if tIdx is activeTabIndex then set isAct to "1"
                                if tURL is not "" then
                                    set outText to outText & (wIdx as string) & fSep & (tIdx as string) & fSep & isAct & fSep & tURL & fSep & tTitle & rSep
                                end if
                            end try
                        end repeat
                    end try
                end repeat
                return outText
            end tell
            """
        }

        let res = await Self.executeAppleScript(script)
        if res.isPermissionDenied { return ([], true) }
        guard res.exitCode == 0 else { return ([], false) }

        let records = res.output.components(separatedBy: "\u{001E}")
        var entries: [BrowserTabEntry] = []
        for record in records {
            let trimmedRecord = record.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedRecord.isEmpty else { continue }
            let fields = record.components(separatedBy: "\u{001F}")
            guard fields.count >= 5 else { continue }
            let wIdx = Int(fields[0].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
            let tIdx = Int(fields[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
            let isAct = fields[2].trimmingCharacters(in: .whitespacesAndNewlines) == "1"
            let urlStr = fields[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawTitle = fields[4]
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            entries.append(BrowserTabEntry(windowIndex: wIdx, tabIndex: tIdx, isActiveTab: isAct, urlString: urlStr, title: rawTitle))
        }
        return (entries, false)
    }

    private func canExecuteJS(in bundleID: String) -> Bool {
        guard let lastDenied = jsDeniedBrowsers[bundleID] else { return true }
        return Date().timeIntervalSince(lastDenied) > 120
    }

    private func probeBrowserTabDOM(browser: SupportedBrowser, windowIndex: Int, tabIndex: Int) async -> BrowserDOMProbe? {
        let js = """
        (() => {
          const els = Array.from(document.querySelectorAll('video, audio'));
          const playing = els.find(e => !e.paused && !e.ended && e.readyState > 0) || els.find(e => (e.duration || 0) > 0) || els[0];
          const m = navigator.mediaSession && navigator.mediaSession.metadata;
          if (!playing && !m) return '';
          const artList = m && m.artwork ? Array.from(m.artwork) : [];
          const bestArt = artList.length ? artList[artList.length - 1].src : '';
          const paused = playing ? Boolean(playing.paused) : (navigator.mediaSession.playbackState !== 'playing');
          const dur = playing && isFinite(playing.duration) ? Number(playing.duration) : 0;
          const cur = playing && isFinite(playing.currentTime) ? Number(playing.currentTime) : 0;
          const ttl = (m && m.title) ? m.title : (document.title || '');
          const art = (m && m.artist) ? m.artist : '';
          const alb = (m && m.album) ? m.album : '';
          const s = '\\u001F';
          return (paused ? '0' : '1') + s + dur + s + cur + s + ttl + s + art + s + alb + s + bestArt;
        })()
        """
        guard let output = await runBrowserJavaScript(browserAppName: browser.appName, browserBundleID: browser.bundleID, engine: browser.engine, windowIndex: windowIndex, tabIndex: tabIndex, jsCode: js) else {
            return nil
        }

        let fields = output.components(separatedBy: "\u{001F}")
        guard fields.count >= 7 else { return nil }
        return BrowserDOMProbe(
            isPaused: fields[0].trimmingCharacters(in: .whitespacesAndNewlines) != "1",
            duration: parseLocalizedDouble(fields[1]),
            elapsed: parseLocalizedDouble(fields[2]),
            title: fields[3].trimmingCharacters(in: .whitespacesAndNewlines),
            artist: fields[4].trimmingCharacters(in: .whitespacesAndNewlines),
            album: fields[5].trimmingCharacters(in: .whitespacesAndNewlines),
            artworkURL: fields[6].trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private enum BrowserControlAction {
        case playPause
        case next
        case previous
    }

    private func controlBrowserMedia(_ target: ActiveBrowserTarget, action: BrowserControlAction) async -> Bool {
        guard canExecuteJS(in: target.bundleID) else { return false }
        let js: String
        switch action {
        case .playPause:
            js = """
            (() => {
              const els = Array.from(document.querySelectorAll('video, audio'));
              const el = els.find(e => !e.paused && !e.ended) || els.find(e => e.readyState > 0) || els[0];
              if (!el) return '';
              if (el.paused) { el.play(); } else { el.pause(); }
              return 'OK';
            })()
            """
        case .next:
            js = """
            (() => {
              const btn = document.querySelector('.ytp-next-button, [data-testid="control-button-skip-forward"], [aria-label*="Next" i]');
              if (btn) { btn.click(); return 'OK'; }
              return '';
            })()
            """
        case .previous:
            js = """
            (() => {
              const els = Array.from(document.querySelectorAll('video, audio'));
              const el = els.find(e => e.readyState > 0) || els[0];
              if (el && el.currentTime > 3) { el.currentTime = 0; return 'OK'; }
              const btn = document.querySelector('.ytp-prev-button, [data-testid="control-button-skip-back"], [aria-label*="Previous" i]');
              if (btn) { btn.click(); return 'OK'; }
              if (el) { el.currentTime = 0; return 'OK'; }
              return '';
            })()
            """
        }

        let res = await runBrowserJavaScript(
            browserAppName: target.appName,
            browserBundleID: target.bundleID,
            engine: target.engine,
            windowIndex: target.windowIndex,
            tabIndex: target.tabIndex,
            jsCode: js
        )
        return res == "OK"
    }

    private func seekBrowserMedia(_ target: ActiveBrowserTarget, to seconds: Double) async -> Bool {
        guard canExecuteJS(in: target.bundleID) else { return false }
        let formatted = String(format: "%.2f", seconds)
        let js = """
        (() => {
          const els = Array.from(document.querySelectorAll('video, audio'));
          const el = els.find(e => (e.duration || 0) > 0) || els[0];
          if (!el) return '';
          el.currentTime = \(formatted);
          return 'OK';
        })()
        """
        let res = await runBrowserJavaScript(
            browserAppName: target.appName,
            browserBundleID: target.bundleID,
            engine: target.engine,
            windowIndex: target.windowIndex,
            tabIndex: target.tabIndex,
            jsCode: js
        )
        return res == "OK"
    }

    private func focusBrowserTarget(_ target: ActiveBrowserTarget) async {
        guard !browserAutomationDenied.contains(target.bundleID) else {
            openApplication(bundleIdentifier: target.bundleID)
            return
        }

        let script: String
        switch target.engine {
        case .chromium:
            script = """
            tell application "\(target.appName)"
                activate
                try
                    set index of window \(target.windowIndex) to 1
                end try
                try
                    set active tab index of window 1 to \(target.tabIndex)
                on error
                    try
                        select tab \(target.tabIndex) of window 1
                    end try
                end try
            end tell
            """
        case .safari:
            script = """
            tell application "\(target.appName)"
                activate
                try
                    set index of window \(target.windowIndex) to 1
                    set current tab of window 1 to tab \(target.tabIndex) of window 1
                end try
            end tell
            """
        }

        let res = await Self.executeAppleScript(script)
        if res.exitCode != 0 {
            openApplication(bundleIdentifier: target.bundleID)
        }
    }

    private func runBrowserJavaScript(
        browserAppName: String,
        browserBundleID: String,
        engine: BrowserEngine,
        windowIndex: Int,
        tabIndex: Int,
        jsCode: String
    ) async -> String? {
        let escapedJS = jsCode
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")

        let script: String
        switch engine {
        case .chromium:
            script = """
            tell application "\(browserAppName)"
                tell tab \(tabIndex) of window \(windowIndex)
                    return execute javascript "\(escapedJS)"
                end tell
            end tell
            """
        case .safari:
            script = """
            tell application "\(browserAppName)"
                return do JavaScript "\(escapedJS)" in tab \(tabIndex) of window \(windowIndex)
            end tell
            """
        }

        let res = await Self.executeAppleScript(script)
        if res.isPermissionDenied {
            browserAutomationDenied.insert(browserBundleID)
            return nil
        }
        if res.exitCode != 0 {
            let errLower = res.errorOutput.lowercased()
            if errLower.contains("javascript") || errLower.contains("apple events") || errLower.contains("turned off") {
                jsDeniedBrowsers[browserBundleID] = Date()
            }
            return nil
        }
        let trimmed = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - URL Classification & Public oEmbed

    private struct URLMediaClassification {
        let kind: MusicPlayerKind
        let sourceName: String
        let cleanedTitle: String
        let fallbackArtist: String
        let directArtworkURL: String?
        let oEmbedCacheKey: String?
        let oEmbedEndpoint: String?
        let isKnownMedia: Bool
    }

    private func classifyMediaURL(_ urlString: String, rawTitle: String) -> URLMediaClassification {
        let url = URL(string: urlString)
        let host = (url?.host ?? "").lowercased()
        let path = url?.path ?? ""

        if host == "music.youtube.com" {
            let videoID = extractYouTubeVideoID(urlString)
            let cleaned = stripPlatformSuffix(from: rawTitle, kind: .youtubeMusic)
            let directArt = videoID.map { "https://i.ytimg.com/vi/\($0)/hqdefault.jpg" }
            let oKey = videoID.map { "ytm:\($0)" }
            let oEndpoint = videoID.map { "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\($0)&format=json" }
            return URLMediaClassification(
                kind: .youtubeMusic,
                sourceName: "YouTube Music",
                cleanedTitle: cleaned,
                fallbackArtist: "YouTube Music",
                directArtworkURL: directArt,
                oEmbedCacheKey: oKey,
                oEmbedEndpoint: oEndpoint,
                isKnownMedia: true
            )
        }

        if host.contains("youtube.com") || host == "youtu.be" || host.contains("youtube-nocookie.com") {
            let videoID = extractYouTubeVideoID(urlString)
            let cleaned = stripPlatformSuffix(from: rawTitle, kind: .youtube)
            let directArt = videoID.map { "https://i.ytimg.com/vi/\($0)/hqdefault.jpg" }
            let oKey = videoID.map { "yt:\($0)" }
            let oEndpoint = videoID.map { "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\($0)&format=json" }
            let isWatchPage = videoID != nil || path.contains("/watch") || path.contains("/shorts/") || path.contains("/live/")
            return URLMediaClassification(
                kind: .youtube,
                sourceName: "YouTube",
                cleanedTitle: cleaned,
                fallbackArtist: "YouTube",
                directArtworkURL: directArt,
                oEmbedCacheKey: oKey,
                oEmbedEndpoint: oEndpoint,
                isKnownMedia: isWatchPage
            )
        }

        if host.contains("netflix.com") {
            let isWatch = path.contains("/watch")
            return URLMediaClassification(
                kind: .netflix,
                sourceName: "Netflix",
                cleanedTitle: stripPlatformSuffix(from: rawTitle, kind: .netflix),
                fallbackArtist: "Netflix",
                directArtworkURL: nil,
                oEmbedCacheKey: nil,
                oEmbedEndpoint: nil,
                isKnownMedia: isWatch
            )
        }

        if host.contains("twitch.tv") {
            let lowerPath = path.lowercased()
            let ignored = lowerPath == "/" || lowerPath.isEmpty || lowerPath.hasPrefix("/directory") || lowerPath.hasPrefix("/settings")
            return URLMediaClassification(
                kind: .twitch,
                sourceName: "Twitch",
                cleanedTitle: stripPlatformSuffix(from: rawTitle, kind: .twitch),
                fallbackArtist: "Twitch",
                directArtworkURL: nil,
                oEmbedCacheKey: nil,
                oEmbedEndpoint: nil,
                isKnownMedia: !ignored
            )
        }

        if host.contains("primevideo.com") || (host.contains("amazon.") && (path.contains("/gp/video") || path.contains("Prime-Video"))) {
            return URLMediaClassification(
                kind: .primeVideo,
                sourceName: "Prime Video",
                cleanedTitle: stripPlatformSuffix(from: rawTitle, kind: .primeVideo),
                fallbackArtist: "Prime Video",
                directArtworkURL: nil,
                oEmbedCacheKey: nil,
                oEmbedEndpoint: nil,
                isKnownMedia: true
            )
        }

        if host.contains("disneyplus.com") {
            return URLMediaClassification(
                kind: .disneyPlus,
                sourceName: "Disney+",
                cleanedTitle: stripPlatformSuffix(from: rawTitle, kind: .disneyPlus),
                fallbackArtist: "Disney+",
                directArtworkURL: nil,
                oEmbedCacheKey: nil,
                oEmbedEndpoint: nil,
                isKnownMedia: path.contains("/video") || path.contains("/play")
            )
        }

        if host == "play.max.com" || (host.contains("max.com") && path.contains("/video")) {
            return URLMediaClassification(
                kind: .maxVideo,
                sourceName: "Max",
                cleanedTitle: stripPlatformSuffix(from: rawTitle, kind: .maxVideo),
                fallbackArtist: "Max",
                directArtworkURL: nil,
                oEmbedCacheKey: nil,
                oEmbedEndpoint: nil,
                isKnownMedia: true
            )
        }

        if host.contains("globoplay.globo.com") {
            return URLMediaClassification(
                kind: .globoplay,
                sourceName: "Globoplay",
                cleanedTitle: stripPlatformSuffix(from: rawTitle, kind: .globoplay),
                fallbackArtist: "Globoplay",
                directArtworkURL: nil,
                oEmbedCacheKey: nil,
                oEmbedEndpoint: nil,
                isKnownMedia: path.contains("/v/") || path.contains("/ao-vivo")
            )
        }

        if host.contains("crunchyroll.com") {
            return URLMediaClassification(
                kind: .crunchyroll,
                sourceName: "Crunchyroll",
                cleanedTitle: stripPlatformSuffix(from: rawTitle, kind: .crunchyroll),
                fallbackArtist: "Crunchyroll",
                directArtworkURL: nil,
                oEmbedCacheKey: nil,
                oEmbedEndpoint: nil,
                isKnownMedia: path.contains("/watch")
            )
        }

        if host.contains("soundcloud.com") {
            let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let isTrack = path.split(separator: "/").count >= 2
            return URLMediaClassification(
                kind: .soundcloud,
                sourceName: "SoundCloud",
                cleanedTitle: stripPlatformSuffix(from: rawTitle, kind: .soundcloud),
                fallbackArtist: "SoundCloud",
                directArtworkURL: nil,
                oEmbedCacheKey: isTrack ? "sc:\(urlString)" : nil,
                oEmbedEndpoint: isTrack && !encoded.isEmpty ? "https://soundcloud.com/oembed?format=json&url=\(encoded)" : nil,
                isKnownMedia: isTrack
            )
        }

        if host.contains("deezer.com") {
            return URLMediaClassification(
                kind: .deezer,
                sourceName: "Deezer",
                cleanedTitle: stripPlatformSuffix(from: rawTitle, kind: .deezer),
                fallbackArtist: "Deezer",
                directArtworkURL: nil,
                oEmbedCacheKey: nil,
                oEmbedEndpoint: nil,
                isKnownMedia: true
            )
        }

        if host.contains("tidal.com") {
            return URLMediaClassification(
                kind: .tidal,
                sourceName: "Tidal",
                cleanedTitle: stripPlatformSuffix(from: rawTitle, kind: .tidal),
                fallbackArtist: "Tidal",
                directArtworkURL: nil,
                oEmbedCacheKey: nil,
                oEmbedEndpoint: nil,
                isKnownMedia: true
            )
        }

        if host.contains("vimeo.com") {
            let numericID = path.split(separator: "/").first { $0.allSatisfy(\.isNumber) }.map(String.init)
            return URLMediaClassification(
                kind: .vimeo,
                sourceName: "Vimeo",
                cleanedTitle: stripPlatformSuffix(from: rawTitle, kind: .vimeo),
                fallbackArtist: "Vimeo",
                directArtworkURL: nil,
                oEmbedCacheKey: numericID.map { "vimeo:\($0)" },
                oEmbedEndpoint: numericID.map { "https://vimeo.com/api/oembed.json?url=https://vimeo.com/\($0)" },
                isKnownMedia: numericID != nil
            )
        }

        if host == "open.spotify.com" {
            return URLMediaClassification(
                kind: .spotify,
                sourceName: "Spotify Web",
                cleanedTitle: stripPlatformSuffix(from: rawTitle, kind: .spotify),
                fallbackArtist: "Spotify",
                directArtworkURL: nil,
                oEmbedCacheKey: nil,
                oEmbedEndpoint: nil,
                isKnownMedia: true
            )
        }

        if host == "music.apple.com" {
            return URLMediaClassification(
                kind: .appleMusic,
                sourceName: "Apple Music Web",
                cleanedTitle: stripPlatformSuffix(from: rawTitle, kind: .appleMusic),
                fallbackArtist: "Apple Music",
                directArtworkURL: nil,
                oEmbedCacheKey: nil,
                oEmbedEndpoint: nil,
                isKnownMedia: true
            )
        }

        let displayDomain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return URLMediaClassification(
            kind: .browser,
            sourceName: displayDomain.isEmpty ? "Navegador" : displayDomain,
            cleanedTitle: rawTitle,
            fallbackArtist: displayDomain.isEmpty ? "Navegador" : displayDomain,
            directArtworkURL: nil,
            oEmbedCacheKey: nil,
            oEmbedEndpoint: nil,
            isKnownMedia: false
        )
    }

    private func extractYouTubeVideoID(_ urlString: String) -> String? {
        guard let components = URLComponents(string: urlString) else { return nil }
        let host = (components.host ?? "").lowercased()
        let pathParts = components.path.split(separator: "/").map(String.init)

        var candidate: String?
        if host == "youtu.be", let first = pathParts.first {
            candidate = first
        } else if let queryV = components.queryItems?.first(where: { $0.name == "v" })?.value {
            candidate = queryV
        } else if let markerIndex = pathParts.firstIndex(where: { $0 == "shorts" || $0 == "live" || $0 == "embed" }),
                  markerIndex + 1 < pathParts.count {
            candidate = pathParts[markerIndex + 1]
        }

        guard let id = candidate else { return nil }
        let validSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard id.count >= 6, id.count <= 24, id.unicodeScalars.allSatisfy({ validSet.contains($0) }) else {
            return nil
        }
        return id
    }

    private func stripPlatformSuffix(from title: String, kind: MusicPlayerKind) -> String {
        var result = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("("), let closeIdx = result.firstIndex(of: ")") {
            let inside = result[result.index(after: result.startIndex)..<closeIdx]
            if inside.allSatisfy(\.isNumber) {
                result = result[result.index(after: closeIdx)...].trimmingCharacters(in: .whitespaces)
            }
        }
        let suffixes: [String]
        switch kind {
        case .youtube:
            suffixes = [" - YouTube"]
        case .youtubeMusic:
            suffixes = [" - YouTube Music"]
        case .netflix:
            suffixes = [" - Netflix", " | Netflix"]
        case .twitch:
            suffixes = [" - Twitch"]
        case .primeVideo:
            suffixes = [" - Prime Video", " | Prime Video", ": Prime Video"]
        case .disneyPlus:
            suffixes = [" | Disney+", " - Disney+"]
        case .maxVideo:
            suffixes = [" | Max", " - Max"]
        case .globoplay:
            suffixes = [" | globoplay", " | Globoplay", " - Globoplay"]
        case .crunchyroll:
            suffixes = [" - Crunchyroll", " | Crunchyroll", " - Watch on Crunchyroll"]
        case .soundcloud:
            suffixes = [" | SoundCloud", " - SoundCloud"]
        case .deezer:
            suffixes = [" - Deezer"]
        case .tidal:
            suffixes = [" | TIDAL", " - TIDAL", " - Tidal"]
        case .vimeo:
            suffixes = [" on Vimeo", " no Vimeo"]
        default:
            suffixes = []
        }

        for suffix in suffixes where result.hasSuffix(suffix) {
            result = String(result.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }
        return result
    }

    private func scheduleOEmbedFetch(cacheKey: String, endpointURL: String) {
        guard !oEmbedInFlight.contains(cacheKey),
              let url = URL(string: endpointURL) else {
            return
        }
        oEmbedInFlight.insert(cacheKey)
        Task {
            defer {
                Task { @MainActor in
                    self.oEmbedInFlight.remove(cacheKey)
                }
            }
            var metadata = OEmbedMetadata(title: nil, authorName: nil, thumbnailURL: nil)
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 200
                if status < 400,
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    metadata = OEmbedMetadata(
                        title: json["title"] as? String,
                        authorName: json["author_name"] as? String,
                        thumbnailURL: json["thumbnail_url"] as? String
                    )
                }
            } catch {
                metadata = OEmbedMetadata(title: nil, authorName: nil, thumbnailURL: nil)
            }
            await MainActor.run {
                if self.oEmbedCache.count > 48 {
                    self.oEmbedCache.removeAll()
                }
                self.oEmbedCache[cacheKey] = metadata
            }
            if metadata.authorName != nil || metadata.thumbnailURL != nil {
                await self.pollNow()
            }
        }
    }

    // MARK: - Native Video & Universal Audio Fallback

    private func fetchNativeVideoSnapshot(activeAudioBundles: Set<String>) async -> TrackSnapshot? {
        let now = Date()
        let vlcBundle = "org.videolan.vlc"
        let qtBundle = "com.apple.QuickTimePlayerX"
        let tvBundle = "com.apple.TV"

        if isRunning(vlcBundle) && !nativeAutomationDenied.contains(vlcBundle) {
            let vlcActive = isAudioActive(bundlePrefix: vlcBundle, in: activeAudioBundles)
            let vlcRecent = lastNativeVideoKind == .vlc && now.timeIntervalSince(lastNativeVideoTimestamp) < 180
            if vlcActive || vlcRecent {
                if let snap = await fetchVLCSnapshot() {
                    if snap.isPlaying {
                        lastNativeVideoKind = .vlc
                        lastNativeVideoTimestamp = now
                    }
                    return snap
                }
            }
        }

        if isRunning(qtBundle) && !nativeAutomationDenied.contains(qtBundle) {
            let qtActive = isAudioActive(bundlePrefix: qtBundle, in: activeAudioBundles)
            let qtRecent = lastNativeVideoKind == .quickTime && now.timeIntervalSince(lastNativeVideoTimestamp) < 180
            if qtActive || qtRecent {
                if let snap = await fetchQuickTimeSnapshot() {
                    if snap.isPlaying {
                        lastNativeVideoKind = .quickTime
                        lastNativeVideoTimestamp = now
                    }
                    return snap
                }
            }
        }

        if isRunning(tvBundle) && !nativeAutomationDenied.contains(tvBundle) {
            let tvActive = isAudioActive(bundlePrefix: tvBundle, in: activeAudioBundles)
            let tvRecent = lastNativeVideoKind == .appleTV && now.timeIntervalSince(lastNativeVideoTimestamp) < 180
            if tvActive || tvRecent {
                if let snap = await fetchAppleTVSnapshot() {
                    if snap.isPlaying {
                        lastNativeVideoKind = .appleTV
                        lastNativeVideoTimestamp = now
                    }
                    return snap
                }
            }
        }

        return nil
    }

    private func fetchVLCSnapshot() async -> TrackSnapshot? {
        let script = """
        tell application "VLC"
            try
                set isP to playing
                set tName to name of current item
                set tDur to duration of current item
                set tPos to current time
                return (isP as string) & "||~||" & tName & "||~||" & (tDur as string) & "||~||" & (tPos as string)
            on error
                return ""
            end try
        end tell
        """
        let res = await Self.executeAppleScript(script)
        if res.isPermissionDenied {
            nativeAutomationDenied.insert("org.videolan.vlc")
            return nil
        }
        guard res.exitCode == 0 else { return nil }
        let trimmed = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.components(separatedBy: "||~||")
        guard parts.count >= 4 else { return nil }
        let isPlay = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
        let name = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.videolan.vlc")
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        return TrackSnapshot(
            player: .vlc,
            isPlaying: isPlay,
            title: name,
            artist: "VLC",
            album: "",
            duration: max(0, parseLocalizedDouble(parts[2])),
            elapsed: max(0, parseLocalizedDouble(parts[3])),
            artworkURL: nil,
            artworkFilePath: nil,
            artworkImage: icon,
            sourceDisplayName: "VLC",
            sourceBundleIdentifier: "org.videolan.vlc"
        )
    }

    private func fetchQuickTimeSnapshot() async -> TrackSnapshot? {
        let script = """
        tell application "QuickTime Player"
            if (count of documents) is 0 then return ""
            try
                set d to document 1
                set isP to playing of d
                set tName to name of d
                set tDur to duration of d
                set tPos to current time of d
                return (isP as string) & "||~||" & tName & "||~||" & (tDur as string) & "||~||" & (tPos as string)
            on error
                return ""
            end try
        end tell
        """
        let res = await Self.executeAppleScript(script)
        if res.isPermissionDenied {
            nativeAutomationDenied.insert("com.apple.QuickTimePlayerX")
            return nil
        }
        guard res.exitCode == 0 else { return nil }
        let trimmed = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.components(separatedBy: "||~||")
        guard parts.count >= 4 else { return nil }
        let isPlay = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
        let name = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.QuickTimePlayerX")
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        return TrackSnapshot(
            player: .quickTime,
            isPlaying: isPlay,
            title: name,
            artist: "QuickTime Player",
            album: "",
            duration: max(0, parseLocalizedDouble(parts[2])),
            elapsed: max(0, parseLocalizedDouble(parts[3])),
            artworkURL: nil,
            artworkFilePath: nil,
            artworkImage: icon,
            sourceDisplayName: "QuickTime",
            sourceBundleIdentifier: "com.apple.QuickTimePlayerX"
        )
    }

    private func fetchAppleTVSnapshot() async -> TrackSnapshot? {
        let script = """
        tell application "TV"
            set pState to player state as string
            if pState is "stopped" then return ""
            try
                set tName to name of current track
                set tArtist to artist of current track
                set tDur to (duration of current track) as string
                set tPos to (player position) as string
                return pState & "||~||" & tName & "||~||" & tArtist & "||~||" & tDur & "||~||" & tPos
            on error
                return ""
            end try
        end tell
        """
        let res = await Self.executeAppleScript(script)
        if res.isPermissionDenied {
            nativeAutomationDenied.insert("com.apple.TV")
            return nil
        }
        guard res.exitCode == 0 else { return nil }
        let trimmed = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.components(separatedBy: "||~||")
        guard parts.count >= 5 else { return nil }
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TV")
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        return TrackSnapshot(
            player: .appleTV,
            isPlaying: parts[0].lowercased() == "playing",
            title: parts[1],
            artist: parts[2].isEmpty ? "Apple TV" : parts[2],
            album: "",
            duration: max(0, parseLocalizedDouble(parts[3])),
            elapsed: max(0, parseLocalizedDouble(parts[4])),
            artworkURL: nil,
            artworkFilePath: nil,
            artworkImage: icon,
            sourceDisplayName: "Apple TV",
            sourceBundleIdentifier: "com.apple.TV"
        )
    }

    private func fetchOtherAudioAppSnapshot(activeAudioBundles: Set<String>) async -> TrackSnapshot? {
        let selfBundle = Bundle.main.bundleIdentifier?.lowercased() ?? ""
        let ignoredPrefixes = [
            "com.spotify.client",
            "com.apple.music",
            "com.apple.controlcenter",
            "com.apple.systemuiserver",
            "com.apple.notificationcenterui",
            "com.apple.loginwindow",
            "com.apple.windowmanager",
            "com.apple.dock",
            "com.apple.finder",
            "com.apple.siri",
            "com.apple.accessibility",
            "com.apple.speech",
            "com.apple.coreaudio",
            "com.apple.audio"
        ]

        let now = Date()
        for rawBundle in activeAudioBundles.sorted() {
            let lower = rawBundle.lowercased()
            if !selfBundle.isEmpty && lower == selfBundle { continue }
            if ignoredPrefixes.contains(where: { lower.hasPrefix($0) }) { continue }

            guard let app = resolveRunningApp(forAudioBundleID: rawBundle),
                  let appBundle = app.bundleIdentifier else {
                continue
            }

            if !browserAutomationDenied.contains(appBundle),
               Self.supportedBrowsers.contains(where: { $0.bundleID == appBundle }) {
                continue
            }

            lastOtherAppBundleID = appBundle
            lastOtherAppTimestamp = now
            return buildOtherAppSnapshot(for: app, isPlaying: true)
        }

        if let prevBundle = lastOtherAppBundleID,
           now.timeIntervalSince(lastOtherAppTimestamp) < 120,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: prevBundle).first {
            return buildOtherAppSnapshot(for: app, isPlaying: false)
        }

        if now.timeIntervalSince(lastOtherAppTimestamp) >= 120 {
            lastOtherAppBundleID = nil
        }
        return nil
    }

    private func resolveRunningApp(forAudioBundleID audioBundle: String) -> NSRunningApplication? {
        if let direct = NSRunningApplication.runningApplications(withBundleIdentifier: audioBundle).first(where: { $0.activationPolicy == .regular }) {
            return direct
        }

        let lowerAudio = audioBundle.lowercased()
        let regularApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }

        return regularApps.first { app in
            guard let bid = app.bundleIdentifier?.lowercased() else { return false }
            return lowerAudio == bid || lowerAudio.hasPrefix(bid + ".")
        }
    }

    private func buildOtherAppSnapshot(for app: NSRunningApplication, isPlaying: Bool) -> TrackSnapshot {
        let bundleID = app.bundleIdentifier ?? ""
        let lower = bundleID.lowercased()
        let kind: MusicPlayerKind
        if lower == "com.apple.podcasts" {
            kind = .podcasts
        } else if lower == "com.colliderli.iina" {
            kind = .iina
        } else if lower.contains("firefox") || lower.contains("zen") || lower.contains("librewolf") || Self.supportedBrowsers.contains(where: { $0.bundleID == bundleID }) {
            kind = .browser
        } else if lower.contains("tidal") {
            kind = .tidal
        } else if lower.contains("deezer") {
            kind = .deezer
        } else if lower.contains("soundcloud") {
            kind = .soundcloud
        } else {
            kind = .otherApp
        }

        let appName = app.localizedName ?? kind.displayName
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) } ?? app.icon

        return TrackSnapshot(
            player: kind,
            isPlaying: isPlaying,
            title: appName,
            artist: isPlaying ? "Reproduzindo mídia" : "Pausado",
            album: "",
            duration: 0,
            elapsed: 0,
            artworkURL: nil,
            artworkFilePath: nil,
            artworkImage: icon,
            sourceDisplayName: appName,
            sourceBundleIdentifier: bundleID,
            signatureIdentity: "app|\(bundleID)"
        )
    }

    private static func postSystemMediaKey(_ keyType: Int32) {
        for isKeyDown in [true, false] {
            let flags = NSEvent.ModifierFlags(rawValue: isKeyDown ? 0xa00 : 0xb00)
            let data1 = (Int(keyType) << 16) | (isKeyDown ? 0xa00 : 0xb00)
            guard let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )?.cgEvent else {
                continue
            }
            event.post(tap: .cghidEventTap)
        }
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
