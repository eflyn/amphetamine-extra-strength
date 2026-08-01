import AppKit
import Combine
import Foundation

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let controller: UtilityController
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var cancellables = Set<AnyCancellable>()

    init(controller: UtilityController) {
        self.controller = controller
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.image = NSImage(
            systemSymbolName: "sun.min.fill",
            accessibilityDescription: "Amphetamine Extra Strength"
        )
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = "Amphetamine Extra Strength"

        controller.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.updateStatusIcon(snapshot)
            }
            .store(in: &cancellables)
    }

    func menuWillOpen(_ menu: NSMenu) {
        controller.refresh(reason: .manual)
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        let snapshot = controller.snapshot

        addHeading("Amphetamine Extra Strength")
        addStatus("Utility", snapshot.utilityStatus)
        addStatus("Amphetamine", snapshot.installation.label)
        addStatus("Amphetamine running", snapshot.amphetamineRunning ? "Yes" : "No")
        addStatus("Amphetamine session", snapshot.session.label)
        addStatus("MacBook lid", snapshot.lid.label)
        addStatus("Built-in brightness", brightnessLabel(snapshot.builtInBrightness))
        addStatus("Display dimmed by utility", snapshot.hasDisplayDimmed ? "Yes" : "No")
        if let savedBrightness = snapshot.brightnessOwnership.savedBrightness {
            addStatus("Saved display brightness", percentLabel(savedBrightness))
        }
        addStatus(
            "Keyboard backlight",
            brightnessLabel(snapshot.keyboardBacklightBrightness)
        )
        addStatus(
            "Keyboard dimmed by utility",
            snapshot.hasKeyboardBacklightDimmed ? "Yes" : "No"
        )
        if let savedKeyboardBacklight =
            snapshot.keyboardBacklightOwnership.savedBrightness
        {
            addStatus(
                "Saved keyboard backlight",
                percentLabel(savedKeyboardBacklight)
            )
        }
        if let launchError = snapshot.launchError {
            addMessage(launchError)
        }
        if let brightnessError = snapshot.brightnessError {
            addMessage(brightnessError)
        }
        if let keyboardBacklightError = snapshot.keyboardBacklightError {
            addMessage(keyboardBacklightError)
        }

        menu.addItem(.separator())
        addToggle(
            "Automatically launch Amphetamine",
            isOn: controller.settings.automaticallyLaunchAmphetamine,
            action: #selector(toggleAutomaticLaunch)
        )
        addToggle(
            "Relaunch Amphetamine if it quits",
            isOn: controller.settings.relaunchAmphetamine,
            action: #selector(toggleRelaunch)
        )
        addToggle(
            "Dim display and keyboard when lid is closed",
            isOn: controller.settings.dimWhenLidClosed,
            action: #selector(toggleAutomaticDimming)
        )
        addToggle(
            "Require an active Amphetamine session",
            isOn: controller.settings.requireActiveSession,
            action: #selector(toggleRequireActiveSession)
        )
        addToggle(
            "Launch utility at login",
            isOn: controller.loginItemState == .enabled
                || controller.loginItemState == .requiresApproval,
            action: #selector(toggleLaunchAtLogin)
        )
        if controller.loginItemState == .requiresApproval {
            addAction(
                "Approve Launch at Login…",
                action: #selector(openLoginItemSettings)
            )
        }

        menu.addItem(.separator())
        let sessionPermissionItem = sessionPermissionMenuItem(for: snapshot.session)
        if let sessionPermissionItem {
            menu.addItem(sessionPermissionItem)
        }

        let launchItem = addAction(
            snapshot.amphetamineRunning ? "Amphetamine Is Running" : "Launch Amphetamine Now",
            action: #selector(launchAmphetamineNow)
        )
        launchItem.isEnabled =
            snapshot.installation != .notInstalled && !snapshot.amphetamineRunning

        let restoreItem = addAction(
            "Restore Display and Keyboard Now",
            action: #selector(restoreBrightnessNow)
        )
        restoreItem.isEnabled = snapshot.ownsAnyBrightness

        menu.addItem(.separator())
        addAction("Open Settings…", action: #selector(openSettings))
        addAction("Quit", action: #selector(quit))
    }

    private func sessionPermissionMenuItem(
        for session: AmphetamineSessionState
    ) -> NSMenuItem? {
        switch session {
        case .unavailable(.permissionRequired):
            return configuredAction(
                "Allow Amphetamine Session Checking…",
                action: #selector(requestSessionAccess)
            )
        case .unavailable(.permissionDenied):
            return configuredAction(
                "Open Automation Privacy Settings…",
                action: #selector(openAutomationPrivacySettings)
            )
        default:
            return nil
        }
    }

    private func addHeading(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        ]
        item.attributedTitle = NSAttributedString(string: title, attributes: attributes)
        menu.addItem(item)
    }

    private func addStatus(_ label: String, _ value: String) {
        let item = NSMenuItem(title: "\(label): \(value)", action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addMessage(_ message: String) {
        let item = NSMenuItem(title: "⚠︎ \(message)", action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    @discardableResult
    private func addAction(_ title: String, action: Selector) -> NSMenuItem {
        let item = configuredAction(title, action: action)
        menu.addItem(item)
        return item
    }

    private func configuredAction(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func addToggle(_ title: String, isOn: Bool, action: Selector) {
        let item = configuredAction(title, action: action)
        item.state = isOn ? .on : .off
        menu.addItem(item)
    }

    private func updateStatusIcon(_ snapshot: UtilitySnapshot) {
        let symbolName: String
        if snapshot.ownsAnyBrightness {
            symbolName = "sun.min.fill"
        } else if snapshot.launchError != nil
                    || snapshot.brightnessError != nil
                    || snapshot.keyboardBacklightError != nil
        {
            symbolName = "exclamationmark.triangle.fill"
        } else {
            symbolName = "sun.max"
        }

        statusItem.button?.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: snapshot.utilityStatus
        )
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip =
            "Amphetamine Extra Strength — \(snapshot.utilityStatus)"
    }

    private func brightnessLabel(_ brightness: Float?) -> String {
        guard let brightness else {
            return "Unavailable"
        }
        return percentLabel(brightness)
    }

    private func percentLabel(_ brightness: Float) -> String {
        "\(Int((brightness * 100).rounded()))%"
    }

    @objc private func toggleAutomaticLaunch() {
        controller.settings.automaticallyLaunchAmphetamine.toggle()
    }

    @objc private func toggleRelaunch() {
        controller.settings.relaunchAmphetamine.toggle()
    }

    @objc private func toggleAutomaticDimming() {
        controller.settings.dimWhenLidClosed.toggle()
    }

    @objc private func toggleRequireActiveSession() {
        controller.settings.requireActiveSession.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        let isCurrentlyEnabled =
            controller.loginItemState == .enabled
            || controller.loginItemState == .requiresApproval
        controller.setLaunchAtLogin(!isCurrentlyEnabled)
    }

    @objc private func openLoginItemSettings() {
        controller.openLoginItemSettings()
    }

    @objc private func requestSessionAccess() {
        controller.requestSessionAccess()
    }

    @objc private func openAutomationPrivacySettings() {
        controller.openAutomationPrivacySettings()
    }

    @objc private func launchAmphetamineNow() {
        controller.launchAmphetamineNow()
    }

    @objc private func restoreBrightnessNow() {
        controller.restoreBrightnessNow()
    }

    @objc private func openSettings() {
        controller.openSettings()
    }

    @objc private func quit() {
        controller.requestQuit()
    }
}
