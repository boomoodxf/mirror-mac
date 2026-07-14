import SwiftUI

struct ContentView: View {
    @StateObject private var model = DeviceListViewModel()

    var body: some View {
        NavigationSplitView {
            deviceSidebar
        } detail: {
            detailView
        }
        .frame(minWidth: 860, minHeight: 560)
        .alert("提示", isPresented: alertPresented, presenting: model.message) { _ in
            Button("好") { model.message = nil }
        } message: { message in
            Text(message)
        }
    }

    private var deviceSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("设备")
                    .font(.headline)
                Spacer()
                Button { model.startAllMirrors() } label: {
                    Image(systemName: "play.rectangle")
                }
                .buttonStyle(.borderless)
                .disabled(model.connectedDevices.isEmpty)
                .help("同时启动所有已连接设备的镜像")
                Button { model.stopAllMirrors() } label: {
                    Image(systemName: "stop.circle")
                }
                .buttonStyle(.borderless)
                .disabled(!model.hasRunningMirrors)
                .help("停止所有镜像")
                Button { model.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(model.isRefreshing)
                .help("刷新设备")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if model.devices.isEmpty {
                EmptyStateView(
                    title: "没有设备",
                    systemImage: "iphone.slash",
                    message: "请连接 Android 手机并开启 USB 调试"
                )
            } else {
                List(selection: $model.selectedDeviceID) {
                    ForEach(model.devices) { device in
                        DeviceRow(device: device, scrcpy: model.scrcpy)
                            .tag(device.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.select(device)
                            }
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()
            wirelessConnectView
        }
        .navigationSplitViewColumnWidth(min: 250, ideal: 280)
    }

    private var wirelessConnectView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("无线 ADB")
                .font(.subheadline.weight(.semibold))
            HStack {
                TextField("IP:端口", text: $model.wirelessAddress)
                    .textFieldStyle(.roundedBorder)
                Button("连接") { model.connectWireless() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private var detailView: some View {
        if let device = model.selectedDevice {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "iphone.gen3")
                            .font(.system(size: 28))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(device.displayName)
                                .font(.title2.weight(.semibold))
                            Text("\(device.connectionLabel) · \(device.serial)")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Label(device.state.label, systemImage: device.state == .device ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(device.state == .device ? .green : .orange)
                    }
                }

                Section("镜像设置") {
                    Picker("最大分辨率", selection: $model.settings.maxSize) {
                        Text("原始").tag("0")
                        Text("1920 px").tag("1920")
                        Text("1600 px").tag("1600")
                        Text("1280 px").tag("1280")
                    }
                    Picker("最大帧率", selection: $model.settings.maxFPS) {
                        Text("30 FPS").tag(30)
                        Text("60 FPS").tag(60)
                        Text("90 FPS").tag(90)
                    }
                    TextField("视频码率", text: $model.settings.videoBitRate)
                    Toggle("播放手机音频", isOn: $model.settings.audioEnabled)
                    Toggle("保持手机唤醒", isOn: $model.settings.stayAwake)
                }

                MirrorActionSection(
                    device: device,
                    scrcpy: model.scrcpy,
                    onStart: { model.startMirror(for: device) },
                    onStop: { model.stopMirror() }
                )
            }
            .formStyle(.grouped)
            .padding()
        } else {
            EmptyStateView(
                title: "选择设备",
                systemImage: "rectangle.connected.to.line.below",
                message: "连接 Android 设备后，在左侧选择它"
            )
        }
    }

    private var alertPresented: Binding<Bool> {
        Binding(
            get: { model.message != nil },
            set: { if !$0 { model.message = nil } }
        )
    }
}

private struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct DeviceRow: View {
    let device: AndroidDevice
    @ObservedObject var scrcpy: ScrcpyService

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: device.serial.contains(":") ? "wifi" : "cable.connector")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .lineLimit(1)
                Text(device.connectionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if scrcpy.isRunning(for: device.id) {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.green)
                    .help("正在镜像")
            } else {
                Circle()
                    .fill(device.state == .device ? .green : .orange)
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MirrorActionSection: View {
    let device: AndroidDevice
    @ObservedObject var scrcpy: ScrcpyService
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        Section {
            HStack {
                if scrcpy.isRunning(for: device.id) {
                    Button("停止镜像", role: .destructive, action: onStop)
                } else {
                    Button("开始镜像", action: onStart)
                        .keyboardShortcut(.defaultAction)
                        .disabled(device.state != .device)
                }
                Spacer()
                if let error = scrcpy.lastError(for: device.id) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }
}
