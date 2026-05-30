import SwiftUI

@main
struct NotchAgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var l10n = L10n.shared

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
