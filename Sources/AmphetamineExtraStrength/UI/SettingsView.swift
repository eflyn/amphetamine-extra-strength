import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: UtilityController
    @ObservedObject private var settings: SettingsStore

    init(controller: UtilityController) {
        self.controller = controller
        settings = controller.settings
    }

    var body: some View {
        Form {
            Section("Amphetamine") {
                Toggle(
                    "Automatically launch Amphetamine",
                    isOn: $settings.automaticallyLaunchAmphetamine
                )
                Toggle(
                    "Relaunch Amphetamine if it quits",
                    isOn: $settings.relaunchAmphetamine
                )
                .disabled(!settings.automaticallyLaunchAmphetamine)

                LabeledContent("Installation", value: controller.snapshot.installation.label)
                LabeledContent(
                    "Running",
                    value: controller.snapshot.amphetamineRunning ? "Yes" : "No"
                )
                LabeledContent("Session", value: controller.snapshot.session.label)

                HStack {
                    Button("Launch Amphetamine Now") {
                        controller.launchAmphetamineNow()
                    }
                    .disabled(
                        controller.snapshot.installation == .notInstalled
                            || controller.snapshot.amphetamineRunning
                    )

                    sessionAccessButton
                }
            }

            Section("Built-in display") {
                Toggle(
                    "Dim the display when the lid is closed",
                    isOn: $settings.dimWhenLidClosed
                )
                Toggle(
                    "Require an active Amphetamine session",
                    isOn: $settings.requireActiveSession
                )

                LabeledContent("MacBook lid", value: controller.snapshot.lid.label)
                LabeledContent(
                    "Current brightness",
                    value: percentLabel(controller.snapshot.builtInBrightness)
                )
                LabeledContent(
                    "Dimmed by this utility",
                    value: controller.snapshot.hasDisplayDimmed ? "Yes" : "No"
                )
                if let saved = controller.snapshot.brightnessOwnership.savedBrightness {
                    LabeledContent("Saved brightness", value: percentLabel(saved))
                }

                Button("Restore Brightness Now") {
                    controller.restoreBrightnessNow()
                }
                .disabled(!controller.snapshot.brightnessOwnership.isOwned)
            }

            Section("Background operation") {
                Toggle(
                    "Launch the utility when I log in",
                    isOn: Binding(
                        get: {
                            controller.loginItemState == .enabled
                                || controller.loginItemState == .requiresApproval
                        },
                        set: { controller.setLaunchAtLogin($0) }
                    )
                )
                Toggle(
                    "Restore brightness when the utility exits",
                    isOn: $settings.restoreBrightnessOnExit
                )

                LabeledContent("Launch at login", value: controller.loginItemState.label)
                if controller.loginItemState == .requiresApproval {
                    Button("Open Login Items Settings…") {
                        controller.openLoginItemSettings()
                    }
                }
                if let error = controller.loginItemError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            }

            if let error = controller.snapshot.launchError
                ?? controller.snapshot.brightnessError
            {
                Section("Needs attention") {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 620)
        .padding()
    }

    @ViewBuilder
    private var sessionAccessButton: some View {
        switch controller.snapshot.session {
        case .unavailable(.permissionRequired):
            Button("Allow Session Checking…") {
                controller.requestSessionAccess()
            }
            .help(
                "Allows this utility to ask Amphetamine whether a session is active. It cannot start or stop sessions."
            )
        case .unavailable(.permissionDenied):
            Button("Open Automation Privacy Settings…") {
                controller.openAutomationPrivacySettings()
            }
        default:
            EmptyView()
        }
    }

    private func percentLabel(_ brightness: Float?) -> String {
        guard let brightness else {
            return "Unavailable"
        }
        return "\(Int((brightness * 100).rounded()))%"
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init(controller: UtilityController) {
        let hostingController = NSHostingController(
            rootView: SettingsView(controller: controller)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Amphetamine Extra Strength Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        showWindow(nil)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
