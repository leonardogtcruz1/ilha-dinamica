import AppKit
import Combine
import Foundation

struct HourlyWeatherItem: Identifiable, Equatable {
    let id: String
    let hourLabel: String
    let tempCelsius: Double
    let symbolName: String
    let rainChance: Int?
}

struct DailyWeatherItem: Identifiable, Equatable {
    let id: String
    let dayLabel: String
    let minCelsius: Double
    let maxCelsius: Double
    let symbolName: String
    let rainChance: Int?
}

@MainActor
final class WeatherService: ObservableObject {
    @Published private(set) var temperatureCelsius: Double?
    @Published private(set) var apparentTempCelsius: Double?
    @Published private(set) var todayMaxCelsius: Double?
    @Published private(set) var todayMinCelsius: Double?
    @Published private(set) var todayRainChancePercent: Int?
    @Published private(set) var conditionText: String = "Carregando clima..."
    @Published private(set) var symbolName: String = "cloud.sun.fill"
    @Published private(set) var cityName: String = ""
    @Published private(set) var humidityPercent: Int?
    @Published private(set) var windKmh: Double?
    @Published private(set) var hourlyForecast: [HourlyWeatherItem] = []
    @Published private(set) var dailyForecast: [DailyWeatherItem] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading: Bool = false

    private let settings: SettingsStore
    private var timer: Timer?
    private var cancellable: AnyCancellable?

    init(settings: SettingsStore) {
        self.settings = settings
        observeCityChange()

        let timer = Timer(timeInterval: 20 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshNow()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        Task { await refreshNow() }
    }

    deinit {
        timer?.invalidate()
    }

    func refreshNow() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let customCity = settings.weatherCity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let location = await resolveLocation(customCity: customCity) else {
            if temperatureCelsius == nil {
                conditionText = "Clima indisponível"
            }
            return
        }

        cityName = location.city
        await fetchForecast(lat: location.lat, lon: location.lon)
    }

    func openAppleWeather() {
        let weatherAppURL = URL(fileURLWithPath: "/System/Applications/Weather.app")
        if FileManager.default.fileExists(atPath: weatherAppURL.path) {
            NSWorkspace.shared.open(weatherAppURL)
        } else if let webURL = URL(string: "https://weather.com") {
            NSWorkspace.shared.open(webURL)
        }
    }

