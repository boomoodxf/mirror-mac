import Foundation

struct AndroidDevice: Identifiable, Hashable {
    enum State: String {
        case device
        case offline
        case unauthorized
        case unknown

        var label: String {
            switch self {
            case .device: return "已连接"
            case .offline: return "离线"
            case .unauthorized: return "待授权"
            case .unknown: return "未知状态"
            }
        }
    }

    let serial: String
    let state: State
    let model: String?
    let product: String?

    var id: String { serial }

    var displayName: String {
        if let model, !model.isEmpty {
            return model.replacingOccurrences(of: "_", with: " ")
        }
        return serial
    }

    var connectionLabel: String {
        serial.contains(":") ? "无线 ADB" : "USB"
    }
}
