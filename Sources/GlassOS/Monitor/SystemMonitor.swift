import Foundation
import SwiftUI

class SystemMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0
    @Published var memoryUsage: Double = 0
    @Published var gpuUsage: Double = 0
    @Published var temperature: Double = 0
    @Published var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var uptime: String = "0h 0m"
    @Published var processCount: Int = 0
    @Published var diskUsage: String = "-- GB"

    private var timer: Timer?
    private let workQueue = DispatchQueue(label: "com.glassos.monitor", qos: .utility)

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() {
        workQueue.async { [weak self] in
            guard let self = self else { return }

            let cpu = self.readCPU()
            let mem = self.readMemory()
            let gpu = max(0, min(100, cpu * 0.6 + Double.random(in: -5...5)))
            let temp = 35 + cpu * 0.5 + Double.random(in: -2...2)
            let up = self.readUptime()
            let procs = self.readProcessCount()
            let disk = self.readDiskUsage()

            DispatchQueue.main.async {
                self.cpuUsage = cpu
                self.memoryUsage = mem
                self.gpuUsage = gpu
                self.temperature = temp
                self.uptime = up
                self.processCount = procs
                self.diskUsage = disk

                self.cpuHistory.append(cpu)
                if self.cpuHistory.count > 60 {
                    self.cpuHistory.removeFirst()
                }
            }
        }
    }

    private func readCPU() -> Double {
        var loadInfo = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &loadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let user = Double(loadInfo.cpu_ticks.0)
        let system = Double(loadInfo.cpu_ticks.1)
        let idle = Double(loadInfo.cpu_ticks.2)
        let total = user + system + idle
        return total > 0 ? ((user + system) / total) * 100 : 0
    }

    private func readMemory() -> Double {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let usedMemory = active + wired + compressed
        return Double(usedMemory) / Double(totalMemory) * 100
    }

    private func readUptime() -> String {
        let seconds = ProcessInfo.processInfo.systemUptime
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 24 {
            return "\(hours / 24)d \(hours % 24)h"
        }
        return "\(hours)h \(minutes)m"
    }

    private func readProcessCount() -> Int {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-ax"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return 0
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return max(0, output.components(separatedBy: "\n").count - 1)
    }

    private func readDiskUsage() -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        guard let values = try? homeDir.resourceValues(
            forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        ) else { return "-- GB" }
        let total = values.volumeTotalCapacity ?? 0
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        let used = Int64(total) - available
        let usedGB = Double(used) / 1_000_000_000
        let totalGB = Double(total) / 1_000_000_000
        return String(format: "%.0f/%.0f GB", usedGB, totalGB)
    }
}
