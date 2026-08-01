import Foundation
import KeyboardBacklightBridge
import os

enum KeyboardBacklightControlError: LocalizedError {
    case unavailable
    case readFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Built-in keyboard backlight unavailable"
        case .readFailed:
            return "Built-in keyboard backlight could not be read"
        case .writeFailed:
            return "Built-in keyboard backlight could not be changed"
        }
    }
}

final class SystemKeyboardBacklightService: BrightnessControlling {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.dawar.AmphetamineExtraStrength",
        category: "keyboard-backlight"
    )
    private var handle: AESKeyboardBacklightHandle?

    init() {
        handle = AESKeyboardBacklightCreate()
        if let handle {
            var initialBrightness: Float = 0
            if AESKeyboardBacklightCopyBrightness(handle, &initialBrightness) != 0 {
                logger.info(
                    "Keyboard backlight service initialized; built-in keyboard backlight found with brightness \(initialBrightness, privacy: .public)"
                )
            } else {
                logger.error(
                    "Keyboard backlight service found the built-in keyboard but could not read its initial brightness"
                )
            }
        } else {
            logger.error(
                "Keyboard backlight service could not find a controllable built-in keyboard backlight"
            )
        }
    }

    deinit {
        if let handle {
            AESKeyboardBacklightDestroy(handle)
        }
    }

    func currentBrightness() throws -> Float {
        guard let handle else {
            throw KeyboardBacklightControlError.unavailable
        }

        var brightness: Float = 0
        guard AESKeyboardBacklightCopyBrightness(handle, &brightness) != 0 else {
            logger.error("CoreBrightness could not read the built-in keyboard backlight")
            throw KeyboardBacklightControlError.readFailed
        }
        return min(max(brightness, 0), 1)
    }

    func setBrightness(_ brightness: Float) throws {
        guard let handle else {
            throw KeyboardBacklightControlError.unavailable
        }

        let clampedBrightness = min(max(brightness, 0), 1)
        guard AESKeyboardBacklightSetBrightness(handle, clampedBrightness) != 0 else {
            logger.error(
                "CoreBrightness could not set built-in keyboard backlight to \(clampedBrightness, privacy: .public)"
            )
            throw KeyboardBacklightControlError.writeFailed
        }

        logger.info(
            "Changed built-in keyboard backlight brightness to \(clampedBrightness, privacy: .public)"
        )
    }
}
