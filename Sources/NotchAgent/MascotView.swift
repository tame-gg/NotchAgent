import SwiftUI
import NotchAgentCore

// MARK: - Mascot Animation Speed Environment

private struct MascotSpeedKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

extension EnvironmentValues {
    var mascotSpeed: Double {
        get { self[MascotSpeedKey.self] }
        set { self[MascotSpeedKey.self] = newValue }
    }
}

/// Routes a CLI source identifier to the correct pixel mascot view.
struct MascotView: View {
    let source: String
    let status: AgentStatus
    var size: CGFloat = 27
    @AppStorage(SettingsKey.mascotSpeed) private var speedPct = SettingsDefaults.mascotSpeed

    var body: some View {
        Group {
            if CustomMascotStore.image(for: source) != nil {
                CustomMascotImage(source: source, size: size)
            } else {
                switch source {
                case "codex":
                    DexView(status: status, size: size)
                case "gemini":
                    GeminiView(status: status, size: size)
                case "cursor":
                    CursorView(status: status, size: size)
                case "trae", "traecn", "traecli":
                    TraeView(status: status, size: size)
                case "copilot":
                    CopilotView(status: status, size: size)
                case "qoder":
                    QoderView(status: status, size: size)
                case "droid":
                    DroidView(status: status, size: size)
                case "stepfun":
                    StepFunView(status: status, size: size)
                case "opencode":
                    OpenCodeView(status: status, size: size)
                case "qwen":
                    QwenView(status: status, size: size)
                case "antigravity":
                    AntiGravityView(status: status, size: size)
                case "hermes":
                    HermesView(status: status, size: size)
                case "kimi":
                    KimiView(status: status, size: size)
                case "cline":
                    ClineView(status: status, size: size)
                default:
                    ClawdView(status: status, size: size)
                }
            }
        }
        .environment(\.mascotSpeed, Double(speedPct) / 100.0)
    }
}

enum CustomMascotStore {
    static func path(for source: String) -> String? {
        let key = SettingsKey.customMascotPath(source)
        guard let path = UserDefaults.standard.string(forKey: key), !path.isEmpty else { return nil }
        return path
    }

    static func image(for source: String) -> NSImage? {
        guard let path = path(for: source) else { return nil }
        return NSImage(contentsOfFile: path)
    }

    static func setPath(_ path: String, for source: String) {
        UserDefaults.standard.set(path, forKey: SettingsKey.customMascotPath(source))
    }

    static func removePath(for source: String) {
        UserDefaults.standard.removeObject(forKey: SettingsKey.customMascotPath(source))
    }
}

struct CustomMascotImage: View {
    let source: String
    let size: CGFloat

    var body: some View {
        if let image = CustomMascotStore.image(for: source) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: max(4, size * 0.18), style: .continuous))
        } else {
            EmptyView()
        }
    }
}
