import Foundation
import os

protocol BrightnessRecoveryStoring: AnyObject {
    var savedBrightness: Float? { get }
    func save(_ brightness: Float)
    func clear()
}

final class UserDefaultsBrightnessRecoveryStore: BrightnessRecoveryStoring {
    private let defaults: UserDefaults
    private let ownershipKey = "brightnessRecovery.isOwned"
    private let savedBrightnessKey = "brightnessRecovery.savedBrightness"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var savedBrightness: Float? {
        guard defaults.bool(forKey: ownershipKey) else {
            return nil
        }
        return defaults.float(forKey: savedBrightnessKey)
    }

    func save(_ brightness: Float) {
        defaults.set(brightness, forKey: savedBrightnessKey)
        defaults.set(true, forKey: ownershipKey)
    }

    func clear() {
        defaults.removeObject(forKey: savedBrightnessKey)
        defaults.removeObject(forKey: ownershipKey)
    }
}

final class BrightnessGuard {
    private let controller: BrightnessControlling
    private let recoveryStore: BrightnessRecoveryStoring
    private let logger: Logger
    private let zeroThreshold: Float = 0.015

    private(set) var state: BrightnessOwnershipState
    private(set) var isSuppressedForCurrentConditionCycle = false
    private(set) var lastError: String?

    init(
        controller: BrightnessControlling,
        recoveryStore: BrightnessRecoveryStoring,
        logger: Logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.dawar.AmphetamineExtraStrength",
            category: "brightness-guard"
        )
    ) {
        self.controller = controller
        self.recoveryStore = recoveryStore
        self.logger = logger

        if let savedBrightness = recoveryStore.savedBrightness {
            state = .restorePending(savedBrightness: savedBrightness)
            logger.warning(
                "Found an unfinished brightness recovery record for \(savedBrightness, privacy: .public); restoration will be attempted before new dimming"
            )
        } else {
            state = .idle
        }
    }

    func reconcile(shouldDim: Bool) {
        lastError = nil

        if !shouldDim {
            isSuppressedForCurrentConditionCycle = false
            restoreIfNeeded(reason: "dimming conditions ended")
            return
        }

        switch state {
        case .dimmed(let savedBrightness):
            detectManualOverride(savedBrightness: savedBrightness)
        case .restorePending:
            // A stale recovery record always wins over a new dim request. This
            // prevents a crash/relaunch from replacing the original brightness.
            restoreIfNeeded(reason: "unfinished recovery before a new dim cycle")
        case .idle:
            guard !isSuppressedForCurrentConditionCycle else {
                return
            }
            dimIfPossible()
        }
    }

    func restoreNow() {
        lastError = nil
        isSuppressedForCurrentConditionCycle = true
        restoreIfNeeded(reason: "manual restore")
    }

    private func dimIfPossible() {
        switch controller.builtInBrightness() {
        case .failure(let error):
            lastError = error.localizedDescription
            logger.error("Cannot save brightness before dimming: \(error.localizedDescription, privacy: .public)")
        case .success(let currentBrightness):
            guard currentBrightness > zeroThreshold else {
                logger.debug(
                    "Built-in display is already at zero; no ownership or recovery record will be created"
                )
                return
            }

            // Persist ownership before changing hardware so a crash between the
            // write and the next monitor cycle can be recovered on next launch.
            recoveryStore.save(currentBrightness)
            switch controller.setBuiltInBrightness(0) {
            case .success:
                state = .dimmed(savedBrightness: currentBrightness)
                logger.info(
                    "Dimmed built-in display and saved original brightness \(currentBrightness, privacy: .public)"
                )
            case .failure(let error):
                recoveryStore.clear()
                state = .idle
                lastError = error.localizedDescription
                logger.error("Dimming failed; discarded ownership record: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func restoreIfNeeded(reason: String) {
        guard let savedBrightness = state.savedBrightness else {
            return
        }

        switch controller.builtInBrightness() {
        case .failure(let error):
            state = .restorePending(savedBrightness: savedBrightness)
            lastError = "Brightness restore pending"
            logger.error(
                "Brightness unavailable while restoring after \(reason, privacy: .public); will retry: \(error.localizedDescription, privacy: .public)"
            )
        case .success(let currentBrightness):
            if currentBrightness > zeroThreshold {
                // A user adjustment after our zero write takes precedence. We no
                // longer own the brightness and must not replace their value.
                recoveryStore.clear()
                state = .idle
                logger.info(
                    "Brightness is \(currentBrightness, privacy: .public), not zero; treating it as a manual adjustment and relinquishing ownership without restoration"
                )
                return
            }

            switch controller.setBuiltInBrightness(savedBrightness) {
            case .success:
                recoveryStore.clear()
                state = .idle
                logger.info(
                    "Restored built-in display brightness to \(savedBrightness, privacy: .public) after \(reason, privacy: .public)"
                )
            case .failure(let error):
                state = .restorePending(savedBrightness: savedBrightness)
                lastError = "Brightness could not be restored; retrying"
                logger.error(
                    "Brightness restoration to \(savedBrightness, privacy: .public) failed after \(reason, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func detectManualOverride(savedBrightness: Float) {
        switch controller.builtInBrightness() {
        case .failure:
            // The display often disappears temporarily during a clamshell or
            // display reconfiguration. Keep ownership and retry later.
            return
        case .success(let currentBrightness):
            guard currentBrightness > zeroThreshold else {
                return
            }
            recoveryStore.clear()
            state = .idle
            isSuppressedForCurrentConditionCycle = true
            logger.info(
                "Detected manual brightness change to \(currentBrightness, privacy: .public) while dimmed (saved value \(savedBrightness, privacy: .public)); suppressing dimming until conditions reset"
            )
        }
    }
}
