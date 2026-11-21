import AppKit
@preconcurrency import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Darwin
import Foundation
@preconcurrency import ScreenCaptureKit

@MainActor
final class ScreenRecorderService: ObservableObject {
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var isStopping: Bool = false
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var lastRecordingURL: URL?

    var onRecordingSaved: ((URL) -> Void)?
    var onRecordingError: ((String) -> Void)?

    private let settings: SettingsStore
    private let audio: AudioControlService

    private var activeProcess: Process?
    private var nativeSession: AnyObject?
    private var startDate: Date?
    private var timer: Timer?
    private var stopRequested = false

    init(settings: SettingsStore, audio: AudioControlService) {
        self.settings = settings
        self.audio = audio
    }

    deinit {
        timer?.invalidate()
    }

    var formattedElapsed: String {
        let total = max(0, Int(elapsedSeconds.rounded(.down)))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startFullScreenRecording()
        }
    }

    func startFullScreenRecording() {
        guard !isRecording && !isStopping else { return }

        if !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
            onRecordingError?("Ative a Ilha Dinâmica em Ajustes → Gravação de Tela e reabra o app.")
            return
        }

        if #available(macOS 15.0, *) {
            startNativeScreenCaptureKitRecording()
        } else {
            startLegacyCLIProcessRecording()
        }
    }

    func stopRecording() {
        guard isRecording, !isStopping else { return }

        if #available(macOS 15.0, *), let session = nativeSession as? ScreenCaptureKitSession {
            stopRequested = true
            isStopping = true
            session.stop()
            return
        }

        guard let proc = activeProcess, proc.isRunning else { return }
        stopRequested = true
        isStopping = true

        // SIGINT makes `screencapture -v` flush and finalize the .mov file cleanly
        Darwin.kill(proc.processIdentifier, SIGINT)

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard let self, self.isStopping, let current = self.activeProcess, current.isRunning else { return }
            current.terminate()
        }
    }

    func startAreaSelectionRecording() {
        Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-U", "-J", "video"]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try? process.run()
        }
    }

    // MARK: - macOS 15+ ScreenCaptureKit (System Audio + Video)

    @available(macOS 15.0, *)
    private func startNativeScreenCaptureKitRecording() {
        let outputURL = makeOutputURL(fileExtension: "mp4")
        let includeSystemAudio = settings.recordSystemAudio
        let includeMic = settings.recordIncludeMic && !audio.isMicMuted
        let micUID: String? = (includeMic && audio.isDefaultInputBluetooth)
            ? audio.builtInMicrophoneUID()
            : nil
        let showClicks = settings.recordShowClicks

        let session = ScreenCaptureKitSession(outputURL: outputURL) { [weak self] url, error in
            Task { @MainActor [weak self] in
                self?.handleNativeFinished(outputURL: url, error: error)
            }
        }

        nativeSession = session
        stopRequested = false
        startDate = Date()
        elapsedSeconds = 0
        isRecording = true
        startTimer()

        Task { [weak self] in
            do {
                try await session.start(
                    includeSystemAudio: includeSystemAudio,
                    includeMic: includeMic,
                    micDeviceUID: micUID,
                    showClicks: showClicks
                )
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    if self.stopRequested {
                        session.stop()
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.handleNativeFinished(outputURL: outputURL, error: error)
                }
            }
        }
    }

    private func handleNativeFinished(outputURL: URL, error: Error?) {
        stopTimer()
        nativeSession = nil
        startDate = nil
        isRecording = false
        isStopping = false

        let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = (attrs?[.size] as? NSNumber)?.int64Value ?? 0

        if fileSize > 0 {
            lastRecordingURL = outputURL
            onRecordingSaved?(outputURL)
        } else {
            try? FileManager.default.removeItem(at: outputURL)
            if let error {
                onRecordingError?("Não foi possível gravar a tela (\(error.localizedDescription)).")
            } else if !stopRequested {
                onRecordingError?("Verifique a permissão de Gravação de Tela e Áudio do Sistema.")
            }
        }
        stopRequested = false
    }

    // MARK: - macOS 14 Legacy Fallback

    private func startLegacyCLIProcessRecording() {
        let outputURL = makeOutputURL(fileExtension: "mov")
        var args = ["-v", "-C"]
        if settings.recordIncludeMic && !audio.isMicMuted {
            if audio.isDefaultInputBluetooth, let builtInUID = audio.builtInMicrophoneUID() {
                args.append(contentsOf: ["-G", builtInUID])
            } else {
                args.append("-g")
            }
        }
        if settings.recordShowClicks {
            args.append("-k")
        }
        args.append(outputURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = args
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        stopRequested = false

        process.terminationHandler = { [weak self] finishedProc in
            let exitStatus = finishedProc.terminationStatus
            Task { @MainActor [weak self] in
                self?.handleProcessFinished(outputURL: outputURL, status: exitStatus)
            }
        }

        do {
            try process.run()
        } catch {
            onRecordingError?("Não foi possível iniciar a gravação (\(error.localizedDescription)).")
            return
        }

        activeProcess = process
        startDate = Date()
        elapsedSeconds = 0
        isRecording = true
        startTimer()
    }

    private func handleProcessFinished(outputURL: URL, status: Int32) {
        stopTimer()
        activeProcess = nil
        startDate = nil
        isRecording = false
        isStopping = false

        let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = (attrs?[.size] as? NSNumber)?.int64Value ?? 0

        if fileSize > 0 {
            lastRecordingURL = outputURL
            onRecordingSaved?(outputURL)
        } else {
            try? FileManager.default.removeItem(at: outputURL)
            if !stopRequested || status != 0 {
                onRecordingError?("Verifique a permissão de Gravação de Tela em Ajustes do Sistema.")
            }
        }
        stopRequested = false
    }

    private func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.startDate else { return }
                self.elapsedSeconds = Date().timeIntervalSince(start)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func makeOutputURL(fileExtension: String) -> URL {
        let fm = FileManager.default
        let desktop = fm.urls(for: .desktopDirectory, in: .userDomainMask).first
        let movies = fm.urls(for: .moviesDirectory, in: .userDomainMask).first
        let folder: URL
        if let desktop, fm.isWritableFile(atPath: desktop.path) {
            folder = desktop
        } else if let movies {
            folder = movies
        } else {
            folder = fm.temporaryDirectory
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "Gravacao_\(formatter.string(from: Date())).\(fileExtension)"
        return folder.appendingPathComponent(filename)
    }
}

@available(macOS 15.0, *)
private final class ScreenCaptureKitSession: NSObject, SCStreamDelegate, SCRecordingOutputDelegate, @unchecked Sendable {
    private let outputURL: URL
    private let onFinished: @Sendable (URL, Error?) -> Void
    private let lock = NSLock()

    private var stream: SCStream?
    private var recordingOutput: SCRecordingOutput?
    private var stopRequested = false
    private var didComplete = false

    init(outputURL: URL, onFinished: @escaping @Sendable (URL, Error?) -> Void) {
        self.outputURL = outputURL
        self.onFinished = onFinished
    }

    func start(
        includeSystemAudio: Bool,
        includeMic: Bool,
        micDeviceUID: String?,
        showClicks: Bool
    ) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let mainDisplayID = CGMainDisplayID()
        guard let display = content.displays.first(where: { $0.displayID == mainDisplayID }) ?? content.displays.first else {
            throw NSError(
                domain: "IlhaDinamica.ScreenRecorder",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Nenhuma tela encontrada para gravação."]
            )
        }

        let scale = await MainActor.run {
            NSScreen.screens.first {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID
            }?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        }

        let rawW = max(2, Int((CGFloat(display.width) * scale).rounded()))
        let rawH = max(2, Int((CGFloat(display.height) * scale).rounded()))

        let config = SCStreamConfiguration()
        config.width = rawW - (rawW % 2)
        config.height = rawH - (rawH % 2)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.showMouseClicks = showClicks
        config.captureDynamicRange = .SDR

        config.capturesAudio = includeSystemAudio
        config.sampleRate = 48_000
        config.channelCount = 2
        config.excludesCurrentProcessAudio = true

        config.captureMicrophone = includeMic
        if includeMic, let micDeviceUID {
            config.microphoneCaptureDeviceID = micDeviceUID
        }

        let recConfig = SCRecordingOutputConfiguration()
        recConfig.outputURL = outputURL
        if recConfig.availableOutputFileTypes.contains(.mp4) {
            recConfig.outputFileType = .mp4
        } else if let firstType = recConfig.availableOutputFileTypes.first {
            recConfig.outputFileType = firstType
        }
        if recConfig.availableVideoCodecTypes.contains(.h264) {
            recConfig.videoCodecType = .h264
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let recOutput = SCRecordingOutput(configuration: recConfig, delegate: self)
        let scStream = SCStream(filter: filter, configuration: config, delegate: self)

        guard attachIfActive(stream: scStream, output: recOutput) else {
            completeOnce(error: nil)
            return
        }

        try scStream.addRecordingOutput(recOutput)
        try await scStream.startCapture()

        if shouldStopAfterStart() {
            stop()
        }
    }

    private func attachIfActive(stream scStream: SCStream, output recOutput: SCRecordingOutput) -> Bool {
        lock.withLock {
            let alreadyStopped = stopRequested || didComplete
            if !alreadyStopped {
                self.recordingOutput = recOutput
                self.stream = scStream
            }
            return !alreadyStopped
        }
    }

    private func shouldStopAfterStart() -> Bool {
        lock.withLock {
            stopRequested && !didComplete
        }
    }

    func stop() {
        let activeStream: SCStream? = lock.withLock {
            stopRequested = true
            guard !didComplete else { return nil }
            return stream
        }

        guard let activeStream else { return }

        Task.detached(priority: .userInitiated) { [weak self] in
            try? await activeStream.stopCapture()

            // Safety fallback in case SCRecordingOutputDelegate does not fire after stopCapture()
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            self?.completeOnce(error: nil)
        }
    }

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        completeOnce(error: nil)
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        completeOnce(error: error)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        // Give SCRecordingOutputDelegate a moment to deliver finish callback if triggered first
        Task.detached(priority: .userInitiated) { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            self?.completeOnce(error: error)
        }
    }

    private func completeOnce(error: Error?) {
        lock.lock()
        if didComplete {
            lock.unlock()
            return
        }
        didComplete = true
        stream = nil
        recordingOutput = nil
        lock.unlock()

        onFinished(outputURL, error)
    }
}
