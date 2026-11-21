import SwiftUI

struct WeatherExpandedView: View {
    @ObservedObject var weather: WeatherService
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            topHeroRow

            HStack(spacing: 8) {
                hourlyCard
                dailyCard
            }
        }
    }

    private var topHeroRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: weather.symbolName)
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(weatherTint(for: weather.symbolName))
                    .frame(width: 34)

                Text(weather.temperatureCelsius.map { String(format: "%.0f°", $0) } ?? "--°")
                    .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(weather.cityName.isEmpty ? "Previsão do Tempo" : weather.cityName)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(weather.conditionText)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(1)

                    Text(sublineText)
                        .font(.system(size: 9.5, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.50))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 5) {
                    Button {
                        Task { await weather.refreshNow() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(weather.isLoading ? Color.white.opacity(0.35) : Color.white.opacity(0.75))
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.09), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(weather.isLoading)
                    .help("Atualizar previsão")

                    Button {
                        weather.openAppleWeather()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Tempo")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.84))
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Color.white.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Abrir app Tempo")

                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.white.opacity(0.84))
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Voltar")
                }

                HStack(spacing: 5) {
                    metricChip(
                        icon: "drop.fill",
                        value: weather.humidityPercent.map { "\($0)%" } ?? "--",
                        tint: Color(red: 0.36, green: 0.76, blue: 1.0)
                    )
                    metricChip(
                        icon: "wind",
                        value: weather.windKmh.map { String(format: "%.0f km/h", $0) } ?? "--",
                        tint: Color.white.opacity(0.72)
                    )
                    if let rain = weather.todayRainChancePercent {
                        metricChip(
                            icon: "cloud.rain.fill",
                            value: "\(rain)%",
                            tint: Color(red: 0.45, green: 0.72, blue: 1.0)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 0.75)
        )
    }

    private var hourlyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PRÓXIMAS HORAS")
                .font(.system(size: 8.5, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Color.white.opacity(0.45))

            if weather.hourlyForecast.isEmpty {
                Spacer(minLength: 0)
                Text(weather.isLoading ? "Carregando previsão..." : "Sem dados horários")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.48))
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
            } else {
                HStack(spacing: 4) {
                    ForEach(weather.hourlyForecast) { item in
                        VStack(spacing: 3) {
                            Text(item.hourLabel)
                                .font(.system(size: 9.5, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(Color.white.opacity(0.58))

                            Image(systemName: item.symbolName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(weatherTint(for: item.symbolName))
                                .frame(height: 16)

                            Text(String(format: "%.0f°", item.tempCelsius))
                                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white)

                            if let rain = item.rainChance, rain >= 20 {
                                Text("\(rain)%")
                                    .font(.system(size: 8, weight: .semibold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(Color(red: 0.42, green: 0.78, blue: 1.0))
                            } else {
                                Text(" ")
                                    .font(.system(size: 8))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
        )
    }

    private var dailyCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("PRÓXIMOS DIAS")
                .font(.system(size: 8.5, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Color.white.opacity(0.45))

            if weather.dailyForecast.isEmpty {
                Spacer(minLength: 0)
                Text("--")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
            } else {
                VStack(spacing: 5) {
                    ForEach(weather.dailyForecast) { day in
                        HStack(spacing: 6) {
                            Text(day.dayLabel)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.88))
                                .frame(width: 44, alignment: .leading)
                                .lineLimit(1)

                            Image(systemName: day.symbolName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(weatherTint(for: day.symbolName))
                                .frame(width: 16)

                            Spacer(minLength: 2)

                            Text(String(format: "%.0f°", day.minCelsius))
                                .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(Color.white.opacity(0.50))

                            Text("/")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white.opacity(0.30))

                            Text(String(format: "%.0f°", day.maxCelsius))
                                .font(.system(size: 10.5, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: 174)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
        )
    }

    private func metricChip(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.white.opacity(0.84))
                .lineLimit(1)
        }
        .padding(.horizontal, 6.5)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.08), in: Capsule())
    }

    private var sublineText: String {
        var parts: [String] = []
        if let feels = weather.apparentTempCelsius {
            parts.append(String(format: "Sensação %.0f°", feels))
        }
        if let maxT = weather.todayMaxCelsius, let minT = weather.todayMinCelsius {
            parts.append(String(format: "↑%.0f° ↓%.0f°", maxT, minT))
        }
        return parts.isEmpty ? "Open-Meteo" : parts.joined(separator: " • ")
    }

    private func weatherTint(for symbol: String) -> Color {
        if symbol.contains("bolt") {
            return Color(red: 1.0, green: 0.84, blue: 0.24)
        } else if symbol.contains("rain") || symbol.contains("drizzle") {
            return Color(red: 0.38, green: 0.76, blue: 1.0)
        } else if symbol.contains("snow") {
            return Color(red: 0.78, green: 0.92, blue: 1.0)
        } else if symbol.contains("moon") {
            return Color(red: 0.66, green: 0.76, blue: 1.0)
        } else if symbol.contains("sun") {
            return Color(red: 1.0, green: 0.80, blue: 0.28)
        } else {
            return Color.white.opacity(0.82)
        }
    }
}
