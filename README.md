# Mirror Mac

一个面向 Apple Silicon 的原生 macOS SwiftUI 外壳，用更贴近 macOS 的方式管理 Android 设备，并调用 [scrcpy](https://github.com/Genymobile/scrcpy) 完成低延迟镜像。

> **非官方项目声明**：Mirror Mac 是社区制作的独立 GUI 外壳，与 Genymobile、scrcpy 官方团队没有隶属或合作关系。Mirror Mac 不会修改 scrcpy 的核心实现，而是把设备发现、无线连接和常用镜像参数整理成一个原生 macOS 界面。

## 特性

- 原生 SwiftUI 界面，支持 Apple Silicon macOS 13+
- 读取 `adb devices -l`，显示设备型号、产品和连接状态
- 支持在列表中切换多台设备，并为每台设备独立启动/停止 scrcpy
- 支持一键同时启动所有已连接设备的镜像窗口
- 支持通过 `adb connect` 连接无线 ADB 设备
- 可配置最大尺寸、帧率、视频码率、音频和保持唤醒
- 支持伪锁屏：关闭手机端物理屏幕，同时保持投屏窗口可操作
- 在设备详情中浏览手机 `/sdcard` 文件，并支持从 Finder 拖拽文件上传
- 将 `scrcpy`、`scrcpy-server` 与 `adb` 一起打包进 App，开箱即用
- 找不到内置运行时文件时，回退到 Homebrew 常见安装路径

## 多设备镜像

左侧设备列表使用设备序列号作为选择标识，点击任意设备即可切换右侧详情。每台设备的 scrcpy 进程独立管理，因此可以同时启动多台设备；正在镜像的设备会在列表中显示绿色播放图标。

- 点击设备后，使用右侧“开始镜像”/“停止镜像”控制当前设备
- 点击设备栏顶部的播放按钮，同时启动所有状态为“已连接”的设备
- 点击停止按钮，停止所有正在运行的镜像进程
- 多台设备可以是 USB 和无线 ADB 的任意组合
- 在“镜像设置”中开启“伪锁屏：关闭手机屏幕”，然后重新启动镜像即可生效
- 在“手机文件”区域进入目标目录，将 Mac 文件拖入上传区域即可复制到手机

## 快速开始

### 开发环境

- macOS 13+
- Xcode / Swift 5.9+
- Apple Silicon Mac
- Android platform-tools（如果不使用仓库内置运行时）

```bash
swift build
swift run
```

### 准备 scrcpy 运行时

为了避免把上游二进制重复提交到源码仓库，运行时文件默认通过脚本从 scrcpy 官方 Release 下载。脚本当前使用 scrcpy `v4.1` 的 macOS ARM64 发布包：

```bash
./Scripts/fetch_runtime_arm64.sh
```

脚本会把以下文件放入 `Sources/MirrorMacApp/Resources/Runtime/`：

```text
adb
scrcpy
scrcpy-server
```

也可以自行放入兼容版本的文件；请同时确认其许可证和再分发条件。

### 打包 App

```bash
./Scripts/fetch_runtime_arm64.sh
./Scripts/package_app.sh
open dist/MirrorMac.app
```

`Scripts/package_app.sh` 会生成 `dist/MirrorMac.app`。当前发布包面向 Apple Silicon（arm64）。首次运行时，macOS 可能需要在“系统设置 → 隐私与安全性”中允许打开未签名应用。

## 项目结构

```text
App/                         App 元数据
Scripts/                     下载运行时、打包脚本
Sources/MirrorMacApp/
  Models/                    设备和镜像设置模型
  Services/                  ADB / scrcpy 进程服务
  ViewModels/                SwiftUI 状态管理
  Views/                     用户界面
  Resources/Runtime/         运行时占位目录与版本说明
```

## 向 scrcpy 致敬

Mirror Mac 的镜像能力建立在 scrcpy 之上。感谢 **Genymobile**、**Romain Vimont** 以及所有贡献者，感谢你们把 Android 设备的高质量、低延迟显示与控制带到了桌面平台。这个项目只是尝试用一个轻量的原生 macOS 外壳，向 scrcpy 的工程设计和长期维护致敬。

请访问原项目了解完整能力、文档、源码和最新版本：

- <https://github.com/Genymobile/scrcpy>
- <https://github.com/Genymobile/scrcpy/releases>

## 第三方组件与许可证

Mirror Mac 自身的 Swift 源码与上游运行时是分开管理的。scrcpy 及其相关组件遵循 Apache License 2.0；随 App 分发的 `scrcpy`、`scrcpy-server` 和 `adb` 来自对应的官方发布包。详细说明见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。

## Roadmap

- 录制、截图、剪贴板同步和全屏
- 更完善的多设备会话管理
- 使用原生 `NSWindow` 管理镜像窗口生命周期
- 在保持 scrcpy 核心能力的前提下探索更紧密的原生窗口体验
