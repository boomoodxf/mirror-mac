import Foundation
import Combine

@MainActor
final class ScrcpyService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    private var process: Process?

    func start(device: AndroidDevice, settings: MirrorSettings) {
        stop()
        lastError = nil

        guard let executableURL = scrcpyURL else {
            lastError = "未找到 scrcpy。请将 scrcpy 和 adb 放入应用的 Runtime 目录。"
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

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = (ProcessInfo.processInfo.environment).merging([
            "ADB": adbURL?.path ?? "adb"
        ]) { _, new in new }

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = errorPipe
        process.terminationHandler = { [weak self] finishedProcess in
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            Task { @MainActor in
                if finishedProcess.terminationStatus != 0 {
                    self?.lastError = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if self?.lastError?.isEmpty != false {
                        self?.lastError = "scrcpy 已退出，退出码：\(finishedProcess.terminationStatus)"
                    }
                }
                self?.isRunning = false
                self?.process = nil
            }
        }

        do {
            try process.run()
            self.process = process
            isRunning = true
        } catch {
            lastError = "启动 scrcpy 失败：\(error.localizedDescription)"
        }
    }

    func stop() {
        guard let process else { return }
        process.terminate()
        self.process = nil
        isRunning = false
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
