import Combine
import Foundation
import IOKit
import IOKit.ps

@MainActor
final class BatteryService: ObservableObject {
    @Published private(set) var percentage: Int = 100
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var isPluggedIn: Bool = false
    @Published private(set) var isFullyCharged: Bool = false
    @Published private(set) var isLowPowerMode: Bool = false
    @Published private(set) var timeRemainingMinutes: Int?
    @Published private(set) var cycleCount: Int?
    @Published private(set) var healthPercent: Int?
    @Published private(set) var temperatureCelsius: Double?
    @Published private(set) var powerWatts: Double?
    @Published private(set) var adapterWatts: Int?
    @Published private(set) var adapterName: String?
    @Published private(set) var adapterVoltageVolts: Double?
    @Published private(set) var systemPowerInWatts: Double?
    @Published private(set) var batteryChargeWatts: Double?
    @Published private(set) var statusText: String = "Na bateria"

    var onBatteryEvent: ((ToastEvent) -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var refreshTimer: Timer?
    private var lowPowerObserver: NSObjectProtocol?
    private var postPlugRefreshTask: Task<Void, Never>?

    private var hasInitialized = false
    private var previousPluggedIn = false
    private var previousFullyCharged = false
    private var alertedLowTier: Int?

    init() {
        refresh(emitToasts: false)
        setupNotifications()
    }

    deinit {
        refreshTimer?.invalidate()
        postPlugRefreshTask?.cancel()
        if let lowPowerObserver {
            NotificationCenter.default.removeObserver(lowPowerObserver)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
    }

    func refreshNow() {
        refresh(emitToasts: true)
    }

    private func setupNotifications() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async {
                service.refresh(emitToasts: true)
            }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }

        lowPowerObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(emitToasts: false)
            }
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(emitToasts: true)
            }
        }
    }

    private func refresh(emitToasts: Bool) {
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

        var newPercentage = percentage
        var newIsCharging = isCharging
        var newIsPluggedIn = isPluggedIn
        var newIsFullyCharged = isFullyCharged
        var newTimeRemaining: Int?

        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else {
                    continue
                }
                let type = desc[kIOPSTypeKey] as? String
                if type != nil && type != kIOPSInternalBatteryType && sources.count > 1 {
                    continue
                }

                let currentCap = (desc[kIOPSCurrentCapacityKey] as? NSNumber)?.doubleValue ?? 0
                let maxCap = max(1, (desc[kIOPSMaxCapacityKey] as? NSNumber)?.doubleValue ?? 100)
                newPercentage = max(0, min(100, Int(((currentCap / maxCap) * 100.0).rounded())))

                let powerState = desc[kIOPSPowerSourceStateKey] as? String
                newIsPluggedIn = (powerState == kIOPSACPowerValue)
                newIsCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
                newIsFullyCharged = (desc[kIOPSIsChargedKey] as? Bool) ?? false

                if newIsPluggedIn {
                    if let ttf = (desc[kIOPSTimeToFullChargeKey] as? NSNumber)?.intValue, ttf > 0 {
                        newTimeRemaining = ttf
                    }
                } else {
                    if let tte = (desc[kIOPSTimeToEmptyKey] as? NSNumber)?.intValue, tte > 0 {
                        newTimeRemaining = tte
                    }
                }
                break
            }
        }

        let smartData = readSmartBatteryDetails()

        if newIsPluggedIn && newTimeRemaining == nil {
            newTimeRemaining = smartData.avgTimeToFullMinutes
        }

        percentage = newPercentage
        isCharging = newIsCharging
        isPluggedIn = newIsPluggedIn
        isFullyCharged = newIsFullyCharged
        timeRemainingMinutes = newTimeRemaining
        cycleCount = smartData.cycleCount
        healthPercent = smartData.healthPercent
        temperatureCelsius = smartData.temperatureCelsius
        powerWatts = smartData.powerWatts
        adapterWatts = smartData.adapterWatts
        adapterName = newIsPluggedIn ? smartData.adapterName : nil
        adapterVoltageVolts = newIsPluggedIn ? smartData.adapterVoltageVolts : nil
        systemPowerInWatts = newIsPluggedIn ? smartData.systemPowerInWatts : nil
        batteryChargeWatts = newIsPluggedIn ? smartData.batteryChargeWatts : nil

        if newIsFullyCharged || (newIsPluggedIn && newPercentage >= 100 && !newIsCharging) {
            statusText = "Bateria carregada"
        } else if newIsCharging {
            statusText = "Carregando"
        } else if newIsPluggedIn {
            statusText = "Conectado à tomada"
        } else {
            statusText = "Na bateria"
        }

        if hasInitialized && emitToasts {
            if newIsPluggedIn != previousPluggedIn {
                if newIsPluggedIn {
                    alertedLowTier = nil
                    onBatteryEvent?(ToastEvent(kind: .charging(percent: newPercentage, watts: smartData.adapterWatts)))
                    schedulePostPlugRefreshes()
                } else {
                    postPlugRefreshTask?.cancel()
                    postPlugRefreshTask = nil
                    onBatteryEvent?(ToastEvent(kind: .unplugged(percent: newPercentage)))
                }
            } else if newIsPluggedIn && !previousFullyCharged && newIsFullyCharged {
                onBatteryEvent?(ToastEvent(kind: .fullBattery))
            } else if !newIsPluggedIn {
                if newPercentage <= 10 && alertedLowTier != 10 {
                    alertedLowTier = 10
                    onBatteryEvent?(ToastEvent(kind: .lowBattery(percent: newPercentage)))
                } else if newPercentage <= 20 && newPercentage > 10 && alertedLowTier == nil {
                    alertedLowTier = 20
                    onBatteryEvent?(ToastEvent(kind: .lowBattery(percent: newPercentage)))
                } else if newPercentage > 22 {
                    alertedLowTier = nil
                }
            }
        }

        previousPluggedIn = newIsPluggedIn
        previousFullyCharged = newIsFullyCharged
        hasInitialized = true
    }

    private func schedulePostPlugRefreshes() {
        postPlugRefreshTask?.cancel()
        postPlugRefreshTask = Task { @MainActor [weak self] in
            let intervalsNs: [UInt64] = [800_000_000, 1_000_000_000, 1_400_000_000]
            for waitNs in intervalsNs {
                try? await Task.sleep(nanoseconds: waitNs)
                guard !Task.isCancelled, let self else { return }
                self.refresh(emitToasts: false)
            }
        }
    }

    private struct SmartBatteryDetails {
        var cycleCount: Int?
        var healthPercent: Int?
        var temperatureCelsius: Double?
        var powerWatts: Double?
        var adapterWatts: Int?
        var adapterName: String?
        var adapterVoltageVolts: Double?
        var systemPowerInWatts: Double?
        var batteryChargeWatts: Double?
        var avgTimeToFullMinutes: Int?
    }

    private func readSmartBatteryDetails() -> SmartBatteryDetails {
        var details = SmartBatteryDetails()

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return details }
        defer { IOObjectRelease(service) }

        var propsRef: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = propsRef?.takeRetainedValue() as? [String: Any] else {
            return details
        }

        details.cycleCount = (props["CycleCount"] as? NSNumber)?.intValue

        let designCap = (props["DesignCapacity"] as? NSNumber)?.doubleValue ?? 0
        let nominalCap = (props["NominalChargeCapacity"] as? NSNumber)?.doubleValue
        let rawMaxCap = (props["AppleRawMaxCapacity"] as? NSNumber)?.doubleValue
        if designCap > 0, let actualCap = nominalCap ?? rawMaxCap, actualCap > 0 {
            let health = Int(((actualCap / designCap) * 100.0).rounded())
            details.healthPercent = max(0, min(100, health))
        }

        if let rawTemp = (props["Temperature"] as? NSNumber)?.doubleValue, rawTemp > 0 {
            let celsius = rawTemp > 10_000 ? (rawTemp / 100.0 - 273.15) : (rawTemp / 100.0)
            if celsius > -20 && celsius < 100 {
                details.temperatureCelsius = celsius
            }
        }

        if let amps = (props["InstantAmperage"] as? NSNumber)?.int64Value,
           let voltage = (props["Voltage"] as? NSNumber)?.int64Value {
            let watts = abs(Double(amps) * Double(voltage)) / 1_000_000.0
            details.powerWatts = watts
            if amps > 0 {
                details.batteryChargeWatts = Double(amps) * Double(voltage) / 1_000_000.0
            }
        }

        if let avgTtf = (props["AvgTimeToFull"] as? NSNumber)?.intValue,
           avgTtf > 0 && avgTtf < 6000 {
            details.avgTimeToFullMinutes = avgTtf
        }

        if let adapter = props["AdapterDetails"] as? [String: Any] {
            if let watts = (adapter["Watts"] as? NSNumber)?.intValue, watts > 0 {
                details.adapterWatts = watts
            }
            if let name = (adapter["Name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !name.isEmpty {
                details.adapterName = name
            }
            if let mv = (adapter["AdapterVoltage"] as? NSNumber)?.doubleValue, mv > 0 {
                details.adapterVoltageVolts = mv / 1000.0
            }
        }

        if let telemetry = props["PowerTelemetryData"] as? [String: Any] {
            if let sysPowerMw = (telemetry["SystemPowerIn"] as? NSNumber)?.doubleValue, sysPowerMw > 0 {
                details.systemPowerInWatts = sysPowerMw / 1000.0
            }
            if let battPowerMw = (telemetry["BatteryPower"] as? NSNumber)?.int64Value, battPowerMw > 0 {
                details.batteryChargeWatts = Double(battPowerMw) / 1000.0
            }
            if let sysVoltageMv = (telemetry["SystemVoltageIn"] as? NSNumber)?.doubleValue, sysVoltageMv > 0 {
                details.adapterVoltageVolts = sysVoltageMv / 1000.0
            }
        }

        return details
    }
}
