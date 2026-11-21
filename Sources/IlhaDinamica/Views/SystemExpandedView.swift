import SwiftUI

struct SystemExpandedView: View {
    @ObservedObject var battery: BatteryService
    @ObservedObject var system: SystemMonitorService
    @ObservedObject var weather: WeatherService
    var onOpenWeather: (() -> Void)? = nil

    private var ringColor: Color {
        if battery.isCharging || battery.isFullyCharged {
            return Color(red: 0.22, green: 0.90, blue: 0.48)
        } else if battery.percentage <= 10 {
            return Color(red: 1.0, green: 0.28, blue: 0.26)
        } else if battery.percentage <= 20 {
            return Color(red: 1.0, green: 0.65, blue: 0.16)
        } else {
            return Color(red: 0.30, green: 0.85, blue: 0.56)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 6.5)

                    Circle()
                        .trim(from: 0, to: CGFloat(battery.percentage) / 100.0)
                        .stroke(
                            ringColor,
                            style: StrokeStyle(lineWidth: 6.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: battery.percentage)

                    VStack(spacing: 1) {
                        if battery.isCharging || battery.isPluggedIn {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(ringColor)
                        }
                        Text("\(battery.percentage)%")
                            .font(.system(size: 16.5, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 70, height: 70)

                VStack(spacing: 2) {
                    Text(battery.statusText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(batterySubline)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color.white.opacity(0.52))
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    miniPill(label: "Saúde", value: battery.healthPercent.map { "\($0)%" } ?? "--")
                    miniPill(label: "Ciclos", value: battery.cycleCount.map { "\($0)" } ?? "--")
                }
            }
            .frame(width: 146)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(spacing: 7) {
                usageBarTile(
                    icon: "cpu",
                    title: "CPU",
                    detail: String(format: "%.0f%%", system.cpuUsagePercent),
                    fraction: system.cpuUsagePercent / 100.0,
                    tint: Color(red: 0.36, green: 0.76, blue: 1.0)
                )

                usageBarTile(
                    icon: "memorychip",
                    title: "Memória RAM",
                    detail: system.formattedMemory,
                    fraction: system.memoryUsagePercent / 100.0,
                    tint: Color(red: 0.76, green: 0.56, blue: 1.0)
                )

                HStack(spacing: 7) {
                    compactInfoTile(
                        icon: "arrow.down.arrow.up",
                        title: "Rede",
                        value: "↓ \(system.formattedDownload) • ↑ \(system.formattedUpload)",
                        tint: Color(red: 0.22, green: 0.90, blue: 0.48)
                    )

                    Button {
                        onOpenWeather?()
                    } label: {
                        compactInfoTile(
                            icon: weather.symbolName,
                            title: weather.cityName.isEmpty ? "Clima" : weather.cityName,
                            value: weatherValueText,
                            tint: Color(red: 1.0, green: 0.78, blue: 0.24)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Abrir previsão do tempo")
                }
            }
        }
    }

    private func miniPill(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 8.5))
                .foregroundStyle(Color.white.opacity(0.45))
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func usageBarTile(icon: String, title: String, detail: String, fraction: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(detail)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.76))
            }

            GeometryReader { geo in
                let w = max(1, geo.size.width)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(tint)
                        .frame(width: w * CGFloat(max(0.02, min(1, fraction))))
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func compactInfoTile(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white.opacity(0.48))
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var batterySubline: String {
        let watts = battery.powerWatts.map { String(format: "%.1fW", $0) } ?? ""
        let temp = battery.temperatureCelsius.map { String(format: "%.0f°C", $0) } ?? ""
        if !watts.isEmpty && !temp.isEmpty { return "\(watts) • \(temp)" }
        return watts + temp
    }

    private var weatherValueText: String {
        guard let temp = weather.temperatureCelsius else { return weather.conditionText }
        return String(format: "%.0f°C • %@", temp, weather.conditionText)
    }
}
