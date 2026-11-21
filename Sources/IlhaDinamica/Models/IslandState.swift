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
    case calculator
    case colorPicker
    case stopwatch
    case qrCode
    case launcher
    case network
    case caffeine
    case screenClean
    case batteries
    case ambientSound
    case worldClock

    static let defaultEnabledTabs: [IslandTab] = [
        .music, .pomodoro, .shelf, .clipboard, .calendar, .notes, .audio, .system
    ]

    var isDefaultEnabled: Bool {
        Self.defaultEnabledTabs.contains(self)
    }

    var requiresKeyboardFocus: Bool {
        self == .notes || self == .calculator || self == .qrCode
    }

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
        case .calculator:
            return "Cálculo"
        case .colorPicker:
            return "Cores"
        case .stopwatch:
            return "Timer"
        case .qrCode:
            return "QR Code"
        case .launcher:
            return "Launcher"
        case .network:
            return "Rede"
        case .caffeine:
            return "Cafeína"
        case .screenClean:
            return "Limpeza"
        case .batteries:
            return "Baterias"
        case .ambientSound:
            return "Ambiente"
        case .worldClock:
            return "Relógios"
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
        case .calculator:
            return "function"
        case .colorPicker:
            return "eyedropper.halffull"
        case .stopwatch:
            return "stopwatch.fill"
        case .qrCode:
            return "qrcode"
        case .launcher:
            return "square.grid.3x3.fill"
        case .network:
            return "network"
        case .caffeine:
            return "cup.and.saucer.fill"
        case .screenClean:
            return "sparkles"
        case .batteries:
            return "battery.100.bolt"
        case .ambientSound:
            return "waveform.path"
        case .worldClock:
            return "globe.americas.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .music:
            return "Player, capa do álbum e ondas"
        case .pomodoro:
            return "Timer de foco e ciclos de pausa"
        case .shelf:
            return "Solte arquivos com miniaturas"
        case .clipboard:
            return "Histórico rápido de cópias"
        case .calendar:
            return "Próximos compromissos do dia"
        case .notes:
            return "Checklist e notas instantâneas"
        case .audio:
            return "Volume, brilho e dispositivos"
        case .system:
            return "CPU, memória, bateria e clima"
        case .calculator:
            return "Contas rápidas, porcentagens e conversões"
        case .colorPicker:
            return "Conta-gotas da tela em HEX, RGB e SwiftUI"
        case .stopwatch:
            return "Cronômetro com voltas e alarmes rápidos"
        case .qrCode:
            return "Gera QR Code instantâneo de links e textos"
        case .launcher:
            return "Atalho rápido para apps e pastas favoritos"
        case .network:
            return "Download/upload ao vivo, IP e ping"
        case .caffeine:
            return "Impede o Mac de apagar tela ou hibernar"
        case .screenClean:
            return "Bloqueia teclado por 30s para limpeza"
        case .batteries:
            return "Bateria do Mac, saúde e fones Bluetooth"
        case .ambientSound:
            return "Chuva, ruído marrom e sons de foco"
        case .worldClock:
            return "Fusos horários e diferença entre cidades"
        }
    }

    var category: String {
        switch self {
        case .music:
            return "Mídia"
        case .pomodoro, .clipboard, .calendar, .notes, .launcher:
            return "Produtividade"
        case .shelf:
            return "Arquivos"
        case .audio:
            return "Controles"
        case .system, .network, .caffeine, .screenClean:
            return "Sistema"
        case .calculator, .colorPicker, .stopwatch, .qrCode:
            return "Utilitários"
        case .batteries:
            return "Conectividade"
        case .ambientSound, .worldClock:
            return "Foco"
        }
    }

    var accentColor: Color {
        switch self {
        case .music:
            return Color(red: 0.98, green: 0.34, blue: 0.44)
        case .pomodoro:
            return Color(red: 1.0, green: 0.45, blue: 0.24)
        case .shelf:
            return Color(red: 0.24, green: 0.68, blue: 1.0)
        case .clipboard:
            return Color(red: 0.64, green: 0.44, blue: 1.0)
        case .calendar:
            return Color(red: 1.0, green: 0.30, blue: 0.32)
        case .notes:
            return Color(red: 1.0, green: 0.78, blue: 0.22)
        case .audio:
            return Color(red: 0.20, green: 0.84, blue: 0.60)
        case .system:
            return Color(red: 0.40, green: 0.78, blue: 1.0)
        case .calculator:
            return Color(red: 1.0, green: 0.62, blue: 0.16)
        case .colorPicker:
            return Color(red: 0.95, green: 0.38, blue: 0.78)
        case .stopwatch:
            return Color(red: 1.0, green: 0.56, blue: 0.26)
        case .qrCode:
            return Color(red: 0.38, green: 0.74, blue: 1.0)
        case .launcher:
            return Color(red: 0.36, green: 0.56, blue: 1.0)
        case .network:
            return Color(red: 0.20, green: 0.86, blue: 0.68)
        case .caffeine:
            return Color(red: 0.94, green: 0.68, blue: 0.30)
        case .screenClean:
            return Color(red: 0.45, green: 0.88, blue: 0.98)
        case .batteries:
            return Color(red: 0.28, green: 0.90, blue: 0.52)
        case .ambientSound:
            return Color(red: 0.56, green: 0.50, blue: 1.0)
        case .worldClock:
            return Color(red: 0.26, green: 0.78, blue: 0.96)
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
    case volume(
        level: Float,
        isMuted: Bool,
        deviceName: String = "Alto-falantes",
        deviceIcon: String = "speaker.wave.2.fill"
    )
    case brightness(level: Float)
    case micMuted(isMuted: Bool)
    case bluetoothConnected(
        name: String,
        batteryText: String?,
        isAudio: Bool,
        batteryLeft: String? = nil,
        batteryRight: String? = nil,
        batteryCase: String? = nil,
        batteryMain: String? = nil,
        iconName: String = "airpodspro"
    )
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

    var isInteractiveControlHUD: Bool {
        switch self {
        case .volume, .brightness:
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

enum IslandTabBarPosition: Equatable {
    case top
    case bottom
    case shoulder
}

enum IslandTabPillStyle: Equatable {
    case capsule
    case glass
    case glow
    case iconOnly
    case dock
}

enum PresetPanelTab: String, Equatable {
    case layouts
    case colors
}

enum IslandSurfaceTheme: String, CaseIterable, Identifiable, Equatable {
    case presetDefault
    case oledBlack
    case liquidGlass
    case midnightBlue
    case cosmicPurple
    case emeraldNight
    case crimsonDark
    case titanium
    case roseGold
    case amberNoir

    var id: String { rawValue }

    var title: String {
        switch self {
        case .presetDefault: return "Do Preset"
        case .oledBlack: return "Preto OLED"
        case .liquidGlass: return "Liquid Glass"
        case .midnightBlue: return "Azul Meia-Noite"
        case .cosmicPurple: return "Roxo Cósmico"
        case .emeraldNight: return "Esmeralda"
        case .crimsonDark: return "Carmesim"
        case .titanium: return "Titânio"
        case .roseGold: return "Rosé"
        case .amberNoir: return "Âmbar Noir"
        }
    }

    var usesGlassMaterial: Bool {
        self == .liquidGlass
    }

    var hasLiquidSheen: Bool {
        self == .liquidGlass
    }

    var topColor: Color? {
        switch self {
        case .presetDefault: return nil
        case .oledBlack: return Color.black
        case .liquidGlass: return Color.white.opacity(0.08)
        case .midnightBlue: return Color(red: 0.04, green: 0.08, blue: 0.17)
        case .cosmicPurple: return Color(red: 0.09, green: 0.05, blue: 0.17)
        case .emeraldNight: return Color(red: 0.03, green: 0.11, blue: 0.09)
        case .crimsonDark: return Color(red: 0.14, green: 0.04, blue: 0.06)
        case .titanium: return Color(red: 0.10, green: 0.11, blue: 0.12)
        case .roseGold: return Color(red: 0.14, green: 0.08, blue: 0.10)
        case .amberNoir: return Color(red: 0.11, green: 0.08, blue: 0.04)
        }
    }

    var bottomColor: Color? {
        switch self {
        case .presetDefault: return nil
        case .oledBlack: return Color.black
        case .liquidGlass: return Color.black.opacity(0.28)
        case .midnightBlue: return Color(red: 0.02, green: 0.05, blue: 0.12)
        case .cosmicPurple: return Color(red: 0.05, green: 0.03, blue: 0.11)
        case .emeraldNight: return Color(red: 0.02, green: 0.06, blue: 0.05)
        case .crimsonDark: return Color(red: 0.08, green: 0.02, blue: 0.03)
        case .titanium: return Color(red: 0.06, green: 0.06, blue: 0.07)
        case .roseGold: return Color(red: 0.09, green: 0.05, blue: 0.07)
        case .amberNoir: return Color(red: 0.07, green: 0.05, blue: 0.02)
        }
    }

    var rimColors: [Color]? {
        switch self {
        case .presetDefault: return nil
        case .oledBlack: return [Color.white.opacity(0.14), Color.white.opacity(0.10)]
        case .liquidGlass: return [Color.white.opacity(0.70), Color.white.opacity(0.24), Color.white.opacity(0.52)]
        case .midnightBlue: return [Color(red: 0.34, green: 0.72, blue: 1.0).opacity(0.62), Color(red: 0.22, green: 0.44, blue: 0.90).opacity(0.35)]
        case .cosmicPurple: return [Color(red: 0.72, green: 0.42, blue: 1.0).opacity(0.65), Color(red: 0.36, green: 0.78, blue: 1.0).opacity(0.38)]
        case .emeraldNight: return [Color(red: 0.22, green: 0.92, blue: 0.62).opacity(0.60), Color(red: 0.12, green: 0.56, blue: 0.42).opacity(0.34)]
        case .crimsonDark: return [Color(red: 1.0, green: 0.36, blue: 0.38).opacity(0.62), Color(red: 0.68, green: 0.18, blue: 0.26).opacity(0.34)]
        case .titanium: return [Color.white.opacity(0.36), Color.white.opacity(0.16)]
        case .roseGold: return [Color(red: 0.98, green: 0.68, blue: 0.66).opacity(0.62), Color(red: 0.74, green: 0.44, blue: 0.48).opacity(0.36)]
        case .amberNoir: return [Color(red: 1.0, green: 0.76, blue: 0.30).opacity(0.62), Color(red: 0.72, green: 0.50, blue: 0.18).opacity(0.34)]
        }
    }

    var rimLineWidth: CGFloat? {
        switch self {
        case .presetDefault: return nil
        case .oledBlack: return 0.85
        case .liquidGlass: return 1.25
        default: return 1.1
        }
    }

    var swatchColor: Color {
        switch self {
        case .presetDefault: return Color.white.opacity(0.25)
        case .oledBlack: return Color(red: 0.06, green: 0.06, blue: 0.07)
        case .liquidGlass: return Color(red: 0.54, green: 0.78, blue: 0.96)
        case .midnightBlue: return Color(red: 0.12, green: 0.32, blue: 0.68)
        case .cosmicPurple: return Color(red: 0.42, green: 0.22, blue: 0.72)
        case .emeraldNight: return Color(red: 0.10, green: 0.46, blue: 0.34)
        case .crimsonDark: return Color(red: 0.62, green: 0.14, blue: 0.20)
        case .titanium: return Color(red: 0.36, green: 0.38, blue: 0.42)
        case .roseGold: return Color(red: 0.76, green: 0.46, blue: 0.50)
        case .amberNoir: return Color(red: 0.68, green: 0.46, blue: 0.14)
        }
    }
}

enum IslandElementColor: String, CaseIterable, Identifiable, Equatable {
    case presetDefault
    case white
    case skyBlue
    case cyan
    case emerald
    case amber
    case coral
    case magenta
    case violet
    case lime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .presetDefault: return "Do Preset"
        case .white: return "Branco"
        case .skyBlue: return "Azul"
        case .cyan: return "Ciano"
        case .emerald: return "Esmeralda"
        case .amber: return "Âmbar"
        case .coral: return "Coral"
        case .magenta: return "Magenta"
        case .violet: return "Violeta"
        case .lime: return "Lima"
        }
    }

    var color: Color? {
        switch self {
        case .presetDefault: return nil
        case .white: return Color.white
        case .skyBlue: return Color(red: 0.22, green: 0.60, blue: 1.0)
        case .cyan: return Color(red: 0.24, green: 0.88, blue: 1.0)
        case .emerald: return Color(red: 0.22, green: 0.90, blue: 0.52)
        case .amber: return Color(red: 1.0, green: 0.76, blue: 0.24)
        case .coral: return Color(red: 1.0, green: 0.38, blue: 0.34)
        case .magenta: return Color(red: 0.96, green: 0.34, blue: 0.70)
        case .violet: return Color(red: 0.64, green: 0.42, blue: 1.0)
        case .lime: return Color(red: 0.66, green: 0.96, blue: 0.26)
        }
    }

    var swatchColor: Color {
        color ?? Color.white.opacity(0.28)
    }

    var foregroundOnFill: Color {
        switch self {
        case .white, .cyan, .emerald, .amber, .lime:
            return .black
        case .presetDefault, .skyBlue, .coral, .magenta, .violet:
            return .white
        }
    }
}

enum IslandLayoutPreset: String, CaseIterable, Identifiable, Equatable {
    case obsidian
    case superIsland
    case atoll
    case dynamicLake
    case liquidGlass
    case aurora
    case minimalCompact
    case dashboardDock
    case titaniumGold

    var id: String { rawValue }

    var hasHomeDashboard: Bool {
        self != .obsidian
    }

    var title: String {
        switch self {
        case .obsidian: return "Clássico"
        case .superIsland: return "SuperIsland"
        case .atoll: return "Atoll"
        case .dynamicLake: return "DynamicLake"
        case .liquidGlass: return "Glass Studio"
        case .aurora: return "Aurora Pulse"
        case .minimalCompact: return "Creator Deck"
        case .dashboardDock: return "Central Pro"
        case .titaniumGold: return "Zen Titanium"
        }
    }

    var badge: String {
        switch self {
        case .obsidian: return "1 Painel"
        case .superIsland: return "3 Painéis"
        case .atoll: return "Notch Split"
        case .dynamicLake: return "Liquid Glass"
        case .liquidGlass: return "Vidro + Dias"
        case .aurora: return "Palco Neon"
        case .minimalCompact: return "3 Painéis Pro"
        case .dashboardDock: return "3 Col. + Dock"
        case .titaniumGold: return "Foco + Som"
        }
    }

    var subtitle: String {
        switch self {
        case .obsidian: return "Preto OLED puro mostrando 1 widget por vez"
        case .superIsland: return "Design SuperIsland: abas no topo lateral + Música, Agenda e Clima divididos"
        case .atoll: return "Design Atoll: capa 90px com glow da cor do álbum + agenda com fita de dias"
        case .dynamicLake: return "Design DynamicLake: Liquid Glass translúcido com DynaMusic central e barra DynaGlance"
        case .liquidGlass: return "Mix DynamicLake + Atoll: vidro fosco, capa com glow + fita de 5 dias e agenda"
        case .aurora: return "Palco neon editorial: Música iluminada à esquerda + Relógio grande e Clima à direita"
        case .minimalCompact: return "3 painéis criativos: Radar AirDrop | Sliders Volume & Brilho | Gravar & Cafeína"
        case .dashboardDock: return "3 colunas editoriais (Música | Pomodoro & Tarefas | Mac & AirDrop) + Dock inferior"
        case .titaniumGold: return "Anel Pomodoro e Som Ambiente à esquerda + Fita de 5 dias e Tarefas à direita"
        }
    }

    var expandedWidth: CGFloat {
        switch self {
        case .obsidian: return 556
        case .superIsland: return 644
        case .atoll: return 640
        case .dynamicLake: return 576
        case .liquidGlass: return 626
        case .aurora: return 614
        case .minimalCompact: return 624
        case .dashboardDock: return 636
        case .titaniumGold: return 618
        }
    }

    var expandedBaseHeight: CGFloat {
        switch self {
        case .obsidian: return 246
        case .superIsland: return 238
        case .atoll: return 214
        case .dynamicLake: return 242
        case .liquidGlass: return 236
        case .aurora: return 252
        case .minimalCompact: return 226
        case .dashboardDock: return 278
        case .titaniumGold: return 234
        }
    }

    var compactExtraWidth: CGFloat {
        switch self {
        case .obsidian: return 118
        case .superIsland: return 116
        case .atoll: return 116
        case .dynamicLake: return 118
        case .liquidGlass: return 124
        case .aurora: return 126
        case .minimalCompact: return 110
        case .dashboardDock: return 130
        case .titaniumGold: return 120
        }
    }

    var topEarRadius: CGFloat {
        switch self {
        case .obsidian: return 12
        case .superIsland: return 12
        case .atoll: return 10
        case .dynamicLake: return 18
        case .liquidGlass: return 16
        case .aurora: return 14
        case .minimalCompact: return 12
        case .dashboardDock: return 14
        case .titaniumGold: return 12
        }
    }

    var bottomCornerRadius: CGFloat {
        switch self {
        case .obsidian: return 28
        case .superIsland: return 26
        case .atoll: return 24
        case .dynamicLake: return 34
        case .liquidGlass: return 30
        case .aurora: return 30
        case .minimalCompact: return 26
        case .dashboardDock: return 28
        case .titaniumGold: return 26
        }
    }

    var tabBarPosition: IslandTabBarPosition {
        switch self {
        case .dashboardDock: return .bottom
        case .superIsland, .atoll, .dynamicLake, .liquidGlass, .minimalCompact, .titaniumGold: return .shoulder
        default: return .top
        }
    }

    var tabPillStyle: IslandTabPillStyle {
        switch self {
        case .obsidian: return .capsule
        case .superIsland: return .iconOnly
        case .atoll: return .capsule
        case .dynamicLake: return .glass
        case .liquidGlass: return .glass
        case .aurora: return .glow
        case .minimalCompact: return .iconOnly
        case .dashboardDock: return .dock
        case .titaniumGold: return .capsule
        }
    }

    var usesGlassMaterial: Bool {
        self == .liquidGlass || self == .dynamicLake
    }

    var hasLiquidSheen: Bool {
        self == .dynamicLake || self == .liquidGlass
    }

    var hasAmbientGlow: Bool {
        self == .aurora
    }

    var accentColor: Color {
        switch self {
        case .obsidian: return Color(red: 0.24, green: 0.64, blue: 1.0)
        case .superIsland: return Color.white.opacity(0.92)
        case .atoll: return Color(red: 0.30, green: 0.64, blue: 1.0)
        case .dynamicLake: return Color(red: 0.56, green: 0.86, blue: 1.0)
        case .liquidGlass: return Color(red: 0.48, green: 0.86, blue: 1.0)
        case .aurora: return Color(red: 0.68, green: 0.42, blue: 1.0)
        case .minimalCompact: return Color(red: 0.28, green: 0.88, blue: 0.56)
        case .dashboardDock: return Color(red: 0.24, green: 0.72, blue: 1.0)
        case .titaniumGold: return Color(red: 0.96, green: 0.74, blue: 0.30)
        }
    }

    var surfaceTopColor: Color {
        switch self {
        case .obsidian, .atoll:
            return Color.black
        case .superIsland:
            return Color.black.opacity(0.98)
        case .dynamicLake:
            return Color.white.opacity(0.08)
        case .liquidGlass:
            return Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.62)
        case .aurora:
            return Color(red: 0.04, green: 0.05, blue: 0.11)
        case .minimalCompact:
            return Color(red: 0.03, green: 0.03, blue: 0.04)
        case .dashboardDock:
            return Color(red: 0.05, green: 0.06, blue: 0.09)
        case .titaniumGold:
            return Color(red: 0.07, green: 0.07, blue: 0.08)
        }
    }

    var surfaceBottomColor: Color {
        switch self {
        case .obsidian, .atoll:
            return Color.black
        case .superIsland:
            return Color.black.opacity(0.94)
        case .dynamicLake:
            return Color.black.opacity(0.28)
        case .liquidGlass:
            return Color(red: 0.11, green: 0.14, blue: 0.19).opacity(0.68)
        case .aurora:
            return Color(red: 0.08, green: 0.04, blue: 0.14)
        case .minimalCompact:
            return Color(red: 0.02, green: 0.02, blue: 0.03)
        case .dashboardDock:
            return Color(red: 0.08, green: 0.09, blue: 0.13)
        case .titaniumGold:
            return Color(red: 0.12, green: 0.10, blue: 0.08)
        }
    }

    var rimColors: [Color] {
        switch self {
        case .obsidian:
            return [Color.white.opacity(0.16), Color.white.opacity(0.14)]
        case .superIsland:
            return [Color.white.opacity(0.11), Color.white.opacity(0.07)]
        case .atoll:
            return [Color.white.opacity(0.11), Color.white.opacity(0.08)]
        case .dynamicLake:
            return [Color.white.opacity(0.70), Color.white.opacity(0.24), Color.white.opacity(0.52)]
        case .liquidGlass:
            return [Color.white.opacity(0.45), Color(red: 0.56, green: 0.88, blue: 1.0).opacity(0.28), Color.white.opacity(0.22)]
        case .aurora:
            return [Color(red: 0.18, green: 0.90, blue: 1.0).opacity(0.72), Color(red: 0.62, green: 0.36, blue: 1.0).opacity(0.68), Color(red: 1.0, green: 0.32, blue: 0.68).opacity(0.62)]
        case .minimalCompact:
            return [Color.white.opacity(0.14), Color.white.opacity(0.10)]
        case .dashboardDock:
            return [Color(red: 0.32, green: 0.72, blue: 1.0).opacity(0.38), Color.white.opacity(0.16)]
        case .titaniumGold:
            return [Color(red: 0.96, green: 0.76, blue: 0.36).opacity(0.55), Color(red: 0.72, green: 0.56, blue: 0.28).opacity(0.34)]
        }
    }

    var rimLineWidth: CGFloat {
        switch self {
        case .dynamicLake: return 1.25
        case .aurora, .liquidGlass: return 1.15
        case .titaniumGold, .dashboardDock: return 1.0
        case .superIsland: return 0.9
        case .obsidian, .atoll, .minimalCompact: return 0.85
        }
    }
}
