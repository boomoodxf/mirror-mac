import Foundation
import Combine

@MainActor
final class ScrcpyService: ObservableObject {
    @Published private(set) var runningSerials: Set<String> = []
    @Published private(set) var lastErrors: [String: String] = [:]

    private var processes: [String: Process] = [:]

    func isRunning(for serial: String) -> Bool {
        runningSerials.contains(serial)
    }

    func lastError(for serial: String) -> String? {
        lastErrors[serial]
    }

    func start(device: AndroidDevice, settings: MirrorSettings) {
        stop(deviceID: device.serial)
        lastErrors[device.serial] = nil

        guard let executableURL = scrcpyURL else {
            lastErrors[device.serial] = "未找到 scrcpy。请将 scrcpy 和 adb 放入应用的 Runtime 目录。"
            return
        }

        var arguments = [
            "--serial", device.serial,
            "--window-title", "Mirror Mac - \(device.displayName)",
            "--max-size", settings.maxSize,
            "--max-fps", String(settings.maxFPS),
            "--video-bit-rate", settings.videoBitRate
        ]

        if settings.audioEnabled == false { arguments.append("--no-audio") }
        if settings.stayAwake { arguments.append("--stay-awake") }
        if settings.turnScreenOff { arguments.append("--turn-screen-off") }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging([
            "ADB": adbURL?.path ?? "adb"
        ]) { _, new in new }

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = errorPipe
        let serial = device.serial
        process.terminationHandler = { [weak self] finishedProcess in
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            Task { @MainActor in
                guard let self, self.processes[serial] === finishedProcess else { return }

                self.processes.removeValue(forKey: serial)
                self.runningSerials.remove(serial)

                if finishedProcess.terminationStatus != 0 {
                    let error = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.lastErrors[serial] = error.isEmpty
                        ? "scrcpy 已退出，退出码：\(finishedProcess.terminationStatus)"
                        : error
                }
            }
        }

        do {
            try process.run()
            processes[device.serial] = process
            runningSerials.insert(device.serial)
        } catch {
            lastErrors[device.serial] = "启动 scrcpy 失败：\(error.localizedDescription)"
        }
    }

    func stop(deviceID: String) {
        if let process = processes.removeValue(forKey: deviceID) {
            process.terminationHandler = nil
            process.terminate()
        }
        runningSerials.remove(deviceID)
    }

    func stopAll() {
        let serials = Array(processes.keys)
        serials.forEach(stop(deviceID:))
    }

    private var scrcpyURL: URL? {
        if let bundled = Bundle.module.url(forResource: "scrcpy", withExtension: nil) {
            return bundled
        }
        return ["/opt/homebrew/bin/scrcpy", "/usr/local/bin/scrcpy"]
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private var adbURL: URL? {
        if let bundled = Bundle.module.url(forResource: "adb", withExtension: nil) {
            return bundled
        }
        return ["/opt/homebrew/bin/adb", "/usr/local/bin/adb"]
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
