import Foundation
import Combine

@MainActor
final class DeviceListViewModel: ObservableObject {
    @Published private(set) var devices: [AndroidDevice] = []
    @Published var selectedDevice: AndroidDevice?
    @Published var settings = MirrorSettings()
    @Published var wirelessAddress = ""
    @Published private(set) var isRefreshing = false
    @Published var message: String?

    let scrcpy = ScrcpyService()
    private let adb = ADBService()
    private var refreshTask: Task<Void, Never>?

    init() {
        refresh()
    }

    deinit {
        refreshTask?.cancel()
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        refreshTask?.cancel()
        refreshTask = Task { [adb] in
            let devices = await Task.detached(priority: .userInitiated) {
                adb.listDevices()
            }.value

            guard !Task.isCancelled else { return }
            self.devices = devices
            if let selectedDevice, devices.contains(selectedDevice) == false {
                self.selectedDevice = devices.first
            } else if self.selectedDevice == nil {
                self.selectedDevice = devices.first
            }
            self.isRefreshing = false
        }
    }

    func startMirror() {
        guard let selectedDevice else {
            message = "请先选择一台设备。"
            return
        }
        guard selectedDevice.state == .device else {
            message = "设备当前状态为“\(selectedDevice.state.label)”。"
            return
        }
        scrcpy.start(device: selectedDevice, settings: settings)
    }

    func stopMirror() {
        scrcpy.stop()
    }

    func connectWireless() {
        let address = wirelessAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            message = "请输入 Android 设备的 IP 地址，例如 192.168.1.20:5555。"
            return
        }

        Task.detached { [adb] in
            let connected = adb.connect(address: address)
            await MainActor.run {
                self.message = connected ? "无线 ADB 已连接。" : "无线 ADB 连接失败。"
                self.refresh()
            }
        }
    }
}
