import SwiftUI

struct LayoutPresetsExpandedView: View {
    @ObservedObject var coordinator: IslandCoordinator
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            presetsHeader

            if coordinator.presetPanelTab == .layouts {
                layoutsGridView
            } else {
                colorsCustomizationView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var layoutsGridView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 9
            ) {
                ForEach(IslandLayoutPreset.allCases) { preset in
                    presetCard(for: preset)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: .infinity)
    }

    private var colorsCustomizationView: some View {
        let previewBtn = settings.resolvedButtonColor(fallback: settings.layoutPreset.accentColor)
        let previewBtnFg = settings.buttonAccentColor == .presetDefault ? Color.white : settings.buttonAccentColor.foregroundOnFill
        let previewSlider = settings.resolvedSliderColor(fallback: settings.layoutPreset.accentColor)

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                surfaceThemePickerRow

                elementColorPickerRow(
                    title: "COR DOS BOTÕES & ABAS",
                    selection: settings.buttonAccentColor
                ) { chosen in
                    withAnimation(settings.sizeSpring) {
                        settings.buttonAccentColor = chosen
                    }
                }

                elementColorPickerRow(
                    title: "COR DOS SLIDERS & BARRAS",
                    selection: settings.sliderAccentColor
                ) { chosen in
                    withAnimation(settings.sizeSpring) {
                        settings.sliderAccentColor = chosen
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("PRÉVIA AO VIVO")
                        .font(.system(size: 8.5, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.white.opacity(0.48))

                    HStack(spacing: 12) {
                        HStack(spacing: 5) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9.5, weight: .bold))
                            Text("Botão Ativo")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundStyle(previewBtnFg)
                        .padding(.horizontal, 11)
                        .frame(height: 24)
                        .background(previewBtn, in: Capsule())

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Slider & Progresso")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.78))
                                Spacer()
                                Text("68%")
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(previewSlider)
                            }
                            GeometryReader { geo in
                                let w = max(1, geo.size.width)
                                ZStack(alignment: .leading) {
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.16))
                                    Capsule(style: .continuous)
                                        .fill(previewSlider)
                                        .frame(width: w * 0.68)
                                }
                            }
                            .frame(height: 5.5)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [
                                settings.effectiveUsesGlassMaterial ? Color(red: 0.20, green: 0.28, blue: 0.38).opacity(0.75) : settings.effectiveSurfaceTopColor,
                                settings.effectiveUsesGlassMaterial ? Color(red: 0.14, green: 0.20, blue: 0.28).opacity(0.85) : settings.effectiveSurfaceBottomColor
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: settings.effectiveRimColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: settings.effectiveRimLineWidth
                            )
                    )
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: .infinity)
    }

    private var surfaceThemePickerRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("COR DA ILHA (FUNDO E BORDA)")
                    .font(.system(size: 8.5, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.white.opacity(0.52))
                Spacer()
                Text(settings.islandSurfaceTheme.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.82))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(IslandSurfaceTheme.allCases) { theme in
                        let selected = settings.islandSurfaceTheme == theme
                        Button {
                            withAnimation(settings.sizeSpring) {
                                settings.islandSurfaceTheme = theme
                            }
                        } label: {
                            VStack(spacing: 3.5) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            theme == .presetDefault
                                                ? AnyShapeStyle(
                                                    AngularGradient(
                                                        colors: [.cyan, .purple, .pink, .orange, .cyan],
                                                        center: .center
                                                    )
                                                )
                                                : AnyShapeStyle(theme.swatchColor)
                                        )
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    selected ? Color.white : Color.white.opacity(0.22),
                                                    lineWidth: selected ? 2.0 : 0.8
                                                )
                                        )

                                    if selected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9.5, weight: .bold))
                                            .foregroundStyle(theme == .liquidGlass ? .black : .white)
                                    }
                                }

                                Text(theme.title)
                                    .font(.system(size: 9, weight: selected ? .bold : .medium))
                                    .foregroundStyle(selected ? .white : Color.white.opacity(0.56))
                                    .lineLimit(1)
                            }
                            .frame(minWidth: 46)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func elementColorPickerRow(
        title: String,
        selection: IslandElementColor,
        onSelect: @escaping (IslandElementColor) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 8.5, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.white.opacity(0.52))
                Spacer()
                Text(selection.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(selection.color ?? Color.white.opacity(0.82))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(IslandElementColor.allCases) { item in
                        let selected = selection == item
                        Button {
                            onSelect(item)
                        } label: {
                            VStack(spacing: 3.5) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            item == .presetDefault
                                                ? AnyShapeStyle(
                                                    AngularGradient(
                                                        colors: [.blue, .green, .yellow, .pink, .blue],
                                                        center: .center
                                                    )
                                                )
                                                : AnyShapeStyle(item.swatchColor)
                                        )
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    selected ? Color.white : Color.white.opacity(0.20),
                                                    lineWidth: selected ? 2.0 : 0.8
                                                )
                                        )

                                    if selected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9.5, weight: .bold))
                                            .foregroundStyle(item == .presetDefault ? .white : item.foregroundOnFill)
                                    }
                                }

                                Text(item.title)
                                    .font(.system(size: 9, weight: selected ? .bold : .medium))
                                    .foregroundStyle(selected ? .white : Color.white.opacity(0.56))
                                    .lineLimit(1)
                            }
                            .frame(minWidth: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var presetsHeader: some View {
        let activeTint = settings.resolvedButtonColor(fallback: settings.layoutPreset.accentColor)
        let activeFg = settings.buttonAccentColor == .presetDefault ? Color.white : settings.buttonAccentColor.foregroundOnFill

        return HStack(spacing: 8) {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                activeTint,
                                Color(red: 0.62, green: 0.36, blue: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(.white)
                    )

                Text("Estilos")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 3) {
                tabSwitchPill("Layouts", icon: "rectangle.3.group.fill", tab: .layouts, tint: activeTint, tintFg: activeFg)
                tabSwitchPill("Cores", icon: "eyedropper.halffull", tab: .colors, tint: activeTint, tintFg: activeFg)
            }
            .padding(2.5)
            .background(Color.white.opacity(0.08), in: Capsule())

            Spacer()

            if coordinator.presetPanelTab == .layouts && settings.layoutPreset != .obsidian {
                Button {
                    withAnimation(settings.sizeSpring) {
                        settings.layoutPreset = .obsidian
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("Padrão")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundStyle(Color.white.opacity(0.86))
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Color.white.opacity(0.11), in: Capsule())
                }
                .buttonStyle(.plain)
            } else if coordinator.presetPanelTab == .colors && settings.hasCustomColors {
                Button {
                    withAnimation(settings.sizeSpring) {
                        settings.resetCustomColors()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("Resetar cores")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundStyle(Color.white.opacity(0.86))
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Color.white.opacity(0.11), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                coordinator.togglePresets()
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

    private func tabSwitchPill(
        _ title: String,
        icon: String,
        tab: PresetPanelTab,
        tint: Color,
        tintFg: Color
    ) -> some View {
        let selected = coordinator.presetPanelTab == tab
        return Button {
            withAnimation(settings.sizeSpring) {
                coordinator.presetPanelTab = tab
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 10.5, weight: .bold))
            }
            .foregroundStyle(selected ? tintFg : Color.white.opacity(0.68))
            .padding(.horizontal, 10)
            .frame(height: 20)
            .background(selected ? tint : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func presetCard(for preset: IslandLayoutPreset) -> some View {
        let isSelected = settings.layoutPreset == preset
        let highlight = isSelected
            ? settings.resolvedButtonColor(fallback: preset.accentColor)
            : preset.accentColor

        return Button {
            withAnimation(settings.sizeSpring) {
                settings.layoutPreset = preset
                coordinator.isShowingPresetHome = preset.hasHomeDashboard
            }
        } label: {
            HStack(spacing: 10) {
                miniIslandPreview(for: preset)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(preset.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(preset.badge)
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(highlight)
                            .padding(.horizontal, 5.5)
                            .padding(.vertical, 1.5)
                            .background(highlight.opacity(0.16), in: Capsule())
                            .lineLimit(1)
                    }

                    Text(preset.subtitle)
                        .font(.system(size: 9.8))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? highlight : Color.white.opacity(0.28))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? highlight.opacity(0.12) : Color.white.opacity(0.055),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        isSelected ? highlight.opacity(0.85) : Color.white.opacity(0.10),
                        lineWidth: isSelected ? 1.2 : 0.8
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func miniIslandPreview(for preset: IslandLayoutPreset) -> some View {
        let customSurface = settings.islandSurfaceTheme != .presetDefault
        let previewUseGlass = customSurface ? settings.effectiveUsesGlassMaterial : preset.usesGlassMaterial
        let previewTop = customSurface ? settings.effectiveSurfaceTopColor : preset.surfaceTopColor
        let previewBottom = customSurface ? settings.effectiveSurfaceBottomColor : preset.surfaceBottomColor
        let previewRim = customSurface ? settings.effectiveRimColors : preset.rimColors
        let activeBtn = settings.resolvedButtonColor(fallback: preset == .atoll ? preset.accentColor : Color.white.opacity(0.85))

        return ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: (preset == .dynamicLake && !customSurface) || (customSurface && settings.islandSurfaceTheme == .liquidGlass) ? [
                            Color(red: 0.36, green: 0.56, blue: 0.74).opacity(0.72),
                            Color(red: 0.22, green: 0.34, blue: 0.48).opacity(0.82)
                        ] : [
                            previewUseGlass ? Color(red: 0.19, green: 0.24, blue: 0.32) : previewTop,
                            previewUseGlass ? Color(red: 0.14, green: 0.19, blue: 0.27) : previewBottom
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            if preset.hasAmbientGlow {
                RadialGradient(
                    colors: [
                        preset.accentColor.opacity(0.32),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 2,
                    endRadius: 46
                )
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }

            VStack(spacing: 4) {
                if preset.tabBarPosition == .shoulder {
                    HStack(spacing: 3) {
                        Capsule()
                            .fill(activeBtn)
                            .frame(width: 7, height: 3.5)
                        Capsule()
                            .fill(Color.white.opacity(preset == .atoll ? 0.22 : 0.30))
                            .frame(width: 6, height: 3.5)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.black)
                            .frame(width: 18, height: 4)
                        Capsule()
                            .fill(Color.white.opacity(0.30))
                            .frame(width: 6, height: 3.5)
                        Circle()
                            .fill(Color.white.opacity(0.38))
                            .frame(width: 3.5, height: 3.5)
                    }
                    miniContentBlocks(for: preset)
                } else {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.black)
                        .frame(width: 18, height: 4)

                    if preset.tabBarPosition == .top {
                        miniTabDots(for: preset)
                        miniContentBlocks(for: preset)
                    } else {
                        miniContentBlocks(for: preset)
                        miniTabDots(for: preset)
                    }
                }
            }
            .padding(5)
        }
        .frame(width: 78, height: 50)
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: previewRim,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
    }

    private func miniTabDots(for preset: IslandLayoutPreset) -> some View {
        let dotAccent = settings.resolvedButtonColor(fallback: preset.accentColor)
        return HStack(spacing: 3) {
            Capsule()
                .fill(dotAccent)
                .frame(width: preset.tabPillStyle == .iconOnly ? 8 : 16, height: 4)
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 8, height: 4)
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 8, height: 4)
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 8, height: 4)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, preset.tabPillStyle == .dock ? 2.5 : 0)
        .background(
            preset.tabPillStyle == .dock ? Color.white.opacity(0.10) : Color.clear,
            in: Capsule()
        )
    }

    private func miniContentBlocks(for preset: IslandLayoutPreset) -> some View {
        let accent = settings.resolvedSliderColor(fallback: preset.accentColor)
        let btnTint = settings.resolvedButtonColor(fallback: preset.accentColor)

        return Group {
            switch preset {
            case .obsidian:
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(accent.opacity(0.45))
                        .frame(width: 14, height: 14)
                    VStack(alignment: .leading, spacing: 2.5) {
                        Capsule()
                            .fill(Color.white.opacity(0.65))
                            .frame(width: 34, height: 3.5)
                        Capsule()
                            .fill(accent.opacity(0.65))
                            .frame(width: 24, height: 3)
                    }
                    Spacer(minLength: 0)
                }

            case .superIsland:
                HStack(spacing: 3) {
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(Color.white.opacity(0.22))
                            .frame(width: 11, height: 11)
                        Capsule()
                            .fill(accent.opacity(0.75))
                            .frame(width: 18, height: 2)
                    }
                    Rectangle().fill(Color.white.opacity(0.14)).frame(width: 0.7, height: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Capsule().fill(Color.white.opacity(0.75)).frame(width: 14, height: 3)
                        Capsule().fill(Color.white.opacity(0.32)).frame(width: 16, height: 2)
                        Capsule().fill(Color.white.opacity(0.24)).frame(width: 13, height: 2)
                    }
                    Rectangle().fill(Color.white.opacity(0.14)).frame(width: 0.7, height: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 2) {
                            Circle().fill(Color.orange.opacity(0.85)).frame(width: 4, height: 4)
                            Capsule().fill(Color.white.opacity(0.75)).frame(width: 10, height: 3)
                        }
                        Capsule().fill(Color.cyan.opacity(0.65)).frame(width: 12, height: 2)
                    }
                }

            case .atoll:
                HStack(spacing: 4) {
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(accent.opacity(0.72))
                            .frame(width: 13, height: 13)
                            .background(
                                RadialGradient(
                                    colors: [accent.opacity(0.55), .clear],
                                    center: .center,
                                    startRadius: 1,
                                    endRadius: 11
                                )
                            )
                        VStack(alignment: .leading, spacing: 2.5) {
                            Capsule()
                                .fill(Color.white.opacity(0.78))
                                .frame(width: 18, height: 2.5)
                            Capsule()
                                .fill(accent.opacity(0.85))
                                .frame(width: 15, height: 2.5)
                            Capsule()
                                .fill(Color.white.opacity(0.32))
                                .frame(width: 13, height: 2)
                        }
                    }

                    Spacer(minLength: 1)

                    VStack(alignment: .leading, spacing: 2.5) {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(btnTint)
                                .frame(width: 5, height: 5)
                            Circle()
                                .fill(Color.white.opacity(0.28))
                                .frame(width: 4, height: 4)
                            Circle()
                                .fill(Color.white.opacity(0.22))
                                .frame(width: 4, height: 4)
                        }
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 0.8)
                                .fill(Color(red: 1.0, green: 0.38, blue: 0.36))
                                .frame(width: 1.5, height: 4)
                            Capsule()
                                .fill(Color.white.opacity(0.62))
                                .frame(width: 16, height: 2)
                        }
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 0.8)
                                .fill(accent)
                                .frame(width: 1.5, height: 4)
                            Capsule()
                                .fill(Color.white.opacity(0.45))
                                .frame(width: 14, height: 2)
                        }
                    }
                }

            case .dynamicLake:
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(Color.white.opacity(0.32))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Capsule()
                                .fill(Color.white.opacity(0.88))
                                .frame(width: 24, height: 2.5)
                            Capsule()
                                .fill(Color.white.opacity(0.55))
                                .frame(width: 18, height: 2)
                        }
                        Spacer(minLength: 1)
                        HStack(spacing: 1) {
                            Capsule().fill(accent).frame(width: 1.5, height: 5)
                            Capsule().fill(accent).frame(width: 1.5, height: 8)
                            Capsule().fill(accent).frame(width: 1.5, height: 4)
                        }
                    }

                    Capsule()
                        .fill(accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 2)

                    HStack(spacing: 4) {
                        Spacer(minLength: 0)
                        Circle().fill(Color.white.opacity(0.70)).frame(width: 3, height: 3)
                        Circle().fill(btnTint).frame(width: 4, height: 4)
                        Circle().fill(Color.white.opacity(0.70)).frame(width: 3, height: 3)
                        Spacer(minLength: 0)
                        Capsule()
                            .fill(btnTint.opacity(0.80))
                            .frame(width: 14, height: 2.5)
                    }
                }

            case .liquidGlass:
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 2.5) {
                        HStack(spacing: 2.5) {
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(accent.opacity(0.65))
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 1.5) {
                                Capsule().fill(Color.white.opacity(0.8)).frame(width: 14, height: 2)
                                Capsule().fill(Color.white.opacity(0.4)).frame(width: 10, height: 1.8)
                            }
                        }
                        Capsule().fill(accent).frame(width: 26, height: 2.5)
                    }
                    Rectangle().fill(Color.white.opacity(0.18)).frame(width: 0.7, height: 18)
                    VStack(alignment: .leading, spacing: 2.5) {
                        HStack(spacing: 2) {
                            Circle().fill(btnTint).frame(width: 4.5, height: 4.5)
                            Circle().fill(Color.white.opacity(0.28)).frame(width: 3.5, height: 3.5)
                            Circle().fill(Color.white.opacity(0.22)).frame(width: 3.5, height: 3.5)
                        }
                        Capsule().fill(Color.white.opacity(0.60)).frame(width: 22, height: 2)
                        Capsule().fill(Color.white.opacity(0.35)).frame(width: 18, height: 2)
                    }
                }

            case .aurora:
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 2.5) {
                        HStack(spacing: 2.5) {
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(accent.opacity(0.78))
                                .frame(width: 10, height: 10)
                            Capsule().fill(Color.white.opacity(0.7)).frame(width: 14, height: 2.5)
                        }
                        Capsule().fill(accent).frame(width: 24, height: 2.5)
                    }
                    Rectangle().fill(accent.opacity(0.40)).frame(width: 0.8, height: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 2.5) {
                            Capsule().fill(Color.white.opacity(0.88)).frame(width: 14, height: 4)
                            Circle().fill(Color(red: 1.0, green: 0.80, blue: 0.28)).frame(width: 5, height: 5)
                        }
                        Capsule().fill(btnTint.opacity(0.65)).frame(width: 22, height: 2)
                    }
                }

            case .minimalCompact:
                HStack(spacing: 3) {
                    VStack(spacing: 2) {
                        Circle()
                            .fill(btnTint.opacity(0.85))
                            .frame(width: 9, height: 9)
                        Capsule().fill(Color.white.opacity(0.4)).frame(width: 16, height: 2)
                    }
                    Rectangle().fill(Color.white.opacity(0.14)).frame(width: 0.7, height: 18)
                    VStack(spacing: 3) {
                        Capsule().fill(accent).frame(width: 22, height: 3)
                        Capsule().fill(accent.opacity(0.72)).frame(width: 22, height: 3)
                    }
                    Rectangle().fill(Color.white.opacity(0.14)).frame(width: 0.7, height: 18)
                    VStack(spacing: 2.5) {
                        Circle().fill(Color(red: 1.0, green: 0.30, blue: 0.28)).frame(width: 6, height: 6)
                        Capsule().fill(btnTint).frame(width: 12, height: 3)
                    }
                }

            case .dashboardDock:
                HStack(spacing: 3) {
                    VStack(alignment: .leading, spacing: 2.5) {
                        RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.55)).frame(width: 9, height: 9)
                        Capsule().fill(accent).frame(width: 16, height: 2)
                    }
                    Rectangle().fill(Color.white.opacity(0.14)).frame(width: 0.7, height: 16)
                    VStack(spacing: 2) {
                        Circle().stroke(accent, lineWidth: 1.5).frame(width: 8, height: 8)
                        Capsule().fill(Color.white.opacity(0.5)).frame(width: 14, height: 2)
                    }
                    Rectangle().fill(Color.white.opacity(0.14)).frame(width: 0.7, height: 16)
                    VStack(spacing: 2.5) {
                        Capsule().fill(accent).frame(width: 14, height: 2.5)
                        Capsule().fill(btnTint).frame(width: 14, height: 3.5)
                    }
                }

            case .titaniumGold:
                HStack(spacing: 4) {
                    VStack(spacing: 2.5) {
                        Circle()
                            .stroke(accent, lineWidth: 1.8)
                            .frame(width: 11, height: 11)
                        HStack(spacing: 2) {
                            Capsule().fill(btnTint).frame(width: 10, height: 3)
                            Capsule().fill(Color.white.opacity(0.35)).frame(width: 8, height: 3)
                        }
                    }
                    Rectangle().fill(accent.opacity(0.32)).frame(width: 0.8, height: 18)
                    VStack(alignment: .leading, spacing: 2.5) {
                        HStack(spacing: 2) {
                            Circle().fill(btnTint).frame(width: 4.5, height: 4.5)
                            Circle().fill(Color.white.opacity(0.28)).frame(width: 3.5, height: 3.5)
                            Circle().fill(Color.white.opacity(0.22)).frame(width: 3.5, height: 3.5)
                        }
                        Capsule().fill(Color.white.opacity(0.65)).frame(width: 24, height: 2)
                        Capsule().fill(Color.white.opacity(0.45)).frame(width: 20, height: 2)
                    }
                }
            }
        }
    }
}
