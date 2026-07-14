import Foundation
import Combine

@MainActor
final class DeviceListViewModel: ObservableObject {
    @Published private(set) var devices: [AndroidDevice] = []
    @Published var selectedDeviceID: AndroidDevice.ID?
    @Published var settings = MirrorSettings()
    @Published var wirelessAddress = ""
    @Published private(set) var isRefreshing = false
    @Published var message: String?

    let scrcpy = ScrcpyService()
    private let adb = ADBService()
    private var refreshTask: Task<Void, Never>?

    var selectedDevice: AndroidDevice? {
        guard let selectedDeviceID else { return nil }
        return devices.first { $0.id == selectedDeviceID }
    }

    var connectedDevices: [AndroidDevice] {
        devices.filter { $0.state == .device }
    }

    var hasRunningMirrors: Bool {
        !scrcpy.runningSerials.isEmpty
    }

    init() {
        refresh()
    }

    deinit {
        refreshTask?.cancel()
    }

    func select(_ device: AndroidDevice) {
        selectedDeviceID = device.id
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
            if let selectedDeviceID = self.selectedDeviceID,
               devices.contains(where: { $0.id == selectedDeviceID }) {
                self.selectedDeviceID = selectedDeviceID
            } else {
                self.selectedDeviceID = devices.first?.id
            }
            self.isRefreshing = false
        }
    }

    func startMirror() {
        guard let selectedDevice else {
            message = "请先选择一台设备。"
            return
        }
        startMirror(for: selectedDevice)
    }

    func startMirror(for device: AndroidDevice) {
        guard device.state == .device else {
            message = "设备“\(device.displayName)”当前状态为“\(device.state.label)”。"
            return
        }
        scrcpy.start(device: device, settings: settings)
    }

    func startAllMirrors() {
        let devices = connectedDevices
        guard !devices.isEmpty else {
            message = "当前没有可启动镜像的已连接设备。"
            return
        }
        devices.forEach { scrcpy.start(device: $0, settings: settings) }
    }

    func stopMirror() {
        guard let selectedDevice else { return }
        scrcpy.stop(deviceID: selectedDevice.id)
    }

    func stopAllMirrors() {
        scrcpy.stopAll()
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
