import Foundation

enum AmphetamineInstallationState: Equatable {
    case installed(URL)
    case notInstalled

    var label: String {
        switch self {
        case .installed:
            return "Installed"
        case .notInstalled:
            return "Not installed"
        }
    }
}

enum AmphetamineSessionState: Equatable {
    case active
    case inactive
    case unavailable(SessionUnavailableReason)
    case notRunning
    case notInstalled

    var label: String {
        switch self {
        case .active:
            return "Active"
        case .inactive:
            return "No active session"
        case .unavailable(let reason):
            return reason.label
        case .notRunning:
            return "Unavailable — Amphetamine is not running"
        case .notInstalled:
            return "Unavailable — Amphetamine is not installed"
        }
    }
}

enum SessionUnavailableReason: Equatable {
    case permissionRequired
    case permissionDenied
    case timedOut
    case error(String)

    var label: String {
        switch self {
        case .permissionRequired:
            return "Permission required"
        case .permissionDenied:
            return "Permission denied"
        case .timedOut:
            return "Unavailable — request timed out"
        case .error:
            return "Unavailable"
        }
    }
}

enum LidState: Equatable {
    case open
    case closed
    case unavailable

    var label: String {
        switch self {
        case .open:
            return "Open"
        case .closed:
            return "Closed"
        case .unavailable:
            return "Unavailable"
        }
    }
}

enum BrightnessOwnershipState: Equatable {
    case idle
    case dimmed(savedBrightness: Float)
    case restorePending(savedBrightness: Float)

    var savedBrightness: Float? {
        switch self {
        case .idle:
            return nil
        case .dimmed(let saved), .restorePending(let saved):
            return saved
        }
    }

    var isOwned: Bool {
        if case .idle = self {
            return false
        }
        return true
    }
}

struct UtilitySnapshot: Equatable {
    var installation: AmphetamineInstallationState = .notInstalled
    var amphetamineRunning = false
    var session: AmphetamineSessionState = .notInstalled
    var lid: LidState = .unavailable
    var builtInBrightness: Float?
    var brightnessOwnership: BrightnessOwnershipState = .idle
    var launchError: String?
    var brightnessError: String?
    var isMonitoring = false

    var utilityStatus: String {
        if case .restorePending = brightnessOwnership {
            return "Waiting to restore brightness"
        }
        if let brightnessError {
            return brightnessError
        }
        if let launchError {
            return launchError
        }
        return isMonitoring ? "Monitoring" : "Starting"
    }

    var hasDisplayDimmed: Bool {
        if case .dimmed = brightnessOwnership {
            return true
        }
        return false
    }
}

enum RefreshReason: String {
    case startup
    case timer
    case settingsChanged
    case applicationChanged
    case wake
    case screenConfiguration
    case sessionChanged
    case manual
}
