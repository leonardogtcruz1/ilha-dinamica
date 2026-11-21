import AppKit
import SwiftUI

// MARK: - 1. Calculadora & Conversor

struct CalculatorExpandedView: View {
    @ObservedObject var extraWidgets: ExtraWidgetsService
    @ObservedObject var coordinator: IslandCoordinator

    private let accent = IslandTab.calculator.accentColor

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    TextField("Digite ex: 1450 * 1.18", text: $extraWidgets.calcExpression)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .onSubmit {
                            extraWidgets.commitCalcEvaluation()
                        }
                        .onTapGesture {
                            coordinator.focusPanelForTyping()
                        }

                    Button {
                        extraWidgets.clearCalc()
                    } label: {
                        Text("C")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .center, spacing: 6) {
                    Text(extraWidgets.calcError ? "Expressão inválida" : "= \(extraWidgets.calcResult)")
                        .font(.system(size: extraWidgets.calcError ? 12 : 20, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(extraWidgets.calcError ? Color.red : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Spacer()

                    Button {
                        extraWidgets.copyCalcResult()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: extraWidgets.calcCopiedNotice ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 9.5, weight: .bold))
                            Text(extraWidgets.calcCopiedNotice ? "Copiado" : "Copiar")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(extraWidgets.calcCopiedNotice ? .black : .white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            extraWidgets.calcCopiedNotice ? Color(red: 0.22, green: 0.90, blue: 0.48) : accent.opacity(0.28),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        quickChip("+10%", action: { extraWidgets.applyQuickConversion("plus10") })
                        quickChip("-15%", action: { extraWidgets.applyQuickConversion("minus15") })
                        quickChip("÷12", action: { extraWidgets.applyQuickConversion("div12") })
                        quickChip("°C→°F", action: { extraWidgets.applyQuickConversion("c2f") })
                        quickChip("km→mi", action: { extraWidgets.applyQuickConversion("km2mi") })
                        quickChip("kg→lb", action: { extraWidgets.applyQuickConversion("kg2lb") })
                    }
                }

                if let last = extraWidgets.calcHistory.first {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white.opacity(0.42))
                        Text("\(last.expression) = \(last.result)")
                            .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color.white.opacity(0.58))
                            .lineLimit(1)
                    }
                    .padding(.top, 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            keypadGrid
                .frame(width: 158)
        }
    }

    private var keypadGrid: some View {
        let rows: [[String]] = [
            ["7", "8", "9", "÷"],
            ["4", "5", "6", "×"],
            ["1", "2", "3", "−"],
            ["0", ".", "=", "+"]
        ]

        return VStack(spacing: 4) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { token in
                        let isOperator = ["÷", "×", "−", "+", "="].contains(token)
                        Button {
                            if token == "=" {
                                extraWidgets.commitCalcEvaluation()
                            } else {
                                extraWidgets.appendCalcToken(token)
                            }
                        } label: {
                            Text(token)
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .frame(height: 29)
                                .background(
                                    token == "="
                                        ? accent
                                        : (isOperator ? accent.opacity(0.26) : Color.white.opacity(0.10)),
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(5)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func quickChip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.86))
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 2. Conta-gotas de Cor

struct ColorPickerExpandedView: View {
    @ObservedObject var extraWidgets: ExtraWidgetsService

    private let accent = IslandTab.colorPicker.accentColor

    private var latest: PickedColorItem? {
        extraWidgets.pickedColors.first
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    extraWidgets.pickColorFromScreen()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "eyedropper.halffull")
                            .font(.system(size: 13, weight: .bold))
                        Text(extraWidgets.isSamplingColor ? "Clique em qualquer pixel..." : "Capturar Cor da Tela")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        LinearGradient(
                            colors: [accent, Color(red: 0.62, green: 0.34, blue: 0.96)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(.plain)

                if let color = latest {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(red: color.red, green: color.green, blue: color.blue))
                            .frame(width: 48, height: 48)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            colorFormatButton(title: color.hex, copyValue: color.hex)
                            colorFormatButton(title: color.rgb, copyValue: color.rgb)
                            colorFormatButton(title: "SwiftUI Color(...)", copyValue: color.swiftUICode)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            VStack(alignment: .leading, spacing: 5) {
                Text("RECENTES")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.white.opacity(0.45))

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                        spacing: 6
                    ) {
                        ForEach(extraWidgets.pickedColors) { item in
                            Button {
                                extraWidgets.copyColorString(item.hex, label: item.hex)
                            } label: {
                                HStack(spacing: 5) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color(red: item.red, green: item.green, blue: item.blue))
                                        .frame(width: 15, height: 15)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .stroke(Color.white.opacity(0.22), lineWidth: 0.5)
                                        )

                                    Text(item.hex)
                                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(extraWidgets.copiedColorLabel == item.hex ? Color(red: 0.22, green: 0.90, blue: 0.48) : .white.opacity(0.88))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .help("Copiar \(item.hex)")
                        }
                    }
                }
            }
            .frame(width: 196)
        }
    }

    private func colorFormatButton(title: String, copyValue: String) -> some View {
        let isCopied = extraWidgets.copiedColorLabel == copyValue
        return Button {
            extraWidgets.copyColorString(copyValue, label: copyValue)
        } label: {
            HStack(spacing: 5) {
                Text(isCopied ? "Copiado!" : title)
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isCopied ? Color(red: 0.22, green: 0.90, blue: 0.48) : .white.opacity(0.9))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 3. Cronômetro & Contagem Regressiva

struct StopwatchExpandedView: View {
    @ObservedObject var extraWidgets: ExtraWidgetsService

    private let accent = IslandTab.stopwatch.accentColor

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    modeButton(title: "Cronômetro", isSelected: !extraWidgets.timerModeIsCountdown) {
                        extraWidgets.timerModeIsCountdown = false
                    }
                    modeButton(title: "Contagem", isSelected: extraWidgets.timerModeIsCountdown) {
                        extraWidgets.timerModeIsCountdown = true
                    }
                }

                if extraWidgets.timerModeIsCountdown {
                    Text(extraWidgets.formattedCountdown)
                        .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(extraWidgets.isCountdownRunning ? accent : .white)

                    HStack(spacing: 6) {
                        Button {
                            extraWidgets.toggleCountdown()
                        } label: {
                            Label(
                                extraWidgets.isCountdownRunning ? "Pausar" : "Iniciar",
                                systemImage: extraWidgets.isCountdownRunning ? "pause.fill" : "play.fill"
                            )
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .frame(height: 27)
                            .background(accent, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            extraWidgets.resetCountdown()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(width: 27, height: 27)
                                .background(Color.white.opacity(0.10), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text(extraWidgets.formattedStopwatch)
                        .font(.system(size: 31, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(extraWidgets.isStopwatchRunning ? accent : .white)

                    HStack(spacing: 6) {
                        Button {
                            extraWidgets.toggleStopwatch()
                        } label: {
                            Label(
                                extraWidgets.isStopwatchRunning ? "Pausar" : "Iniciar",
                                systemImage: extraWidgets.isStopwatchRunning ? "pause.fill" : "play.fill"
                            )
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .frame(height: 27)
                            .background(accent, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            extraWidgets.recordLap()
                        } label: {
                            Text("Volta")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal, 10)
                                .frame(height: 27)
                                .background(Color.white.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!extraWidgets.isStopwatchRunning && extraWidgets.stopwatchElapsed < 0.05)

                        Button {
                            extraWidgets.resetStopwatch()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(width: 27, height: 27)
                                .background(Color.white.opacity(0.10), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            rightPanel
                .frame(width: 196)
        }
    }

    @ViewBuilder
    private var rightPanel: some View {
        if extraWidgets.timerModeIsCountdown {
            VStack(alignment: .leading, spacing: 6) {
                Text("ALARMES RÁPIDOS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.white.opacity(0.45))

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                    spacing: 6
                ) {
                    ForEach([1, 5, 10, 15, 25, 45], id: \.self) { mins in
                        let isSelected = extraWidgets.countdownDurationSeconds == mins * 60
                        Button {
                            extraWidgets.selectCountdownPreset(minutes: mins)
                        } label: {
                            Text("\(mins) min")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(isSelected ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 29)
                                .background(
                                    isSelected ? accent : Color.white.opacity(0.09),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 5) {
                Text("VOLTAS REGISTRADAS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.white.opacity(0.45))

                if extraWidgets.stopwatchLaps.isEmpty {
                    Text("Clique em Volta enquanto o cronômetro estiver rodando.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(extraWidgets.stopwatchLaps.enumerated()), id: \.offset) { idx, lap in
                                let lapNumber = extraWidgets.stopwatchLaps.count - idx
                                HStack {
                                    Text("#\(lapNumber)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(accent)
                                    Spacer()
                                    Text(formatLap(lap))
                                        .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                        }
                    }
                }
            }
            .padding(8)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func modeButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(isSelected ? .black : Color.white.opacity(0.75))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.white : Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func formatLap(_ t: TimeInterval) -> String {
        let total = Int((t * 100).rounded(.down))
        return String(format: "%02d:%02d.%02d", (total / 6000) % 60, (total / 100) % 60, total % 100)
    }
}

// MARK: - 4. Gerador de QR Code

struct QRCodeExpandedView: View {
    @ObservedObject var extraWidgets: ExtraWidgetsService
    @ObservedObject var coordinator: IslandCoordinator

    private let accent = IslandTab.qrCode.accentColor

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)

                if let img = extraWidgets.qrImage {
                    Image(nsImage: img)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                } else {
                    Text("Vazio")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.gray)
                }
            }
            .frame(width: 116, height: 116)

            VStack(alignment: .leading, spacing: 8) {
                Text("LINK OU TEXTO PARA QR CODE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.white.opacity(0.45))

                TextField("Cole um link, Wi-Fi ou texto...", text: $extraWidgets.qrText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .onTapGesture {
                        coordinator.focusPanelForTyping()
                    }

                HStack(spacing: 6) {
                    Button {
                        extraWidgets.loadQRFromClipboard()
                    } label: {
                        Label("Clipboard", systemImage: "doc.on.clipboard")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(accent.opacity(0.32), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        extraWidgets.copyQRImageToClipboard()
                    } label: {
                        Label("Copiar QR", systemImage: "photo.on.rectangle")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(Color.white.opacity(0.11), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        extraWidgets.saveQRImageToDownloads()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.11), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Salvar PNG em Downloads")
                }

                Text(extraWidgets.qrActionFeedback ?? "Aponte a câmera do iPhone para abrir direto.")
                    .font(.system(size: 10))
                    .foregroundStyle(
                        extraWidgets.qrActionFeedback != nil
                            ? Color(red: 0.22, green: 0.90, blue: 0.48)
                            : Color.white.opacity(0.50)
                    )
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 5. Launcher de Apps & Pastas

struct LauncherExpandedView: View {
    @ObservedObject var extraWidgets: ExtraWidgetsService

    private let accent = IslandTab.launcher.accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(extraWidgets.lastLaunchedName.map { "Abrindo \($0)..." } ?? "APPS & PASTAS RÁPIDAS")
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(
                        extraWidgets.lastLaunchedName != nil
                            ? Color(red: 0.22, green: 0.90, blue: 0.48)
                            : Color.white.opacity(0.48)
                    )

                Spacer()

                Button {
                    extraWidgets.promptAddCustomApp()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("Adicionar App")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .frame(height: 22)
                    .background(accent.opacity(0.32), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 5),
                    spacing: 7
                ) {
                    ForEach(extraWidgets.launcherItems) { item in
                        Button {
                            extraWidgets.openLauncherItem(item)
                        } label: {
                            VStack(spacing: 4) {
                                Image(nsImage: extraWidgets.icon(for: item))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)

                                Text(item.name)
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                            .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Abrir \(item.name)") {
                                extraWidgets.openLauncherItem(item)
                            }
                            if item.isCustom {
                                Button("Remover do Launcher", role: .destructive) {
                                    extraWidgets.removeCustomLauncherItem(item)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 6. Rede & Speedtest

struct NetworkExpandedView: View {
    @ObservedObject var extraWidgets: ExtraWidgetsService
    @ObservedObject var system: SystemMonitorService

    private let accent = IslandTab.network.accentColor

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Label("↓ \(system.formattedDownload)", systemImage: "arrow.down.circle.fill")
                            .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(accent)
                        Spacer()
                        Label("↑ \(system.formattedUpload)", systemImage: "arrow.up.circle.fill")
                            .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color.white.opacity(0.76))
                    }

                    networkSparkline
                        .frame(height: 36)
                }
                .padding(9)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }

            HStack(spacing: 7) {
                Button {
                    extraWidgets.copyNetworkString(extraWidgets.localIP, label: "IP local copiado")
                } label: {
                    infoCard(title: extraWidgets.interfaceName, value: extraWidgets.localIP, tint: accent)
                }
                .buttonStyle(.plain)
                .help("Copiar IP local")

                Button {
                    if extraWidgets.publicIP == "—" {
                        extraWidgets.fetchPublicIP()
                    } else {
                        extraWidgets.copyNetworkString(extraWidgets.publicIP, label: "IP público copiado")
                    }
                } label: {
                    infoCard(
                        title: "IP Público",
                        value: extraWidgets.isFetchingPublicIP
                            ? "Buscando..."
                            : (extraWidgets.publicIP == "—" ? "Consultar" : extraWidgets.publicIP),
                        tint: Color(red: 0.36, green: 0.76, blue: 1.0)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    extraWidgets.measurePing()
                } label: {
                    infoCard(
                        title: "Ping (1.1.1.1)",
                        value: extraWidgets.isPinging
                            ? "Testando..."
                            : (extraWidgets.pingMs.map { "\($0) ms" } ?? "Medir"),
                        tint: Color(red: 1.0, green: 0.78, blue: 0.24)
                    )
                }
                .buttonStyle(.plain)
            }

            if let notice = extraWidgets.copiedIPNotice {
                Text(notice)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(accent)
            }
        }
    }

    private var networkSparkline: some View {
        let samples = extraWidgets.downloadHistory
        let maxVal = max(10_240, samples.max() ?? 10_240)

        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let step = w / CGFloat(max(1, samples.count - 1))

            Path { path in
                for (index, val) in samples.enumerated() {
                    let x = CGFloat(index) * step
                    let norm = CGFloat(min(1.0, max(0.03, val / maxVal)))
                    let y = h - norm * (h - 4) - 2
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    private func infoCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.48))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - 7. Modo Cafeína

struct CaffeineExpandedView: View {
    @ObservedObject var extraWidgets: ExtraWidgetsService

    private let accent = IslandTab.caffeine.accentColor

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(extraWidgets.isCaffeineActive ? accent.opacity(0.22) : Color.white.opacity(0.07))
                        .frame(width: 58, height: 58)
                    Image(systemName: extraWidgets.isCaffeineActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(extraWidgets.isCaffeineActive ? accent : Color.white.opacity(0.55))
                }

                Text(extraWidgets.formattedCaffeineRemaining)
                    .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(extraWidgets.isCaffeineActive ? accent : Color.white.opacity(0.58))
            }
            .frame(width: 120)
            .frame(maxHeight: .infinity)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(extraWidgets.isCaffeineActive ? "Mac Mantido Acordado" : "Suspensão Normal do Mac")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(.white)

                Text("Impede a tela de escurecer ou entrar em repouso durante builds, downloads e apresentações.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    caffeinePreset(label: "Sem limite", minutes: 0)
                    caffeinePreset(label: "30 min", minutes: 30)
                    caffeinePreset(label: "1h", minutes: 60)
                    caffeinePreset(label: "2h", minutes: 120)
                }

                Button {
                    extraWidgets.toggleCaffeine()
                } label: {
                    Text(extraWidgets.isCaffeineActive ? "Desativar Cafeína" : "Ativar Agora")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(extraWidgets.isCaffeineActive ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 29)
                        .background(
                            extraWidgets.isCaffeineActive ? Color(red: 1.0, green: 0.28, blue: 0.26) : accent,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func caffeinePreset(label: String, minutes: Int) -> some View {
        let selected = extraWidgets.caffeinePresetMinutes == minutes
        return Button {
            extraWidgets.enableCaffeine(minutes: minutes)
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(selected && extraWidgets.isCaffeineActive ? .black : .white.opacity(0.86))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    selected && extraWidgets.isCaffeineActive ? accent : Color.white.opacity(0.09),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 8. Limpeza de Tela & Teclado

struct ScreenCleanExpandedView: View {
    @ObservedObject var extraWidgets: ExtraWidgetsService

    private let accent = IslandTab.screenClean.accentColor

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 5)
                if extraWidgets.isCleaningScreen {
                    Circle()
                        .trim(from: 0, to: CGFloat(extraWidgets.cleaningRemainingSeconds) / 30.0)
                        .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                if extraWidgets.isCleaningScreen {
                    Text("\(extraWidgets.cleaningRemainingSeconds)s")
                        .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(accent)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 7) {
                Text(extraWidgets.isCleaningScreen ? "Teclado Bloqueado para Limpeza" : "Modo Limpeza do MacBook")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(.white)

                Text(
                    extraWidgets.isCleaningScreen
                        ? "Teclas ignoradas temporariamente. Limpe o teclado e a tela com tranquilidade."
                        : "Bloqueia as teclas por 30 segundos para evitar comandos acidentais ao limpar o teclado."
                )
                .font(.system(size: 10.5))
                .foregroundStyle(Color.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)

                if extraWidgets.cleaningNeedsAccessibility {
                    HStack(spacing: 6) {
                        Text("Permita Acessibilidade para travar teclas")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Color.yellow)
                        Button("Autorizar") {
                            extraWidgets.requestAccessibilityForClean()
                        }
                        .font(.system(size: 9.5, weight: .bold))
                        .buttonStyle(.plain)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.yellow.opacity(0.22), in: Capsule())
                    }
                }

                Button {
                    if extraWidgets.isCleaningScreen {
                        extraWidgets.stopScreenClean()
                    } else {
                        extraWidgets.startScreenClean(seconds: 30)
                    }
                } label: {
                    Text(extraWidgets.isCleaningScreen ? "Desbloquear Agora" : "Iniciar Limpeza (30s)")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(extraWidgets.isCleaningScreen ? .white : .black)
                        .padding(.horizontal, 14)
                        .frame(height: 29)
                        .background(
                            extraWidgets.isCleaningScreen ? Color(red: 1.0, green: 0.28, blue: 0.26) : accent,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
    }
}

// MARK: - 9. Baterias & Bluetooth

struct BatteriesExpandedView: View {
    @ObservedObject var battery: BatteryService
    @ObservedObject var audio: AudioControlService

    private let accent = IslandTab.batteries.accentColor

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: battery.isCharging || battery.isPluggedIn ? "bolt.fill" : "laptopcomputer")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(accent)
                    Text("\(battery.percentage)%")
                        .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                }

                Text(battery.statusText)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.84))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let health = battery.healthPercent {
                        badgePill("Saúde \(health)%")
                    }
                    if let cycles = battery.cycleCount {
                        badgePill("\(cycles) ciclos")
                    }
                }

                if let watts = battery.powerWatts {
                    Text(String(format: "%.1fW em uso", watts))
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color.white.opacity(0.50))
                }
            }
            .frame(width: 146)
            .frame(maxHeight: .infinity)
            .padding(8)
            .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("DISPOSITIVOS BLUETOOTH")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.white.opacity(0.45))
                    Spacer()
                    Button {
                        Task { await audio.refreshBluetoothDevices(emitToast: false) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                    .help("Atualizar baterias Bluetooth")
                }

                if audio.bluetoothDevices.isEmpty {
                    Text("Nenhum dispositivo Bluetooth conectado.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.52))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 5) {
                            ForEach(audio.bluetoothDevices) { dev in
                                HStack(spacing: 8) {
                                    Image(systemName: dev.isAudio ? "airpodspro" : "keyboard")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(accent)
                                        .frame(width: 18)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(dev.name)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text(dev.batterySummary ?? "Conectado")
                                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color.white.opacity(0.65))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func badgePill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.84))
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Color.white.opacity(0.09), in: Capsule())
    }
}

// MARK: - 10. Sons de Foco / Ambiente

struct AmbientSoundExpandedView: View {
    @ObservedObject var extraWidgets: ExtraWidgetsService

    private let accent = IslandTab.ambientSound.accentColor

    var body: some View {
        VStack(spacing: 9) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 5),
                spacing: 7
            ) {
                ForEach(AmbientPreset.allCases) { preset in
                    let active = extraWidgets.activeAmbientPreset == preset
                    Button {
                        extraWidgets.toggleAmbientPreset(preset)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: preset.iconName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(active ? .white : accent)

                            Text(preset.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 68)
                        .background(
                            active ? accent.opacity(0.38) : Color.white.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(active ? accent : Color.white.opacity(0.08), lineWidth: active ? 1.2 : 0.7)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.68))

                Slider(
                    value: Binding(
                        get: { Double(extraWidgets.ambientVolume) },
                        set: { extraWidgets.ambientVolume = Float($0) }
                    ),
                    in: 0.05...1.0
                )
                .tint(accent)

                Text("\(Int((extraWidgets.ambientVolume * 100).rounded()))%")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.76))
                    .frame(width: 34, alignment: .trailing)

                if extraWidgets.activeAmbientPreset != nil {
                    Button {
                        extraWidgets.stopAmbientSound()
                    } label: {
                        Text("Parar")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(Color(red: 1.0, green: 0.28, blue: 0.26), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

// MARK: - 11. Relógio Mundial

struct WorldClockExpandedView: View {
    @ObservedObject var extraWidgets: ExtraWidgetsService

    private let accent = IslandTab.worldClock.accentColor

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 7),
                GridItem(.flexible(), spacing: 7),
                GridItem(.flexible(), spacing: 7)
            ],
            spacing: 7
        ) {
            ForEach(extraWidgets.worldCities) { city in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(city.flag)
                            .font(.system(size: 12))
                        Text(city.name)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    Text(extraWidgets.formattedTime(for: city))
                        .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(accent)

                    HStack(spacing: 4) {
                        Text(extraWidgets.dayLabel(for: city))
                        Text("•")
                        Text(extraWidgets.relativeOffsetLabel(for: city))
                    }
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}
