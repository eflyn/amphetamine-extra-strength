import AppKit
import Foundation
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: UtilityController?
    private var menuBarController: MenuBarController?
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.eflyn.AmphetamineExtraStrength",
        category: "lifecycle"
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = UtilityController()
        let menuBarController = MenuBarController(controller: controller)
        let settingsWindowController = SettingsWindowController(controller: controller)

        controller.onOpenSettings = { [weak settingsWindowController] in
            settingsWindowController?.show()
        }

        self.controller = controller
        self.menuBarController = menuBarController
        self.settingsWindowController = settingsWindowController

        controller.start()
        logger.info("Application finished launching as a menu-bar accessory")

        if !controller.settings.completedOnboarding {
            let onboardingWindowController = OnboardingWindowController(
                controller: controller
            )
            self.onboardingWindowController = onboardingWindowController
            onboardingWindowController.show()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        controller?.prepareForSystemTermination()
        logger.info("Application is terminating")
        return .terminateNow
    }
}

@main
enum AmphetamineExtraStrengthApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