    private func observeCityChange() {
        cancellable = settings.$weatherCity
            .dropFirst()
            .debounce(for: .milliseconds(700), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.refreshNow() }
            }
    }

    private struct ResolvedLocation {
        let city: String
        let lat: Double
        let lon: Double
    }

    private func resolveLocation(customCity: String) async -> ResolvedLocation? {
        if !customCity.isEmpty {
            let encoded = customCity.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? customCity
            if let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=pt&format=json"),
               let json = await fetchJSON(url),
               let results = json["results"] as? [[String: Any]],
               let first = results.first,
               let lat = doubleValue(first["latitude"]),
               let lon = doubleValue(first["longitude"]) {
                let name = (first["name"] as? String) ?? customCity
                return ResolvedLocation(city: name, lat: lat, lon: lon)
            }
        }

        if let url = URL(string: "https://ipwho.is/"),
           let json = await fetchJSON(url),
           let success = json["success"] as? Bool, success,
           let lat = doubleValue(json["latitude"]),
           let lon = doubleValue(json["longitude"]) {
            let city = (json["city"] as? String) ?? "Local"
            return ResolvedLocation(city: city, lat: lat, lon: lon)
        }

        if let url = URL(string: "https://get.geojs.io/v1/ip/geo.json"),
           let json = await fetchJSON(url),
           let latStr = json["latitude"] as? String,
           let lonStr = json["longitude"] as? String,
           let lat = Double(latStr),
           let lon = Double(lonStr) {
            let city = (json["city"] as? String) ?? "Local"
            return ResolvedLocation(city: city, lat: lat, lon: lon)
        }

        return nil
    }

    private func fetchForecast(lat: Double, lon: Double) async {
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m&hourly=temperature_2m,weather_code,precipitation_probability,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&forecast_days=4&timezone=auto"
        guard let url = URL(string: urlStr),
              let json = await fetchJSON(url),
              let current = json["current"] as? [String: Any] else {
            return
        }

        temperatureCelsius = doubleValue(current["temperature_2m"])
        apparentTempCelsius = doubleValue(current["apparent_temperature"])
        humidityPercent = intValue(current["relative_humidity_2m"])
        windKmh = doubleValue(current["wind_speed_10m"])

        let code = intValue(current["weather_code"]) ?? 0
        let isDay = (intValue(current["is_day"]) ?? 1) == 1
        let mapped = mapWeatherCode(code, isDay: isDay)
        conditionText = mapped.text
        symbolName = mapped.symbol
        lastUpdated = Date()

        let currentTimeStr = (current["time"] as? String) ?? ""

        if let hourly = json["hourly"] as? [String: Any] {
            parseHourly(hourly, after: currentTimeStr)
        }

        if let daily = json["daily"] as? [String: Any] {
            parseDaily(daily)
        }
    }

    private func parseHourly(_ hourly: [String: Any], after currentTimeStr: String) {
        guard let times = hourly["time"] as? [String],
              let temps = hourly["temperature_2m"] as? [Any],
              let codes = hourly["weather_code"] as? [Any] else {
            return
        }
        let rains = hourly["precipitation_probability"] as? [Any]
        let isDays = hourly["is_day"] as? [Any]

        let count = min(times.count, temps.count, codes.count)
        var picked: [HourlyWeatherItem] = []

        for idx in 0..<count {
            let timeStr = times[idx]
            if !currentTimeStr.isEmpty && timeStr <= currentTimeStr {
                continue
            }
            guard let temp = doubleValue(temps[idx]),
                  let code = intValue(codes[idx]) else {
                continue
            }
            let isDay = (isDays.flatMap { idx < $0.count ? intValue($0[idx]) : nil } ?? 1) == 1
            let rain = rains.flatMap { idx < $0.count ? intValue($0[idx]) : nil }
            let hourLabel: String
            if let tIdx = timeStr.firstIndex(of: "T") {
                let afterT = timeStr[timeStr.index(after: tIdx)...]
                hourLabel = String(afterT.prefix(2)) + "h"
            } else {
                hourLabel = timeStr
            }

            picked.append(
                HourlyWeatherItem(
                    id: timeStr,
                    hourLabel: hourLabel,
                    tempCelsius: temp,
                    symbolName: mapWeatherCode(code, isDay: isDay).symbol,
                    rainChance: rain
                )
            )
            if picked.count == 5 {
                break
            }
        }

        hourlyForecast = picked
    }

    private func parseDaily(_ daily: [String: Any]) {
        guard let times = daily["time"] as? [String],
              let maxes = daily["temperature_2m_max"] as? [Any],
              let mins = daily["temperature_2m_min"] as? [Any],
              let codes = daily["weather_code"] as? [Any] else {
            return
        }
        let rains = daily["precipitation_probability_max"] as? [Any]
        let count = min(times.count, maxes.count, mins.count, codes.count)

        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")

        let weekdayFmt = DateFormatter()
        weekdayFmt.dateFormat = "EEE"
        weekdayFmt.locale = Locale(identifier: "pt_BR")

        var items: [DailyWeatherItem] = []
        for idx in 0..<min(count, 3) {
            guard let maxT = doubleValue(maxes[idx]),
                  let minT = doubleValue(mins[idx]),
                  let code = intValue(codes[idx]) else {
                continue
            }
            let rain = rains.flatMap { idx < $0.count ? intValue($0[idx]) : nil }

            if idx == 0 {
                todayMaxCelsius = maxT
                todayMinCelsius = minT
                todayRainChancePercent = rain
            }

            let label: String
            if idx == 0 {
                label = "Hoje"
            } else if idx == 1 {
                label = "Amanhã"
            } else if let date = parser.date(from: times[idx]) {
                let raw = weekdayFmt.string(from: date).replacingOccurrences(of: ".", with: "")
                label = raw.prefix(1).uppercased() + raw.dropFirst()
            } else {
                label = times[idx]
            }

            items.append(
                DailyWeatherItem(
                    id: times[idx],
                    dayLabel: label,
                    minCelsius: minT,
                    maxCelsius: maxT,
                    symbolName: mapWeatherCode(code, isDay: true).symbol,
                    rainChance: rain
                )
            )
        }

        dailyForecast = items
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let n = value as? NSNumber { return n.doubleValue }
        return nil
    }

    private func intValue(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let d = value as? Double { return Int(d.rounded()) }
        if let n = value as? NSNumber { return Int(n.doubleValue.rounded()) }
        return nil
    }

    private func fetchJSON(_ url: URL) async -> [String: Any]? {
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            return nil
        }
    }

    private func mapWeatherCode(_ code: Int, isDay: Bool) -> (text: String, symbol: String) {
        switch code {
        case 0:
            return ("Céu limpo", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1, 2:
            return ("Parcialmente nublado", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3:
            return ("Nublado", "cloud.fill")
        case 45, 48:
            return ("Neblina", "cloud.fog.fill")
        case 51, 53, 55, 56, 57:
            return ("Garoa", "cloud.drizzle.fill")
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return ("Chuva", "cloud.rain.fill")
        case 71, 73, 75, 77, 85, 86:
            return ("Neve", "cloud.snow.fill")
        case 95, 96, 99:
            return ("Trovoada", "cloud.bolt.rain.fill")
        default:
            return ("Tempo variável", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        }
    }
}
