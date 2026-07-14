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
