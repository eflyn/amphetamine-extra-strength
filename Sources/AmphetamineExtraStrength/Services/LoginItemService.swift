import AppKit
import Foundation
import ServiceManagement
import os

enum LoginItemState: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable

    var label: String {
        switch self {
        case .enabled:
            return "Enabled"
        case .disabled:
            return "Disabled"
        case .requiresApproval:
            return "Needs approval in System Settings"
        case .unavailable:
            return "Unavailable"
        }
    }
}

@MainActor
final class LoginItemService {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.eflyn.AmphetamineExtraStrength",
        category: "login-item"
    )

    var state: LoginItemState {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    func setEnabled(_ enabled: Bool) -> Result<LoginItemState, Error> {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            let currentState = state
            logger.info(
                "Updated launch-at-login registration; requested enabled: \(enabled, privacy: .public), resulting state: \(currentState.label, privacy: .public)"
            )
            return .success(currentState)
        } catch {
            logger.error(
                "Could not update launch-at-login registration to \(enabled, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return .failure(error)
        }
    }

    func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
