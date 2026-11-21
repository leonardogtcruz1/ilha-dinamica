import SwiftUI

struct IslandRootView: View {
    @ObservedObject var coordinator: IslandCoordinator
    @ObservedObject var settings: SettingsStore
    @ObservedObject var music: MusicService
    @ObservedObject var pomodoro: PomodoroService
    @ObservedObject var battery: BatteryService
    @ObservedObject var shelf: ShelfService
    @ObservedObject var clipboard: ClipboardService
    @ObservedObject var calendar: CalendarService
    @ObservedObject var notes: NotesService
    @ObservedObject var audio: AudioControlService
    @ObservedObject var camera: CameraMirrorService
    @ObservedObject var system: SystemMonitorService
    @ObservedObject var weather: WeatherService
    @ObservedObject var recorder: ScreenRecorderService

    private var islandShape: NotchIslandShape {
        NotchIslandShape(
            hasNotch: coordinator.geometry.hasNotch,
            topEarRadius: topEarRadius,
            bottomCornerRadius: bottomCornerRadius
        )
    }

    private var topEarRadius: CGFloat {
        switch coordinator.mode {
        case .idle:
            return 0
        case .compact:
            return 8
        case .toast:
            return 10
        case .expanded:
            return 12
        }
    }

    private var bottomCornerRadius: CGFloat {
        switch coordinator.mode {
        case .idle:
            return 10
        case .compact:
            return 16
        case .toast:
            return 22
        case .expanded:
            return 28
        }
    }

    private var rimOpacity: Double {
        if shelf.isDropTargeted {
            return 0.48
        }
        switch coordinator.mode {
        case .idle:
            return coordinator.geometry.hasNotch ? 0 : 0.14
        case .compact:
            return coordinator.geometry.hasNotch ? 0.08 : 0.11
        case .toast:
            return 0.15
        case .expanded:
            return 0.16
        }
    }

    private var rimColor: Color {
        shelf.isDropTargeted
            ? Color(red: 0.36, green: 0.76, blue: 1.0)
            : Color.white.opacity(rimOpacity)
    }

    private var shadowRadius: CGFloat {
        switch coordinator.mode {
        case .idle:
            return coordinator.geometry.hasNotch ? 0 : 8
        case .compact:
            return coordinator.geometry.hasNotch ? 0 : 12
        case .toast:
            return 18
        case .expanded:
            return 24
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if coordinator.geometry.topInset > 0 {
                Spacer()
                    .frame(height: coordinator.geometry.topInset)
            }

            ZStack {
                islandShape
                    .fill(Color.black)

                contentView
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
            .frame(
                width: coordinator.currentSize.width,
                height: coordinator.currentSize.height
            )
            .clipShape(islandShape)
            .overlay(
                islandShape
                    .stroke(rimColor, lineWidth: shelf.isDropTargeted ? 1.4 : 0.85)
            )
            .shadow(
                color: Color.black.opacity(shadowRadius > 0 ? 0.55 : 0),
                radius: shadowRadius,
                x: 0,
                y: 8
            )
            .contentShape(islandShape)
            .onTapGesture {
                if coordinator.mode != .expanded {
                    coordinator.expand()
                }
            }

            Spacer(minLength: 0)
        }
        .frame(
            width: IslandPanel.canvasSize.width,
            height: IslandPanel.canvasSize.height,
            alignment: .top
        )
        .animation(settings.expandSpring, value: coordinator.mode)
        .animation(settings.sizeSpring, value: coordinator.currentSize)
    }

    @ViewBuilder
    private var contentView: some View {
        switch coordinator.mode {
        case .idle:
            Color.clear

        case .compact:
            CompactIslandView(
                coordinator: coordinator,
                settings: settings,
                music: music,
                pomodoro: pomodoro,
                battery: battery,
                audio: audio,
                recorder: recorder
            )

        case .toast(let event):
            ToastIslandView(
                event: event,
                geometry: coordinator.geometry,
                music: music
            )

        case .expanded:
            ExpandedIslandView(
                coordinator: coordinator,
                settings: settings,
                music: music,
                pomodoro: pomodoro,
                battery: battery,
                shelf: shelf,
                clipboard: clipboard,
                calendar: calendar,
                notes: notes,
                audio: audio,
                camera: camera,
                system: system,
                weather: weather,
                recorder: recorder
            )
        }
    }
}
