import Foundation

struct ADBService {
    private let fileManager = FileManager.default

    var executableURL: URL? {
        if let bundled = Bundle.module.url(forResource: "adb", withExtension: nil) {
            return bundled
        }

        let candidates = [
            "/opt/homebrew/bin/adb",
            "/usr/local/bin/adb",
            "/usr/bin/adb"
        ]

        return candidates
            .map(URL.init(fileURLWithPath:))
            .first { fileManager.isExecutableFile(atPath: $0.path) }
    }

    func listDevices() -> [AndroidDevice] {
        guard let executableURL else { return [] }
        let result = run(executableURL, arguments: ["devices", "-l"])
        guard result.status == 0 else { return [] }

        return result.output
            .split(whereSeparator: \.isNewline)
            .dropFirst()
            .compactMap(parseDeviceLine)
    }

    @discardableResult
    func connect(address: String) -> Bool {
        guard let executableURL else { return false }
        return run(executableURL, arguments: ["connect", address]).status == 0
    }

    func listFiles(serial: String, path: String) -> (files: [RemoteFile], error: String?) {
        guard let executableURL else {
            return ([], "未找到 adb。请将 adb 放入应用的 Runtime 目录。")
        }

        let result = run(executableURL, arguments: [
            "-s", serial,
            "shell", "ls", "-1p", path
        ])
        guard result.status == 0 else {
            return ([], cleanError(result.output, fallback: "读取手机文件失败。"))
        }

        let normalizedPath = normalizedRemotePath(path)
        let files = result.output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
            .map { entry -> RemoteFile in
                let isDirectory = entry.hasSuffix("/")
                let name = isDirectory ? String(entry.dropLast()) : entry
                let childPath = normalizedPath == "/"
                    ? "/\(name)"
                    : "\(normalizedPath)/\(name)"
                return RemoteFile(name: name, path: childPath, isDirectory: isDirectory)
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory && !rhs.isDirectory
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

        return (files, nil)
    }

    @discardableResult
    func push(serial: String, localURL: URL, to remoteDirectory: String) -> (success: Bool, error: String?) {
        guard let executableURL else {
            return (false, "未找到 adb。请将 adb 放入应用的 Runtime 目录。")
        }

        let result = run(executableURL, arguments: [
            "-s", serial,
            "push", localURL.path, normalizedRemotePath(remoteDirectory)
        ])
        guard result.status == 0 else {
            return (false, cleanError(result.output, fallback: "复制文件到手机失败。"))
        }
        return (true, nil)
    }

    @discardableResult
    func pull(serial: String, remotePath: String, to localURL: URL) -> (success: Bool, error: String?) {
        guard let executableURL else {
            return (false, "未找到 adb。请将 adb 放入应用的 Runtime 目录。")
        }

        let result = run(executableURL, arguments: [
            "-s", serial,
            "pull", normalizedRemotePath(remotePath), localURL.path
        ])
        guard result.status == 0 else {
            return (false, cleanError(result.output, fallback: "保存手机文件失败。"))
        }
        return (true, nil)
    }

    private func parseDeviceLine(_ line: Substring) -> AndroidDevice? {
        let columns = line.split(whereSeparator: \.isWhitespace)
        guard columns.count >= 2 else { return nil }

        let serial = String(columns[0])
        let state: AndroidDevice.State
        switch columns[1] {
        case "device": state = .device
        case "offline": state = .offline
        case "unauthorized": state = .unauthorized
        default: state = .unknown
        }

        var attributes: [String: String] = [:]
        for column in columns.dropFirst(2) {
            let pair = column.split(separator: ":", maxSplits: 1).map(String.init)
            if pair.count == 2 { attributes[pair[0]] = pair[1] }
        }

        return AndroidDevice(
            serial: serial,
            state: state,
            model: attributes["model"],
            product: attributes["product"]
        )
    }

    private func normalizedRemotePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "/" }
        if trimmed == "/" { return "/" }
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    private func cleanError(_ output: String, fallback: String) -> String {
        let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? fallback : message
    }

    private func run(_ executableURL: URL, arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        } catch {
            return (-1, "")
        }
    }
}
