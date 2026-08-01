import AppKit
import Foundation
import os

protocol AmphetamineServicing: AnyObject {
    func installedApplicationURL() -> URL?
    func isRunning() -> Bool
    func sessionState(accessRequested: Bool) -> AmphetamineSessionState
    func launch(completion: @escaping (Result<Void, Error>) -> Void)
}

final class SystemAmphetamineService: AmphetamineServicing {
    static let bundleIdentifier = "com.if.Amphetamine"

    private let workspace: NSWorkspace
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.eflyn.AmphetamineExtraStrength",
        category: "amphetamine"
    )
    private lazy var sessionScript: NSAppleScript? = {
        let source = """
        with timeout of 2 seconds
            tell application id "\(Self.bundleIdentifier)" to session is active
        end timeout
        """
        return NSAppleScript(source: source)
    }()
    private var lastSessionErrorNumber: Int?

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func installedApplicationURL() -> URL? {
        workspace.urlForApplication(withBundleIdentifier: Self.bundleIdentifier)
    }

    func isRunning() -> Bool {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.bundleIdentifier
        ).isEmpty
    }

    func sessionState(accessRequested: Bool) -> AmphetamineSessionState {
        guard accessRequested else {
            return .unavailable(.permissionRequired)
        }
        guard isRunning() else {
            return .notRunning
        }

        guard let script = sessionScript else {
            logger.error("Could not construct the read-only Amphetamine session script")
            return .unavailable(.error("Could not create session query"))
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let errorNumber = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown Apple event error"
            if lastSessionErrorNumber == errorNumber {
                logger.debug(
                    "Amphetamine session query remains unavailable with AppleScript error \(errorNumber, privacy: .public)"
                )
            } else {
                logger.error(
                    "Amphetamine session query failed with AppleScript error \(errorNumber, privacy: .public): \(message, privacy: .public)"
                )
            }
            lastSessionErrorNumber = errorNumber

            switch errorNumber {
            case -1743:
                return .unavailable(.permissionDenied)
            case -1712:
                return .unavailable(.timedOut)
            default:
                return .unavailable(.error(message))
            }
        }

        lastSessionErrorNumber = nil
        return result.booleanValue ? .active : .inactive
    }

    func launch(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let applicationURL = installedApplicationURL() else {
            completion(.failure(AmphetamineLaunchError.notInstalled))
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.hides = true

        logger.info("Requesting a background launch of Amphetamine at \(applicationURL.path, privacy: .public)")
        workspace.openApplication(
            at: applicationURL,
            configuration: configuration
        ) { runningApplication, error in
            if let error {
                completion(.failure(error))
            } else if runningApplication == nil {
                completion(.failure(AmphetamineLaunchError.noRunningApplicationReturned))
            } else {
                completion(.success(()))
            }
        }
    }
}

enum AmphetamineLaunchError: LocalizedError {
    case notInstalled
    case noRunningApplicationReturned

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Amphetamine is not installed"
        case .noRunningApplicationReturned:
            return "macOS did not confirm that Amphetamine launched"
        }
    }
}
