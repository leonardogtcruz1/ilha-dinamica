import Darwin
import Foundation

@MainActor
final class SystemMonitorService: ObservableObject {
    @Published private(set) var cpuUsagePercent: Double = 0
    @Published private(set) var memoryUsedGB: Double = 0
    @Published private(set) var memoryTotalGB: Double = 0
    @Published private(set) var memoryUsagePercent: Double = 0
    @Published private(set) var downloadBytesPerSec: Double = 0
    @Published private(set) var uploadBytesPerSec: Double = 0

    private var timer: Timer?
    private var prevCPUCounts: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    private var prevNetBytes: (rx: UInt64, tx: UInt64, timestamp: Date)?

    init() {
        memoryTotalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
        sample()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sample()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    deinit {
        timer?.invalidate()
    }

    var formattedDownload: String {
        formatSpeed(downloadBytesPerSec)
    }

    var formattedUpload: String {
        formatSpeed(uploadBytesPerSec)
    }

    var formattedMemory: String {
        String(format: "%.1f / %.0f GB", memoryUsedGB, memoryTotalGB)
    }

    private func sample() {
        sampleCPU()
        sampleMemory()
        sampleNetwork()
    }

    private func sampleCPU() {
        var count: mach_msg_type_number_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPU: natural_t = 0

        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPU, &cpuInfo, &count)
        guard kr == KERN_SUCCESS, let cpuInfo else { return }
        defer {
            let byteSize = vm_size_t(Int(count) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), byteSize)
        }

        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0

        let stride = Int(CPU_STATE_MAX)
        for cpu in 0..<Int(numCPU) {
            let base = cpu * stride
            totalUser += UInt64(max(0, cpuInfo[base + Int(CPU_STATE_USER)]))
            totalSystem += UInt64(max(0, cpuInfo[base + Int(CPU_STATE_SYSTEM)]))
            totalIdle += UInt64(max(0, cpuInfo[base + Int(CPU_STATE_IDLE)]))
            totalNice += UInt64(max(0, cpuInfo[base + Int(CPU_STATE_NICE)]))
        }

        if let prev = prevCPUCounts {
            let dUser = totalUser >= prev.user ? totalUser - prev.user : 0
            let dSys = totalSystem >= prev.system ? totalSystem - prev.system : 0
            let dIdle = totalIdle >= prev.idle ? totalIdle - prev.idle : 0
            let dNice = totalNice >= prev.nice ? totalNice - prev.nice : 0

            let used = dUser + dSys + dNice
            let total = used + dIdle
            if total > 0 {
                cpuUsagePercent = min(100, max(0, (Double(used) / Double(total)) * 100.0))
            }
        }

        prevCPUCounts = (totalUser, totalSystem, totalIdle, totalNice)
    }

    private func sampleMemory() {
        var vm = vm_statistics64()
        // Classic 38-integer_t count covers all fields read here (offsets <= 144 bytes) across macOS 14–27
        var count: mach_msg_type_number_t = 38
        let kr = withUnsafeMutablePointer(to: &vm) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return }

        let pageSize = UInt64(sysconf(_SC_PAGESIZE))
        let appPages = UInt64(vm.internal_page_count) - UInt64(vm.purgeable_count)
        let wiredPages = UInt64(vm.wire_count)
        let compressedPages = UInt64(vm.compressor_page_count)
        let usedBytes = Double(appPages + wiredPages + compressedPages) * Double(pageSize)
        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)

        memoryUsedGB = usedBytes / 1_073_741_824.0
        if totalBytes > 0 {
            memoryUsagePercent = min(100, max(0, (usedBytes / totalBytes) * 100.0))
        }
    }

    private func sampleNetwork() {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return }
        defer { freeifaddrs(first) }

        var rxBytes: UInt64 = 0
        var txBytes: UInt64 = 0

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            let addr = current.pointee
            let flags = Int32(addr.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if isUp, !isLoopback,
               let sa = addr.ifa_addr,
               sa.pointee.sa_family == UInt8(AF_LINK),
               let namePtr = addr.ifa_name,
               let dataPtr = addr.ifa_data {
                let name = String(cString: namePtr)
                if name.hasPrefix("en") {
                    let netData = dataPtr.assumingMemoryBound(to: if_data.self).pointee
                    rxBytes += UInt64(netData.ifi_ibytes)
                    txBytes += UInt64(netData.ifi_obytes)
                }
            }
            cursor = addr.ifa_next
        }

        let now = Date()
        if let prev = prevNetBytes {
            let dt = now.timeIntervalSince(prev.timestamp)
            if dt > 0.2 {
                let dRx = rxBytes >= prev.rx ? rxBytes - prev.rx : 0
                let dTx = txBytes >= prev.tx ? txBytes - prev.tx : 0
                downloadBytesPerSec = Double(dRx) / dt
                uploadBytesPerSec = Double(dTx) / dt
            }
        }
        prevNetBytes = (rxBytes, txBytes, now)
    }

    private func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576 {
            return String(format: "%.1f MB/s", bytesPerSec / 1_048_576.0)
        }
        if bytesPerSec >= 1024 {
            return String(format: "%.0f KB/s", bytesPerSec / 1024.0)
        }
        return String(format: "%.0f B/s", bytesPerSec)
    }
}
