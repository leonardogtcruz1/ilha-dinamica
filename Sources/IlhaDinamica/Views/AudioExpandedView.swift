import CoreAudio
import SwiftUI

struct AudioExpandedView: View {
    @ObservedObject var audio: AudioControlService
    @ObservedObject var settings: SettingsStore

    private var dynamicVolumeIcon: String {
        if audio.isMuted || audio.volume <= 0.001 {
            return "speaker.slash.fill"
        }
        if audio.volume < 0.34 {
            return "speaker.wave.1.fill"
        }
        if audio.volume < 0.68 {
            return "speaker.wave.2.fill"
        }
        return "speaker.wave.3.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                controlSliderRow(
                    icon: dynamicVolumeIcon,
                    iconTint: audio.isMuted ? .red : settings.resolvedSliderColor(fallback: Color(red: 0.30, green: 0.85, blue: 0.56)),
                    label: "Volume",
                    value: audio.isMuted ? 0 : audio.volume,
                    isDragging: audio.isDraggingVolume,
                    isHovering: audio.isHoveringVolume,
                    overscroll: audio.volumeOverscroll,
                    dragVelocity: audio.volumeDragVelocity,
                    rotatesIcon: false,
                    onIconTap: { audio.toggleMute() },
                    onHoverChange: { audio.isHoveringVolume = $0 },
                    onDragChange: { rawRatio, locX in audio.updateVolumeDrag(rawRatio: rawRatio, locationX: locX) },
                    onDragEnd: { rawRatio in audio.endVolumeDrag(rawRatio: rawRatio) }
                )

