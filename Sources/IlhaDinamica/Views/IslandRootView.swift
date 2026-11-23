import AppKit
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
    @ObservedObject var calls: CallMonitorService
    @ObservedObject var extraWidgets: ExtraWidgetsService

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
            if coordinator.isEditingWidgets || coordinator.isPresetsOpen {
                return 12
            }
            return settings.layoutPreset.topEarRadius
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
            if coordinator.isEditingWidgets || coordinator.isPresetsOpen {
                return 28
            }
            return settings.layoutPreset.bottomCornerRadius
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

    @ViewBuilder
    private var islandBackground: some View {
        let preset = settings.layoutPreset
        if coordinator.mode == .idle && coordinator.geometry.hasNotch {
            Color.black
        } else {
            ZStack {
                if settings.effectiveUsesGlassMaterial {
                    IslandGlassBackdrop()
                    LinearGradient(
                        colors: [
                            settings.effectiveSurfaceTopColor,
                            settings.effectiveSurfaceBottomColor
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    if settings.effectiveHasLiquidSheen {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.04),
                                Color.clear,
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                } else {
                    LinearGradient(
                        colors: [
                            settings.effectiveSurfaceTopColor,
                            settings.effectiveSurfaceBottomColor
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

                if preset.hasAmbientGlow {
                    RadialGradient(
                        colors: [
                            Color(red: 0.18, green: 0.88, blue: 1.0).opacity(0.16),
                            Color(red: 0.56, green: 0.34, blue: 1.0).opacity(0.10),
                            Color.clear
                        ],
                        center: .top,
                        startRadius: 10,
                        endRadius: 300
                    )
                }
            }
        }
    }

    private var rimStrokeStyle: AnyShapeStyle {
        if shelf.isDropTargeted {
            return AnyShapeStyle(Color(red: 0.36, green: 0.76, blue: 1.0))
        }
        if coordinator.mode == .idle {
            return AnyShapeStyle(rimColor)
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: settings.effectiveRimColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var activeRimLineWidth: CGFloat {
        if shelf.isDropTargeted { return 1.4 }
        if coordinator.mode == .idle { return 0.85 }
        return settings.effectiveRimLineWidth
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
                    .fill(Color.clear)
                    .background(islandBackground)
                    .clipShape(islandShape)

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
                    .stroke(rimStrokeStyle, lineWidth: activeRimLineWidth)
            )
            .shadow(
                color: Color.black.opacity(shadowRadius > 0 ? 0.55 : 0),
                radius: shadowRadius,
                x: 0,
                y: 8
            )
            .contentShape(islandShape)
            .onTapGesture {
                if case .toast(let event) = coordinator.mode, event.kind.blocksTapToExpand {
                    return
                }
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
        .animation(settings.sizeSpring, value: settings.layoutPreset)
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
                recorder: recorder,
                calls: calls
            )

        case .toast(let event):
            ToastIslandView(
                event: event,
                geometry: coordinator.geometry,
                music: music,
                battery: battery,
                audio: audio,
                calls: calls,
                coordinator: coordinator,
                settings: settings
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
                recorder: recorder,
                calls: calls,
                extraWidgets: extraWidgets
            )
        }
    }
}

private struct IslandGlassBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .hudWindow
        nsView.blendingMode = .behindWindow
        nsView.state = .active
        nsView.appearance = NSAppearance(named: .darkAqua)
    }
}
