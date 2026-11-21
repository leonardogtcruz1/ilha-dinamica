import AppKit
import SwiftUI

struct ToastIslandView: View {
    let event: ToastEvent
    let geometry: NotchGeometry
    @ObservedObject var music: MusicService
    @ObservedObject var battery: BatteryService
    @ObservedObject var audio: AudioControlService
    @ObservedObject var coordinator: IslandCoordinator
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            if geometry.hasNotch {
                Spacer()
                    .frame(height: geometry.notchHeight - 2)
            }

            if case .volume = event.kind {
                volumeHudRow()
            } else if case .brightness = event.kind {
                brightnessHudRow()
            } else if case .charging(let percent, let watts) = event.kind {
                chargingConnectedCard(
                    fallbackPercent: percent,
                    fallbackWatts: watts
                )
            } else if case .bluetoothConnected(
                let name,
                let batteryText,
                let isAudio,
                let batteryLeft,
                let batteryRight,
                let batteryCase,
                let batteryMain,
                let iconName
            ) = event.kind {
                headphoneConnectedCard(
                    name: name,
                    batteryText: batteryText,
                    isAudio: isAudio,
                    batteryLeft: batteryLeft,
                    batteryRight: batteryRight,
                    batteryCase: batteryCase,
                    batteryMain: batteryMain,
                    iconName: iconName
                )
            } else {
                standardBannerRow
            }
        }
        .onDisappear {
            if !audio.isDraggingVolume {
                audio.isHoveringVolume = false
            }
            if !audio.isDraggingBrightness {
                audio.isHoveringBrightness = false
            }
        }
    }

    private func volumeHudRow() -> some View {
        let isMuted = audio.isMuted
        let level = audio.volume
        let deviceName = audio.defaultOutputName
        let deviceIcon = audio.defaultOutputIconName
        let tint: Color = isMuted
            ? .red
            : settings.resolvedSliderColor(fallback: Color(red: 0.28, green: 0.88, blue: 0.54))
        let displayValue: Float = isMuted ? 0 : level
        let badgeIcon = isMuted ? "speaker.slash.fill" : deviceIcon
        let canOpenAudioTab = settings.enabledTabs.contains(.audio)

        return HStack(spacing: 12) {
            Button {
                audio.toggleMute()
            } label: {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.20))
                        .frame(width: 34, height: 34)
                    Image(systemName: badgeIcon)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }
            .buttonStyle(.plain)
            .help(isMuted ? "Ativar som" : "Silenciar")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(isMuted ? "Sem som" : "Volume")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.white)

                    if canOpenAudioTab {
                        Button {
                            coordinator.expand(tab: .audio)
                        } label: {
                            devicePillLabel(deviceIcon: deviceIcon, deviceName: deviceName, tint: tint)
                        }
                        .buttonStyle(.plain)
                        .help("Abrir aba de Áudio e Brilho")
                    } else {
                        devicePillLabel(deviceIcon: deviceIcon, deviceName: deviceName, tint: tint)
                    }

                    Spacer(minLength: 4)

                    Text(isMuted ? "Mudo" : "\(Int((displayValue * 100).rounded()))%")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(tint)

                    if canOpenAudioTab {
                        openAudioTabButton
                    }
                }

                interactiveHudSlider(
                    value: displayValue,
                    tint: tint,
                    isDragging: audio.isDraggingVolume,
                    isHovering: audio.isHoveringVolume,
                    overscroll: audio.volumeOverscroll,
                    onHoverChange: { audio.isHoveringVolume = $0 },
                    onDragChange: { rawRatio, locX in
                        audio.updateVolumeDrag(rawRatio: rawRatio, locationX: locX)
                    },
                    onDragEnd: { rawRatio in
                        audio.endVolumeDrag(rawRatio: rawRatio)
                    }
                )
            }
        }
        .padding(.horizontal, geometry.hasNotch ? 22 : 18)
        .frame(maxHeight: .infinity)
        .textSelection(.disabled)
    }

    private func chargingConnectedCard(
        fallbackPercent: Int,
        fallbackWatts: Int?
    ) -> some View {
        let chargeGreen = Color(red: 0.24, green: 0.92, blue: 0.54)
        let brightGreen = Color(red: 0.36, green: 0.98, blue: 0.62)
        let deepGreen = Color(red: 0.16, green: 0.84, blue: 0.46)
        let amberAccent = Color(red: 1.0, green: 0.78, blue: 0.24)
        let cyanAccent = Color(red: 0.34, green: 0.76, blue: 1.0)

        let effectivePercent = battery.isPluggedIn ? battery.percentage : fallbackPercent
        let effectiveAdapterWatts = battery.adapterWatts ?? fallbackWatts
        let isFastCharging = (effectiveAdapterWatts ?? 0) >= 60 || (battery.batteryChargeWatts ?? 0) >= 35

        let statusEyebrow: String = {
            if battery.isFullyCharged {
                return "CARGA COMPLETA"
            }
            if isFastCharging {
                return "CARGA RÁPIDA"
            }
            if battery.isCharging {
                return "CARREGANDO MAC"
            }
            return "CONECTADO À TOMADA"
        }()

        let adapterTitle: String = {
            if let name = battery.adapterName, !name.isEmpty {
                return name
            }
            if let watts = effectiveAdapterWatts {
                return "Carregador USB-C \(watts)W"
            }
            return "Carregador conectado"
        }()

        let powerValueText: String = {
            if let sysW = battery.systemPowerInWatts {
                return String(format: "%.1fW", sysW)
            }
            if let chgW = battery.batteryChargeWatts {
                return String(format: "%.1fW", chgW)
            }
            if let watts = effectiveAdapterWatts {
                return "\(watts)W"
            }
            return "Ativo"
        }()

        let powerDetailText: String = {
            if let watts = effectiveAdapterWatts, let volts = battery.adapterVoltageVolts {
                return "Fonte \(watts)W • \(Int(volts.rounded()))V"
            }
            if let chgW = battery.batteryChargeWatts {
                return String(format: "+%.1fW bat.", chgW)
            }
            if let watts = effectiveAdapterWatts {
                return "Fonte \(watts)W"
            }
            return "Negociando PD"
        }()

        let etaValueText: String = {
            if battery.isFullyCharged || effectivePercent >= 100 {
                return "100%"
            }
            if let mins = battery.timeRemainingMinutes, mins > 0 {
                if mins >= 60 {
                    return "\(mins / 60)h \(mins % 60)m"
                }
                return "\(mins) min"
            }
            return "Calculando..."
        }()

        let etaDetailText: String = {
            if battery.isFullyCharged || effectivePercent >= 100 {
                return "Carga cheia"
            }
            if !battery.isCharging && battery.isPluggedIn {
                return "Pausado / Otimizada"
            }
            return "Tempo estimado"
        }()

        let batteryValueText: String = {
            if let health = battery.healthPercent {
                return "\(health)% saúde"
            }
            if let temp = battery.temperatureCelsius {
                return String(format: "%.1f°C", temp)
            }
            return "Normal"
        }()

        let batteryDetailText: String = {
            if let temp = battery.temperatureCelsius, let cycles = battery.cycleCount {
                return String(format: "%.1f°C • %dc", temp, cycles)
            }
            if let temp = battery.temperatureCelsius {
                return String(format: "%.1f°C", temp)
            }
            if let cycles = battery.cycleCount {
                return "\(cycles) ciclos"
            }
            return "Temperatura OK"
        }()

        return VStack(spacing: 8) {
            HStack(spacing: 12) {
                TimelineView(.animation(minimumInterval: 0.08)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let wave = (sin(t * 3.8) + 1.0) * 0.5
                    let glowScale = 0.96 + 0.08 * wave
                    let innerOpacity = 0.24 + 0.16 * wave

                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        chargeGreen.opacity(innerOpacity),
                                        chargeGreen.opacity(0.06)
                                    ],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 24
                                )
                            )
                            .frame(width: 42, height: 42)
                            .scaleEffect(glowScale)
                            .overlay(
                                Circle()
                                    .stroke(chargeGreen.opacity(0.48), lineWidth: 0.9)
                            )

                        Image(systemName: "bolt.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(chargeGreen)
                    }
                }

                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(chargeGreen)
                            .frame(width: 6, height: 6)
                        Text(statusEyebrow)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(chargeGreen)
                            .lineLimit(1)
                    }

                    Text(adapterTitle)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Text("\(effectivePercent)%")
                    .font(.system(size: 21, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color(red: 0.26, green: 0.94, blue: 0.56))
            }

            GeometryReader { geo in
                let w = max(1, geo.size.width)
                let fraction = max(0.03, min(1.0, Double(effectivePercent) / 100.0))
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.14))
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [deepGreen, brightGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: w * CGFloat(fraction))
                }
            }
            .frame(height: 6)

            HStack(spacing: 8) {
                chargingTelemetryTile(
                    label: "POTÊNCIA",
                    value: powerValueText,
                    detail: powerDetailText,
                    tint: chargeGreen
                )
                chargingTelemetryTile(
                    label: "ATÉ 100%",
                    value: etaValueText,
                    detail: etaDetailText,
                    tint: cyanAccent
                )
                chargingTelemetryTile(
                    label: "BATERIA",
                    value: batteryValueText,
                    detail: batteryDetailText,
                    tint: amberAccent
                )
            }
        }
        .padding(.horizontal, geometry.hasNotch ? 22 : 18)
        .padding(.bottom, 10)
        .frame(maxHeight: .infinity)
    }

    private func chargingTelemetryTile(
        label: String,
        value: String,
        detail: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8.5, weight: .bold))
                .tracking(0.35)
                .foregroundStyle(Color.white.opacity(0.50))
                .lineLimit(1)

            Text(value)
                .font(.system(size: 12.5, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)

            Text(detail)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.68))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func headphoneConnectedCard(
        name: String,
        batteryText: String?,
        isAudio: Bool,
        batteryLeft: String?,
        batteryRight: String?,
        batteryCase: String?,
        batteryMain: String?,
        iconName: String
    ) -> some View {
        let btAccent = Color(red: 0.34, green: 0.72, blue: 1.0)
        let greenAccent = Color(red: 0.24, green: 0.90, blue: 0.54)
        let hasSplitBatteries = batteryLeft != nil || batteryRight != nil || batteryCase != nil

        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [btAccent.opacity(0.32), btAccent.opacity(0.08)],
                                center: .center,
                                startRadius: 2,
                                endRadius: 24
                            )
                        )
                        .frame(width: 42, height: 42)
                        .overlay(
                            Circle()
                                .stroke(btAccent.opacity(0.45), lineWidth: 0.9)
                        )

                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(greenAccent)
                            .frame(width: 6, height: 6)
                        Text(isAudio ? "SAÍDA DE ÁUDIO CONECTADA" : "BLUETOOTH CONECTADO")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(greenAccent)
                    }

                    Text(name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                HStack(spacing: 6) {
                    if isAudio {
                        AudioVisualizerView(
                            isPlaying: true,
                            accentColor: btAccent,
                            barCount: 3,
                            barWidth: 2.2,
                            maxHeight: 13,
                            spacing: 2
                        )
                    }

                    Text("Ativo")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(greenAccent)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(greenAccent.opacity(0.14), in: Capsule())
            }

            if hasSplitBatteries {
                HStack(spacing: 8) {
                    batteryTile(label: "FONE ESQ.", valueText: batteryLeft)
                    batteryTile(label: "FONE DIR.", valueText: batteryRight)
                    batteryTile(label: "ESTOJO", valueText: batteryCase)
                }
            } else if let batteryMain {
                HStack(spacing: 8) {
                    batteryTile(label: "BATERIA", valueText: batteryMain)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("ROTA DE ÁUDIO")
                            .font(.system(size: 8.5, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(Color.white.opacity(0.48))
                        HStack(spacing: 5) {
                            Image(systemName: iconName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(btAccent)
                            Text("Selecionado como principal")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(btAccent)

                    Text(batteryText ?? (isAudio ? "Áudio roteado para este dispositivo" : "Conectado e pronto para uso"))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.86))
                        .lineLimit(1)

                    Spacer()

                    Text("Conectado")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(btAccent)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
        }
        .padding(.horizontal, geometry.hasNotch ? 22 : 18)
        .padding(.bottom, 12)
        .frame(maxHeight: .infinity)
    }

    private func batteryTile(label: String, valueText: String?) -> some View {
        let fraction = Self.parsePercentFraction(valueText)
        let tint: Color = {
            guard let fraction else { return Color.white.opacity(0.42) }
            if fraction <= 0.18 { return Color(red: 1.0, green: 0.42, blue: 0.22) }
            if fraction <= 0.35 { return Color(red: 1.0, green: 0.78, blue: 0.24) }
            return Color(red: 0.24, green: 0.90, blue: 0.54)
        }()

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 8.5, weight: .bold))
                    .tracking(0.35)
                    .foregroundStyle(Color.white.opacity(0.50))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(valueText ?? "—")
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(valueText == nil ? Color.white.opacity(0.45) : .white)
            }

            GeometryReader { geo in
                let w = max(1, geo.size.width)
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.14))
                    if let fraction {
                        Capsule(style: .continuous)
                            .fill(tint)
                            .frame(width: w * CGFloat(max(0.06, min(1.0, fraction))))
                    }
                }
            }
            .frame(height: 4.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private static func parsePercentFraction(_ raw: String?) -> Double? {
        guard let raw else { return nil }
        let digits = raw.filter(\.isNumber)
        guard let num = Double(digits) else { return nil }
        return max(0, min(1, num / 100.0))
    }

    private var standardBannerRow: some View {
        HStack(spacing: 12) {
            iconBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitleText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            trailingView
        }
        .padding(.horizontal, geometry.hasNotch ? 24 : 18)
        .frame(maxHeight: .infinity)
    }

    private func brightnessHudRow() -> some View {
        let tint = settings.resolvedSliderColor(fallback: Color(red: 1.0, green: 0.78, blue: 0.24))
        let value = audio.brightness
        let canOpenAudioTab = settings.enabledTabs.contains(.audio)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.20))
                    .frame(width: 34, height: 34)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(tint)
                    .rotationEffect(.degrees(Double(value) * 180.0))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Brilho")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer(minLength: 4)

                    Text("\(Int((value * 100).rounded()))%")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(tint)

                    if canOpenAudioTab {
                        openAudioTabButton
                    }
                }

                interactiveHudSlider(
                    value: value,
                    tint: tint,
                    isDragging: audio.isDraggingBrightness,
                    isHovering: audio.isHoveringBrightness,
                    overscroll: audio.brightnessOverscroll,
                    onHoverChange: { audio.isHoveringBrightness = $0 },
                    onDragChange: { rawRatio, locX in
                        audio.updateBrightnessDrag(rawRatio: rawRatio, locationX: locX)
                    },
                    onDragEnd: { rawRatio in
                        audio.endBrightnessDrag(rawRatio: rawRatio)
                    }
                )
            }
        }
        .padding(.horizontal, geometry.hasNotch ? 22 : 18)
        .frame(maxHeight: .infinity)
        .textSelection(.disabled)
    }

    private var openAudioTabButton: some View {
        Button {
            coordinator.expand(tab: .audio)
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.84))
                .frame(width: 22, height: 22)
                .background(Color.white.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .help("Abrir aba de Áudio e Brilho")
    }

    private func devicePillLabel(deviceIcon: String, deviceName: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: deviceIcon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(tint)
            Text(deviceName)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.88))
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(Color.white.opacity(0.11), in: Capsule())
    }

    private func interactiveHudSlider(
        value: Float,
        tint: Color,
        isDragging: Bool,
        isHovering: Bool,
        overscroll: CGFloat,
        onHoverChange: @escaping (Bool) -> Void,
        onDragChange: @escaping (Float, CGFloat) -> Void,
        onDragEnd: @escaping (Float) -> Void
    ) -> some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let clampedVal = CGFloat(max(0, min(1, value)))
            let tipX = w * clampedVal
            let trackHeight: CGFloat = isDragging ? 9.5 : (isHovering ? 8 : 6.5)
            let fillWidth: CGFloat = clampedVal <= 0.001 ? 0 : max(trackHeight * 0.7, tipX)
            let showKnob = isHovering || isDragging
            let knobWidth: CGFloat = isDragging ? 20 : 14
            let knobHeight: CGFloat = isDragging ? 14 : 12
            let knobCenterX = min(max(knobWidth / 2, tipX), w - knobWidth / 2)
            let stretchX = 1.0 + abs(overscroll) * 0.035
            let squishY = 1.0 - abs(overscroll) * 0.08

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(isDragging ? 0.22 : 0.16))
                    .frame(width: w, height: trackHeight)

                if fillWidth > 0 {
                    Capsule(style: .continuous)
                        .fill(tint)
                        .frame(width: min(w, fillWidth), height: trackHeight)
                        .shadow(color: isDragging ? tint.opacity(0.42) : .clear, radius: 6, x: 0, y: 0)
                }

                if showKnob {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(isDragging ? 0.96 : 0.88))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.75), lineWidth: 0.75)
                        )
                        .frame(width: knobWidth, height: knobHeight)
                        .shadow(color: Color.black.opacity(0.32), radius: 3, y: 1)
                        .position(x: knobCenterX, y: 10)
                }
            }
            .frame(width: w, height: 20)
            .scaleEffect(x: stretchX, y: squishY, anchor: overscroll >= 0 ? .leading : .trailing)
            .offset(x: overscroll * 3.5)
            .animation(.spring(response: 0.24, dampingFraction: 0.68), value: isDragging)
            .animation(.spring(response: 0.22, dampingFraction: 0.74), value: isHovering)
            .animation(.spring(response: 0.30, dampingFraction: 0.58), value: overscroll)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.arrow.set()
                }
                onHoverChange(hovering)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let rawRatio = Float(drag.location.x / w)
                        onDragChange(rawRatio, drag.location.x)
                    }
                    .onEnded { drag in
                        let rawRatio = Float(drag.location.x / w)
                        onDragEnd(rawRatio)
                    }
            )
        }
        .frame(height: 20)
    }

    private var accentColor: Color {
        switch event.kind {
        case .charging, .fullBattery:
            return Color(red: 0.22, green: 0.90, blue: 0.48)
        case .unplugged:
            return Color(red: 1.0, green: 0.72, blue: 0.22)
        case .lowBattery:
            return Color(red: 1.0, green: 0.30, blue: 0.26)
        case .pomodoroFinished(let completed, _):
            return completed.accentColor
        case .trackChanged(_, _, let accent):
            return accent
        case .volume(_, let isMuted, _, _):
            return isMuted ? .red : Color(red: 0.28, green: 0.88, blue: 0.54)
        case .brightness:
            return Color(red: 1.0, green: 0.78, blue: 0.24)
        case .micMuted(let isMuted):
            return isMuted ? Color(red: 1.0, green: 0.30, blue: 0.26) : Color(red: 0.22, green: 0.90, blue: 0.48)
        case .bluetoothConnected:
            return Color(red: 0.34, green: 0.72, blue: 1.0)
        case .meetingSoon:
            return Color(red: 1.0, green: 0.38, blue: 0.38)
        case .shelfAdded:
            return Color(red: 0.36, green: 0.76, blue: 1.0)
        case .recordingSaved:
            return Color(red: 0.22, green: 0.90, blue: 0.48)
        case .recordingError:
            return Color(red: 1.0, green: 0.30, blue: 0.26)
        }
    }

    private var iconName: String {
        switch event.kind {
        case .charging:
            return "bolt.fill"
        case .unplugged:
            return "battery.50"
        case .lowBattery:
            return "battery.25"
        case .fullBattery:
            return "battery.100.bolt"
        case .pomodoroFinished(let completed, _):
            return completed.iconName
        case .trackChanged:
            return "music.note"
        case .volume(_, let isMuted, _, let deviceIcon):
            return isMuted ? "speaker.slash.fill" : deviceIcon
        case .brightness:
            return "sun.max.fill"
        case .micMuted(let isMuted):
            return isMuted ? "mic.slash.fill" : "mic.fill"
        case .bluetoothConnected(_, _, _, _, _, _, _, let icon):
            return icon
        case .meetingSoon:
            return "video.fill"
        case .shelfAdded:
            return "tray.and.arrow.down.fill"
        case .recordingSaved:
            return "record.circle.fill"
        case .recordingError:
            return "exclamationmark.triangle.fill"
        }
    }

    private var titleText: String {
        switch event.kind {
        case .charging:
            return "Carregando"
        case .unplugged:
            return "Na bateria"
        case .lowBattery:
            return "Bateria fraca"
        case .fullBattery:
            return "Bateria completa"
        case .pomodoroFinished(let completed, _):
            return "\(completed.title) concluído"
        case .trackChanged(let title, _, _):
            return title
        case .volume(_, _, let deviceName, _):
            return deviceName
        case .brightness:
            return "Brilho"
        case .micMuted(let isMuted):
            return isMuted ? "Microfone Mutado" : "Microfone Ativado"
        case .bluetoothConnected(let name, _, _, _, _, _, _, _):
            return name
        case .meetingSoon(let title, _):
            return title
        case .shelfAdded(let count):
            return count == 1 ? "Arquivo guardado" : "\(count) arquivos guardados"
        case .recordingSaved:
            return "Gravação salva"
        case .recordingError:
            return "Erro na gravação"
        }
    }

    private var subtitleText: String {
        switch event.kind {
        case .charging(_, let watts):
            if let watts {
                return "Fonte de \(watts)W conectada"
            }
            return "Carregador conectado"
        case .unplugged:
            return "Alimentação desconectada"
        case .lowBattery:
            return "Conecte o carregador em breve"
        case .fullBattery:
            return "Carga de 100% atingida"
        case .pomodoroFinished(_, let next):
            return "Próxima etapa: \(next.title)"
        case .trackChanged(_, let artist, _):
            return artist.isEmpty ? "Tocando agora" : artist
        case .volume, .brightness:
            return ""
        case .micMuted(let isMuted):
            return isMuted ? "Captura de áudio silenciada" : "Pronto para falar"
        case .bluetoothConnected(_, let batteryText, _, _, _, _, _, _):
            return batteryText ?? "Dispositivo Bluetooth conectado"
        case .meetingSoon(_, let minutes):
            return minutes <= 1 ? "Começa agora" : "Começa em \(minutes) minutos"
        case .shelfAdded:
            return "Disponível na Bandeja da ilha"
        case .recordingSaved(let filename):
            return filename
        case .recordingError(let message):
            return message
        }
    }

    @ViewBuilder
    private var iconBadge: some View {
        if case .trackChanged = event.kind, let artwork = music.artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.75)
                )
                .shadow(color: accentColor.opacity(0.32), radius: 5, x: 0, y: 2)
        } else {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.20))
                    .frame(width: 32, height: 32)
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
        }
    }

    @ViewBuilder
    private var trailingView: some View {
        switch event.kind {
        case .charging(let percent, _), .unplugged(let percent), .lowBattery(let percent):
            pill("\(percent)%", color: accentColor)

        case .fullBattery:
            pill("100%", color: accentColor)

        case .pomodoroFinished(_, let next):
            pill(next.shortTitle, color: next.accentColor)

        case .trackChanged(_, _, let accent):
            AudioVisualizerView(
                isPlaying: true,
                accentColor: accent,
                barCount: 4,
                barWidth: 2.5,
                maxHeight: 16,
                spacing: 2.2
            )

        case .micMuted(let isMuted):
            pill(isMuted ? "OFF" : "ON", color: accentColor)

        case .bluetoothConnected:
            pill("BT", color: accentColor)

        case .meetingSoon(_, let minutes):
            pill("\(minutes)m", color: accentColor)

        case .shelfAdded(let count):
            pill("+\(count)", color: accentColor)

        case .recordingSaved(let filename):
            pill(filename.lowercased().hasSuffix(".mp4") ? "MP4" : "MOV", color: accentColor)

        case .recordingError:
            pill("!", color: accentColor)

        case .volume, .brightness:
            EmptyView()
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
    }
}