                controlSliderRow(
                    icon: "sun.max.fill",
                    iconTint: settings.resolvedSliderColor(fallback: Color(red: 1.0, green: 0.78, blue: 0.24)),
                    label: "Brilho",
                    value: audio.brightness,
                    isDragging: audio.isDraggingBrightness,
                    isHovering: audio.isHoveringBrightness,
                    overscroll: audio.brightnessOverscroll,
                    dragVelocity: audio.brightnessDragVelocity,
                    rotatesIcon: true,
                    onIconTap: nil,
                    onHoverChange: { audio.isHoveringBrightness = $0 },
                    onDragChange: { rawRatio, locX in audio.updateBrightnessDrag(rawRatio: rawRatio, locationX: locX) },
                    onDragEnd: { rawRatio in audio.endBrightnessDrag(rawRatio: rawRatio) }
                )
            }
            .zIndex((audio.isDraggingVolume || audio.isDraggingBrightness) ? 10 : 1)

            HStack(spacing: 8) {
                Button {
                    audio.toggleMicMute()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: audio.isMicMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(audio.isMicMuted ? "Mic Mutado" : "Mic Ativo")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(audio.isMicMuted ? Color.white : Color.white.opacity(0.88))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        audio.isMicMuted ? Color.red.opacity(0.85) : Color.white.opacity(0.10),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(audio.outputDevices) { dev in
                            Button {
                                audio.selectOutputDevice(dev.id)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: dev.isBluetooth ? "airpodspro" : "hifispeaker.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(dev.name)
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(
                                    dev.isDefault
                                        ? settings.resolvedButtonForeground(fallback: .black)
                                        : Color.white.opacity(0.76)
                                )
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(
                                    dev.isDefault
                                        ? settings.resolvedButtonColor(fallback: .white)
                                        : Color.white.opacity(0.08),
                                    in: Capsule()
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !audio.bluetoothDevices.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(audio.bluetoothDevices) { bt in
                            bluetoothCard(bt)
                        }
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.42))
                    Text("Nenhum dispositivo Bluetooth conectado")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.45))
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .textSelection(.disabled)
    }

    private func controlSliderRow(
        icon: String,
        iconTint: Color,
        label: String,
        value: Float,
        isDragging: Bool,
        isHovering: Bool,
        overscroll: CGFloat,
        dragVelocity: CGFloat,
        rotatesIcon: Bool,
        onIconTap: (() -> Void)?,
        onHoverChange: @escaping (Bool) -> Void,
        onDragChange: @escaping (Float, CGFloat) -> Void,
        onDragEnd: @escaping (Float) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                if let onIconTap {
                    Button(action: onIconTap) {
                        sliderHeaderIcon(icon: icon, tint: iconTint, value: value, isDragging: isDragging, rotates: rotatesIcon)
                    }
                    .buttonStyle(.plain)
                } else {
                    sliderHeaderIcon(icon: icon, tint: iconTint, value: value, isDragging: isDragging, rotates: rotatesIcon)
                }

                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(isDragging ? 0.98 : 0.88))

                Spacer()

                Text("\(Int((value * 100).rounded()))%")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(isDragging ? iconTint : Color.white.opacity(0.62))
                    .scaleEffect(isDragging ? 1.08 : 1.0, anchor: .trailing)
                    .animation(.spring(response: 0.24, dampingFraction: 0.70), value: isDragging)
            }

            GeometryReader { geo in
                let width = max(1, geo.size.width)
                let clampedVal = CGFloat(max(0, min(1, value)))
                let tipX = width * clampedVal
                let trackHeight: CGFloat = isDragging ? 11 : (isHovering ? 9.5 : 8)
                let fillWidth: CGFloat = clampedVal <= 0.001 ? 0 : max(trackHeight * 0.7, tipX)

                let velocityBoost = min(6, abs(dragVelocity) * 6)
                let knobWidth: CGFloat = isDragging ? (28 + velocityBoost) : (isHovering ? 18 : 14)
                let knobHeight: CGFloat = isDragging ? (18 - min(2, abs(dragVelocity) * 2)) : (isHovering ? 15 : 14)
                let knobCenterX = min(max(knobWidth / 2, tipX), width - knobWidth / 2)

                let stretchX = 1.0 + abs(overscroll) * 0.045
                let squishY = 1.0 - abs(overscroll) * 0.10

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(isDragging ? 0.20 : 0.14))
                        .frame(width: width, height: trackHeight)

                    if fillWidth > 0 {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: isDragging
                                        ? [iconTint.opacity(0.88), iconTint, .white.opacity(0.85)]
                                        : [iconTint.opacity(0.85), iconTint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: min(width, fillWidth), height: trackHeight)
                            .shadow(color: isDragging ? iconTint.opacity(0.45) : .clear, radius: 7, x: 0, y: 0)
                    }

                    liquidGlassKnob(
                        width: knobWidth,
                        height: knobHeight,
                        tint: iconTint,
                        isDragging: isDragging,
                        isHovering: isHovering
                    )
                    .position(x: knobCenterX, y: 11)
                }
                .frame(width: width, height: 22)
                .scaleEffect(x: stretchX, y: squishY, anchor: overscroll >= 0 ? .leading : .trailing)
                .offset(x: overscroll * 4.5)
                .animation(.spring(response: 0.26, dampingFraction: 0.64), value: isDragging)
                .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isHovering)
                .animation(.spring(response: 0.32, dampingFraction: 0.56), value: overscroll)
                .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.75), value: dragVelocity)
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
                            let rawRatio = Float(drag.location.x / width)
                            onDragChange(rawRatio, drag.location.x)
                        }
                        .onEnded { drag in
                            let rawRatio = Float(drag.location.x / width)
                            onDragEnd(rawRatio)
                        }
                )
            }
            .frame(height: 22)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Color.white.opacity(isDragging ? 0.11 : (isHovering ? 0.09 : 0.07)),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(
                    iconTint.opacity(isDragging ? 0.42 : (isHovering ? 0.16 : 0.0)),
                    lineWidth: 0.85
                )
        )
        .zIndex(isDragging ? 10 : 1)
    }

    private func sliderHeaderIcon(icon: String, tint: Color, value: Float, isDragging: Bool, rotates: Bool) -> some View {
        Image(systemName: icon)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(tint)
            .rotationEffect(.degrees(rotates ? Double(value) * 180.0 : 0))
            .scaleEffect(isDragging ? 1.16 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.62), value: isDragging)
    }

    private func liquidGlassKnob(
        width: CGFloat,
        height: CGFloat,
        tint: Color,
        isDragging: Bool,
        isHovering: Bool
    ) -> some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(
                    isDragging
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.46),
                                Color.white.opacity(0.14),
                                tint.opacity(0.28)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    : AnyShapeStyle(Color.white.opacity(isHovering ? 0.98 : 0.94))
                )

            if isDragging {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.55)
            }

            Capsule(style: .continuous)
                .fill(Color.white.opacity(isDragging ? 0.55 : 0.0))
                .frame(width: max(8, width * 0.48), height: 2)
                .offset(y: -(height * 0.28))

            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isDragging ? 0.95 : 0.85),
                            Color.white.opacity(isDragging ? 0.28 : 0.45),
                            Color.white.opacity(isDragging ? 0.72 : 0.60)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: isDragging ? 1.2 : 0.8
                )
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(isDragging ? 0.48 : 0.25), radius: isDragging ? 6 : 2, x: 0, y: isDragging ? 2 : 1)
        .shadow(color: isDragging ? tint.opacity(0.38) : .clear, radius: 8, x: 0, y: 0)
    }

    private func bluetoothCard(_ bt: BluetoothDeviceInfo) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.28, green: 0.66, blue: 1.0).opacity(0.18))
                    .frame(width: 28, height: 28)
                Image(systemName: bt.isAudio ? "airpodspro" : "dot.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.36, green: 0.76, blue: 1.0))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(bt.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(bt.batterySummary ?? "Conectado")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.22, green: 0.90, blue: 0.48))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
