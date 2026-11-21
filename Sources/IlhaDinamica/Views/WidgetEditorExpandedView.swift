import SwiftUI

struct WidgetEditorExpandedView: View {
    @ObservedObject var coordinator: IslandCoordinator
    @ObservedObject var settings: SettingsStore

    private let trayCardWidth: CGFloat = 62
    private let trayCardSpacing: CGFloat = 7
    private var traySlotStride: CGFloat { trayCardWidth + trayCardSpacing }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            editorHeader

            activeStripSection

            gallerySection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var editorHeader: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.24, green: 0.56, blue: 1.0),
                                Color(red: 0.42, green: 0.34, blue: 0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(.white)
                    )

                Text("Biblioteca de Widgets")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(.white)

                Text("\(settings.enabledTabs.count) de \(IslandTab.allCases.count) ativos • Arraste para ordenar")
                    .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.68))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.09), in: Capsule())
            }

            Spacer()

            HStack(spacing: 6) {
                if !settings.disabledTabs.isEmpty {
                    Button {
                        withAnimation(settings.sizeSpring) {
                            settings.enableAllWidgets()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.square.on.square")
                                .font(.system(size: 9.5, weight: .bold))
                            Text("Ativar todos")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .foregroundStyle(Color.white.opacity(0.90))
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Color(red: 0.19, green: 0.80, blue: 0.44).opacity(0.26), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Adicionar todos os widgets da biblioteca na Ilha")
                }

                if !settings.isDefaultWidgetLayout {
                    Button {
                        withAnimation(settings.sizeSpring) {
                            settings.resetWidgetsToDefault()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 9.5, weight: .bold))
                            Text("Restaurar padrão")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .foregroundStyle(Color.white.opacity(0.86))
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Color.white.opacity(0.11), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Restaurar widgets e ordem padrão")
                }

                Button {
                    coordinator.toggleWidgetEditor()
                } label: {
                    Text("OK")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 24)
                        .background(Color(red: 0.04, green: 0.52, blue: 1.0), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var activeStripSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("NA ILHA — ARRASTE OS WIDGETS PARA MUDAR A ORDEM")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.55)
                .foregroundStyle(Color.white.opacity(0.48))

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let activeTabs = settings.enabledTabs

                let trayContent = HStack(spacing: trayCardSpacing) {
                    ForEach(Array(activeTabs.enumerated()), id: \.element.id) { index, tab in
                        let isDragging = coordinator.draggingWidgetTab == tab
                        let angle = isDragging ? 0.0 : sin(t * 22.0 + Double(index) * 1.5) * 1.3
                        activeStripCard(
                            tab: tab,
                            index: index,
                            totalCount: activeTabs.count,
                            jiggleDegrees: angle,
                            isDragging: isDragging
                        )
                        .zIndex(isDragging ? 10 : 0)
                    }
                }
                .coordinateSpace(name: "EditorActiveTray")
                .padding(.vertical, 8)
                .padding(.horizontal, 8)

                if activeTabs.count > 8 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        trayContent
                    }
                } else {
                    trayContent
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(height: 84)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 0.75)
            )
        }
    }

    private func activeStripCard(
        tab: IslandTab,
        index: Int,
        totalCount: Int,
        jiggleDegrees: Double,
        isDragging: Bool
    ) -> some View {
        let canRemove = totalCount > 1
        let isCurrent = coordinator.activeTab == tab
        let dragOffset = coordinator.dragOffset(for: tab, slotStride: traySlotStride)

        return ZStack(alignment: .topLeading) {
            VStack(spacing: 3) {
                HStack {
                    Spacer(minLength: 14)
                    Text("#\(index + 1)")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.50))
                }
                .padding(.top, 4)
                .padding(.horizontal, 5)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tab.accentColor, tab.accentColor.opacity(0.68)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: tab.iconName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )

                Text(tab.title)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 3)

                Capsule()
                    .fill(Color.white.opacity(isDragging ? 0.55 : 0.24))
                    .frame(width: 18, height: 2.5)
                    .padding(.bottom, 4)
            }
            .frame(width: trayCardWidth, height: 68)
            .background(
                isDragging
                    ? Color.white.opacity(0.20)
                    : (isCurrent ? Color.white.opacity(0.13) : Color.white.opacity(0.08)),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isDragging
                            ? tab.accentColor
                            : (isCurrent ? tab.accentColor.opacity(0.70) : Color.white.opacity(0.13)),
                        lineWidth: isDragging ? 1.25 : 0.75
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture {
                withAnimation(settings.sizeSpring) {
                    coordinator.activeTab = tab
                }
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named("EditorActiveTray"))
                    .onChanged { value in
                        coordinator.updateWidgetDrag(
                            tab: tab,
                            translation: value.translation,
                            slotStride: traySlotStride
                        )
                    }
                    .onEnded { _ in
                        coordinator.endWidgetDrag()
                    }
            )

            Button {
                withAnimation(settings.sizeSpring) {
                    settings.setTabEnabled(tab, enabled: false)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 13.5, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color(red: 1.0, green: 0.28, blue: 0.26))
                    .opacity(canRemove ? 1.0 : 0.32)
            }
            .buttonStyle(.plain)
            .disabled(!canRemove)
            .offset(x: -4, y: -4)
            .help(canRemove ? "Remover \(tab.title) da Ilha" : "Pelo menos 1 widget precisa ficar ativo")
        }
        .scaleEffect(isDragging ? 1.08 : 1.0)
        .shadow(color: Color.black.opacity(isDragging ? 0.45 : 0.0), radius: 8, y: 4)
        .rotationEffect(.degrees(jiggleDegrees))
        .offset(dragOffset)
    }

    private var gallerySection: some View {
        let availableTabs = IslandTab.allCases.filter { !settings.isTabEnabled($0) }
        let enabledTabs = settings.enabledTabs

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 9) {
                if !availableTabs.isEmpty {
                    Text("DISPONÍVEIS PARA ADICIONAR (\(availableTabs.count))")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.55)
                        .foregroundStyle(Color(red: 0.28, green: 0.88, blue: 0.54))

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ],
                        spacing: 8
                    ) {
                        ForEach(availableTabs) { tab in
                            galleryCard(for: tab)
                        }
                    }
                }

                Text("ATIVOS NA ILHA (\(enabledTabs.count))")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.55)
                    .foregroundStyle(Color.white.opacity(0.48))
                    .padding(.top, availableTabs.isEmpty ? 0 : 2)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 8
                ) {
                    ForEach(enabledTabs) { tab in
                        galleryCard(for: tab)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: .infinity)
    }

    private func galleryCard(for tab: IslandTab) -> some View {
        let isEnabled = settings.isTabEnabled(tab)
        let activeTabs = settings.enabledTabs
        let activeIndex = activeTabs.firstIndex(of: tab)
        let canRemove = activeTabs.count > 1

        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tab.accentColor, tab.accentColor.opacity(0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: tab.iconName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2.5) {
                HStack(spacing: 5) {
                    Text(tab.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(tab.category)
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.60))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .lineLimit(1)
                }

                Text(tab.subtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.64))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            if isEnabled {
                VStack(alignment: .trailing, spacing: 4) {
                    if let activeIndex {
                        Text("#\(activeIndex + 1)")
                            .font(.system(size: 9, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(tab.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(tab.accentColor.opacity(0.16), in: Capsule())
                    }

                    Button {
                        withAnimation(settings.sizeSpring) {
                            settings.setTabEnabled(tab, enabled: false)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Remover")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                        .foregroundStyle(canRemove ? .white : Color.white.opacity(0.45))
                        .padding(.horizontal, 7)
                        .frame(height: 21)
                        .background(
                            canRemove ? Color(red: 1.0, green: 0.28, blue: 0.26).opacity(0.85) : Color.white.opacity(0.08),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canRemove)
                    .help(canRemove ? "Remover \(tab.title) da Ilha" : "Pelo menos 1 widget precisa ficar ativo")
                }
            } else {
                Button {
                    withAnimation(settings.sizeSpring) {
                        settings.setTabEnabled(tab, enabled: true)
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 10.5, weight: .bold))
                        Text("Adicionar")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Color(red: 0.19, green: 0.80, blue: 0.44), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Adicionar \(tab.title) na Ilha")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            isEnabled ? Color.white.opacity(0.085) : Color.white.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(
                    isEnabled ? tab.accentColor.opacity(0.35) : Color.white.opacity(0.10),
                    lineWidth: 0.8
                )
        )
    }
}
