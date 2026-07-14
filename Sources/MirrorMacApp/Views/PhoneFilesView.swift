import SwiftUI
import UniformTypeIdentifiers

struct PhoneFilesView: View {
    let device: AndroidDevice

    @State private var currentPath = "/sdcard"
    @State private var files: [RemoteFile] = []
    @State private var isLoading = false
    @State private var isUploading = false
    @State private var isDropTargeted = false
    @State private var statusMessage: String?

    private let adb = ADBService()

    var body: some View {
        Section("手机文件") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button {
                        navigateToParent()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .disabled(parentPath == nil || isLoading || isUploading)
                    .help("返回上一级目录")

                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(currentPath)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        loadFiles(at: currentPath)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .disabled(isLoading || isUploading)
                    .help("刷新手机文件")
                }

                fileList
                    .frame(minHeight: 150, maxHeight: 240)

                uploadDropZone

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
        .task(id: device.id) {
            loadFiles(at: currentPath)
        }
    }

    @ViewBuilder
    private var fileList: some View {
        if isLoading {
            VStack {
                ProgressView()
                Text("正在读取手机文件…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if files.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "folder.badge.questionmark")
                    .foregroundStyle(.secondary)
                Text("此目录为空")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(files) { file in
                        Button {
                            guard file.isDirectory else { return }
                            loadFiles(at: file.path)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: file.isDirectory ? "folder.fill" : "doc")
                                    .foregroundStyle(file.isDirectory ? .yellow : .secondary)
                                Text(file.name)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                if file.isDirectory {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!file.isDirectory || isUploading)
                    }
                }
            }
            .scrollIndicators(.automatic)
        }
    }

    private var uploadDropZone: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isDropTargeted ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
            .overlay {
                HStack(spacing: 8) {
                    if isUploading {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在复制文件到手机…")
                    } else {
                        Image(systemName: "arrow.down.doc")
                        Text("将 Mac 文件拖到这里，复制到当前目录")
                    }
                }
                .font(.caption)
                .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
                .padding(10)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
            .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
    }

    private var parentPath: String? {
        guard currentPath != "/" else { return nil }
        let parent = (currentPath as NSString).deletingLastPathComponent
        return parent.isEmpty ? "/" : parent
    }

    private func navigateToParent() {
        guard let parentPath else { return }
        loadFiles(at: parentPath)
    }

    private func loadFiles(at path: String) {
        currentPath = path
        isLoading = true
        statusMessage = nil

        let serial = device.serial
        let adb = self.adb
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                adb.listFiles(serial: serial, path: path)
            }.value

            guard !Task.isCancelled else { return }
            files = result.files
            statusMessage = result.error
            isLoading = false
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !isUploading else { return false }

        Task { @MainActor in
            let urls = await withTaskGroup(of: URL?.self, returning: [URL].self) { group in
                for provider in providers {
                    group.addTask {
                        await Self.url(from: provider)
                    }
                }

                var urls: [URL] = []
                for await url in group {
                    if let url {
                        urls.append(url)
                    }
                }
                return urls
            }

            upload(urls)
        }
        return true
    }

    private func upload(_ urls: [URL]) {
        guard !urls.isEmpty else {
            statusMessage = "没有读取到可复制的文件。"
            return
        }

        isUploading = true
        statusMessage = nil
        let serial = device.serial
        let destination = currentPath
        let adb = self.adb

        Task { @MainActor in
            var copiedCount = 0
            for url in urls {
                let result = await Task.detached(priority: .userInitiated) {
                    adb.push(serial: serial, localURL: url, to: destination)
                }.value

                if result.success {
                    copiedCount += 1
                } else {
                    statusMessage = result.error ?? "复制文件失败。"
                    break
                }
            }

            if copiedCount == urls.count {
                statusMessage = "已复制 \(copiedCount) 个文件到 \(destination)。"
                loadFiles(at: destination)
            } else if copiedCount > 0 {
                statusMessage = "已复制 \(copiedCount)/\(urls.count) 个文件。"
                loadFiles(at: destination)
            }
            isUploading = false
        }
    }

    private static func url(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data {
                    continuation.resume(returning: URL(dataRepresentation: data, relativeTo: nil))
                } else if let string = item as? String {
                    continuation.resume(returning: URL(fileURLWithPath: string))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
