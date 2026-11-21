import AppKit
import Combine
import Foundation

@MainActor
final class PomodoroService: ObservableObject {
    private enum Keys {
        static let statsDate = "pomodoro.statsDate"
        static let completedToday = "pomodoro.completedToday"
        static let focusedMinutesToday = "pomodoro.focusedMinutesToday"
    }

    @Published private(set) var phase: PomodoroPhase = .focus
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var remainingSeconds: TimeInterval = 25 * 60
    @Published private(set) var totalSeconds: TimeInterval = 25 * 60
    @Published private(set) var completedSessionsInCycle: Int = 0
    @Published private(set) var completedToday: Int = 0
    @Published private(set) var focusedMinutesToday: Int = 0

    var onPhaseCompleted: ((PomodoroPhase, PomodoroPhase) -> Void)?

    private let settings: SettingsStore
    private let defaults: UserDefaults
    private var endDate: Date?
    private var tickTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var hasStartedCurrentSession = false

    init(settings: SettingsStore, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.defaults = defaults

        let initialDuration = TimeInterval(settings.focusMinutes * 60)
        self.remainingSeconds = initialDuration
        self.totalSeconds = initialDuration

        loadTodayStats()
        observeSettings()
    }

    deinit {
        tickTimer?.invalidate()
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        let elapsed = totalSeconds - remainingSeconds
        return max(0, min(1, elapsed / totalSeconds))
    }

    var formattedRemaining: String {
        let total = max(0, Int(ceil(remainingSeconds)))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func start() {
        guard !isRunning else { return }
        if remainingSeconds <= 0 {
            let dur = duration(for: phase)
            remainingSeconds = dur
            totalSeconds = dur
        }
        hasStartedCurrentSession = true
        endDate = Date().addingTimeInterval(remainingSeconds)
        isRunning = true
        startTimer()
    }

    func pause() {
        guard isRunning else { return }
        if let endDate {
            remainingSeconds = max(0, endDate.timeIntervalSinceNow)
        }
        self.endDate = nil
        isRunning = false
        stopTimer()
    }

    func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    func reset() {
        pause()
        hasStartedCurrentSession = false
        let dur = duration(for: phase)
        totalSeconds = dur
        remainingSeconds = dur
    }

    func skip() {
        pause()
        hasStartedCurrentSession = false
        let completed = phase
        let next = nextPhase(after: completed, recordCompletion: false)
        applyPhase(next)
    }

    func selectPhase(_ newPhase: PomodoroPhase) {
        pause()
        hasStartedCurrentSession = false
        applyPhase(newPhase)
    }

    func addOneMinute() {
        remainingSeconds += 60
        totalSeconds = max(totalSeconds + 60, remainingSeconds)
        if isRunning {
            endDate = Date().addingTimeInterval(remainingSeconds)
        }
    }

    private func observeSettings() {
        Publishers.CombineLatest3(
            settings.$focusMinutes,
            settings.$shortBreakMinutes,
            settings.$longBreakMinutes
        )
        .dropFirst()
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            guard let self else { return }
            if !self.isRunning && !self.hasStartedCurrentSession {
                let dur = self.duration(for: self.phase)
                self.totalSeconds = dur
                self.remainingSeconds = dur
            }
        }
        .store(in: &cancellables)
    }

    private func duration(for phase: PomodoroPhase) -> TimeInterval {
        switch phase {
        case .focus:
            return TimeInterval(settings.focusMinutes * 60)
        case .shortBreak:
            return TimeInterval(settings.shortBreakMinutes * 60)
        case .longBreak:
            return TimeInterval(settings.longBreakMinutes * 60)
        }
    }

    private func applyPhase(_ newPhase: PomodoroPhase) {
        phase = newPhase
        let dur = duration(for: newPhase)
        totalSeconds = dur
        remainingSeconds = dur
    }

    private func startTimer() {
        stopTimer()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func stopTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func handleTick() {
        guard isRunning, let endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left <= 0 {
            completeCurrentPhase()
        } else {
            remainingSeconds = left
        }
    }

    private func completeCurrentPhase() {
        pause()
        hasStartedCurrentSession = false
        remainingSeconds = 0

        playCompletionSound()

        let completed = phase
        if completed == .focus {
            loadTodayStats()
            completedToday += 1
            let minutes = max(1, Int((totalSeconds / 60.0).rounded()))
            focusedMinutesToday += minutes
            saveTodayStats()
        }

        let next = nextPhase(after: completed, recordCompletion: true)
        applyPhase(next)
        onPhaseCompleted?(completed, next)

        if settings.pomodoroAutoStart {
            start()
        }
    }

    private func nextPhase(after current: PomodoroPhase, recordCompletion: Bool) -> PomodoroPhase {
        switch current {
        case .focus:
            if recordCompletion {
                completedSessionsInCycle += 1
            } else {
                completedSessionsInCycle = (completedSessionsInCycle + 1) % 4
            }

            if completedSessionsInCycle >= 4 {
                completedSessionsInCycle = 0
                return .longBreak
            }
            return .shortBreak

        case .shortBreak, .longBreak:
            return .focus
        }
    }

    private func playCompletionSound() {
        let name = settings.pomodoroSound
        guard name != "Nenhum" else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func loadTodayStats() {
        let today = todayKey()
        if defaults.string(forKey: Keys.statsDate) == today {
            completedToday = defaults.integer(forKey: Keys.completedToday)
            focusedMinutesToday = defaults.integer(forKey: Keys.focusedMinutesToday)
        } else {
            defaults.set(today, forKey: Keys.statsDate)
            defaults.set(0, forKey: Keys.completedToday)
            defaults.set(0, forKey: Keys.focusedMinutesToday)
            completedToday = 0
            focusedMinutesToday = 0
        }
    }

    private func saveTodayStats() {
        defaults.set(todayKey(), forKey: Keys.statsDate)
        defaults.set(completedToday, forKey: Keys.completedToday)
        defaults.set(focusedMinutesToday, forKey: Keys.focusedMinutesToday)
    }
}
