import SwiftUI

struct OnboardingView: View {
    @ObservedObject var controller: UtilityController
    @ObservedObject private var settings: SettingsStore
    let finish: () -> Void

    init(controller: UtilityController, finish: @escaping () -> Void) {
        self.controller = controller
        self.finish = finish
        settings = controller.settings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "sun.min.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Amphetamine Extra Strength")
                        .font(.title2.bold())
                    Text("A quiet helper for closed-lid sessions")
                        .foregroundStyle(.secondary)
                }
            }

            Text(
                "When an Amphetamine session is keeping your Mac awake and the lid closes, this utility saves the built-in display brightness, sets it to zero, and restores it as soon as those conditions end."
            )
            .fixedSize(horizontal: false, vertical: true)

            statusRow(
                title: "Amphetamine",
                value: controller.snapshot.installation.label,
                symbol: controller.snapshot.installation == .notInstalled
                    ? "xmark.circle.fill"
                    : "checkmark.circle.fill"
            )

            Toggle(
                "Launch Amphetamine automatically when needed",
                isOn: $settings.automaticallyLaunchAmphetamine
            )

            Toggle(
                "Launch this utility when I log in",
                isOn: Binding(
                    get: {
                        controller.loginItemState == .enabled
                            || controller.loginItemState == .requiresApproval
                    },
                    set: { controller.setLaunchAtLogin($0) }
                )
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Amphetamine session access")
                    .font(.headline)
                Text(
                    "macOS Automation access lets this utility ask one read-only question: whether an Amphetamine session is active. It cannot create, stop, or change sessions. You can continue without access and choose “whenever Amphetamine is running” in Settings."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                if case .unavailable(.permissionDenied) = controller.snapshot.session {
                    Button("Open Automation Privacy Settings…") {
                        controller.openAutomationPrivacySettings()
                    }
                } else if controller.snapshot.session != .active
                            && controller.snapshot.session != .inactive {
                    Button("Allow Session Checking…") {
                        controller.requestSessionAccess()
                    }
                    .disabled(!controller.snapshot.amphetamineRunning)
                } else {
                    Label("Session checking is available", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            HStack {
                Text("These choices can be changed later from the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done") {
                    finish()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26)
        .frame(width: 560)
    }

    private func statusRow(title: String, value: String, symbol: String) -> some View {
        HStack {
            Image(systemName: symbol)
                .foregroundStyle(
                    controller.snapshot.installation == .notInstalled ? .red : .green
                )
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let controller: UtilityController
    private var didFinish = false

    init(controller: UtilityController) {
        self.controller = controller
        let weakBox = WeakOnboardingWindowBox()

        let hostingController = NSHostingController(
            rootView: OnboardingView(
                controller: controller,
                finish: {
                    weakBox.windowController?.finish()
                }
            )
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false

        super.init(window: window)
        weakBox.windowController = self
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
        completeIfNeeded()
        NSApp.setActivationPolicy(.accessory)
    }

    private func finish() {
        completeIfNeeded()
        close()
        NSApp.setActivationPolicy(.accessory)
    }

    private func completeIfNeeded() {
        guard !didFinish else {
            return
        }
        didFinish = true
        controller.completeOnboarding()
    }
}

@MainActor
private final class WeakOnboardingWindowBox {
    weak var windowController: OnboardingWindowController?
}
