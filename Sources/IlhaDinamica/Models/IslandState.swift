import Foundation
import SwiftUI

enum PomodoroPhase: String, CaseIterable, Identifiable, Equatable {
    case focus
    case shortBreak
    case longBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus:
            return "Foco"
        case .shortBreak:
            return "Pausa"
        case .longBreak:
            return "Pausa Longa"
        }
    }

    var shortTitle: String {
        switch self {
        case .focus:
            return "Foco"
        case .shortBreak:
            return "Pausa"
        case .longBreak:
            return "Longa"
        }
    }

    var iconName: String {
        switch self {
        case .focus:
            return "flame.fill"
        case .shortBreak:
            return "cup.and.saucer.fill"
        case .longBreak:
            return "leaf.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .focus:
            return Color(red: 1.0, green: 0.37, blue: 0.27)
        case .shortBreak:
            return Color(red: 0.24, green: 0.84, blue: 0.58)
        case .longBreak:
            return Color(red: 0.32, green: 0.72, blue: 1.0)
        }
    }
}

enum IslandTab: String, CaseIterable, Identifiable, Equatable {
    case music
    case pomodoro
    case shelf
    case clipboard
    case calendar
    case notes
    case audio
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .music:
            return "Música"
        case .pomodoro:
            return "Pomodoro"
        case .shelf:
            return "Bandeja"
        case .clipboard:
            return "Clipboard"
        case .calendar:
            return "Agenda"
        case .notes:
            return "Notas"
        case .audio:
            return "Áudio"
        case .system:
            return "Mac"
        }
    }

    var iconName: String {
        switch self {
        case .music:
            return "music.note"
        case .pomodoro:
            return "timer"
        case .shelf:
            return "tray.and.arrow.down.fill"
        case .clipboard:
            return "doc.on.clipboard.fill"
        case .calendar:
            return "calendar"
        case .notes:
            return "checklist"
        case .audio:
            return "speaker.wave.2.fill"
        case .system:
            return "cpu"
        }
    }
}

enum ToastKind: Equatable {
    case charging(percent: Int, watts: Int?)
    case unplugged(percent: Int)
    case lowBattery(percent: Int)
    case fullBattery
    case pomodoroFinished(completed: PomodoroPhase, next: PomodoroPhase)
    case trackChanged(title: String, artist: String, accent: Color)
    case volume(level: Float, isMuted: Bool)
    case brightness(level: Float)
    case micMuted(isMuted: Bool)
    case bluetoothConnected(name: String, batteryText: String?, isAudio: Bool)
    case meetingSoon(title: String, minutesUntil: Int)
    case shelfAdded(count: Int)
    case recordingSaved(filename: String)
    case recordingError(message: String)

    var isQuickHUD: Bool {
        switch self {
        case .volume, .brightness, .micMuted:
            return true
        default:
            return false
        }
    }
}

struct ToastEvent: Equatable, Identifiable {
    let id: UUID
    let kind: ToastKind

    init(id: UUID = UUID(), kind: ToastKind) {
        self.id = id
        self.kind = kind
    }
}

enum IslandMode: Equatable {
    case idle
    case compact
    case toast(ToastEvent)
    case expanded
}
