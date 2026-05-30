import XCTest
@testable import NotchAgent

final class BrandingTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testBundleBrandingUsesNotchAgent() throws {
        let plistURL = repoRoot.appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertEqual(plist["CFBundleName"] as? String, "NotchAgent")
        XCTAssertEqual(plist["CFBundleExecutable"] as? String, "NotchAgent")
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "gg.tame.notchagent")
    }

    func testEnglishBrandStringsCreditTameWithoutNamingOriginalDev() {
        L10n.shared.language = "en"

        XCTAssertEqual(L10n.shared["settings_title"], "NotchAgent Settings")
        XCTAssertEqual(L10n.shared["about_devs"], "A tame.gg project")
        XCTAssertEqual(L10n.shared["about_credit"], "NotchAgent by tame.gg.")
        let originalAuthor = "wxt" + "sky"
        XCTAssertFalse(L10n.shared["about_credit"].localizedCaseInsensitiveContains(originalAuthor))
    }

    func testRemovedFeatureSettingsStringsAreRemoved() {
        let en = L10n.strings["en"] ?? [:]
        let removedPrefixes = ["rem" + "ote", "bud" + "dy"]
        let removedKeys = en.keys.filter { key in
            removedPrefixes.contains { key == $0 || key.hasPrefix("\($0)_") }
        }

        XCTAssertTrue(removedKeys.isEmpty, "Removed settings keys still present: \(removedKeys.sorted())")
    }

    func testBluetoothEntitlementRemovedWithDeletedHardwareSupport() throws {
        let entitlementsURL = repoRoot.appendingPathComponent("NotchAgent.entitlements")
        let data = try Data(contentsOf: entitlementsURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertNil(plist["com.apple.security.device.bluetooth"])
    }

    func testDeletedFeatureFilesAreRemoved() {
        let removedPaths = [
            "Sources/NotchAgent/Rem" + "oteHost.swift",
            "Sources/NotchAgent/Rem" + "oteManager.swift",
            "Sources/NotchAgent/Rem" + "oteInstaller.swift",
            "Sources/NotchAgent/SSHForwarder.swift",
            "Sources/NotchAgent/ESP32BridgeManager.swift",
            "Sources/NotchAgent/ESP32FocusCoordinator.swift",
            "Sources/NotchAgent/ESP32StatePublisher.swift",
            "Sources/NotchAgentCore/ESP32Protocol.swift",
            "Sources/NotchAgent/Resources/notchagent-rem" + "ote-hook.py",
            "Sources/NotchAgent/Resources/notchagent-opencode-rem" + "ote.js",
            "android-watch",
            "hardware",
        ]

        let remaining = removedPaths.filter {
            FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent($0).path)
        }
        XCTAssertTrue(remaining.isEmpty, "Removed feature files still present: \(remaining)")
    }
}
