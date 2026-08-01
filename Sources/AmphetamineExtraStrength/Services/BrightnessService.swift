import CoreGraphics
import Darwin
import Foundation
import os

protocol BrightnessControlling: AnyObject {
    func builtInBrightness() -> Result<Float, BrightnessControlError>
    func setBuiltInBrightness(_ brightness: Float) -> Result<Void, BrightnessControlError>
}

enum BrightnessControlError: LocalizedError, Equatable {
    case builtInDisplayUnavailable
    case displayServicesUnavailable
    case readFailed(Int32)
    case writeFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .builtInDisplayUnavailable:
            return "Built-in display brightness unavailable"
        case .displayServicesUnavailable:
            return "Brightness control is unavailable on this version of macOS"
        case .readFailed:
            return "Built-in display brightness could not be read"
        case .writeFailed:
            return "Built-in display brightness could not be changed"
        }
    }
}

final class SystemBrightnessService: BrightnessControlling {
    private typealias GetBrightnessFunction = @convention(c) (
        CGDirectDisplayID,
        UnsafeMutablePointer<Float>
    ) -> Int32

    private typealias SetBrightnessFunction = @convention(c) (
        CGDirectDisplayID,
        Float
    ) -> Int32

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.dawar.AmphetamineExtraStrength",
        category: "brightness"
    )

    private var frameworkHandle: UnsafeMutableRawPointer?
    private var getBrightnessFunction: GetBrightnessFunction?
    private var setBrightnessFunction: SetBrightnessFunction?
    private var cachedBuiltInDisplayID: CGDirectDisplayID?

    init() {
        loadDisplayServices()
        cachedBuiltInDisplayID = findBuiltInDisplayID()
        logger.info(
            "Brightness service initialized; DisplayServices loaded: \(self.frameworkHandle != nil, privacy: .public), built-in display found: \(self.cachedBuiltInDisplayID != nil, privacy: .public)"
        )
    }

    deinit {
        if let frameworkHandle {
            dlclose(frameworkHandle)
        }
    }

    func builtInBrightness() -> Result<Float, BrightnessControlError> {
        guard let getBrightnessFunction else {
            return .failure(.displayServicesUnavailable)
        }
        guard let displayID = builtInDisplayID() else {
            return .failure(.builtInDisplayUnavailable)
        }

        var brightness: Float = 0
        let result = getBrightnessFunction(displayID, &brightness)
        guard result == 0 else {
            logger.error(
                "DisplayServicesGetBrightness failed for built-in display \(displayID, privacy: .public) with status \(result, privacy: .public)"
            )
            return .failure(.readFailed(result))
        }
        return .success(min(max(brightness, 0), 1))
    }

    func setBuiltInBrightness(_ brightness: Float) -> Result<Void, BrightnessControlError> {
        guard let setBrightnessFunction else {
            return .failure(.displayServicesUnavailable)
        }
        guard let displayID = builtInDisplayID() else {
            return .failure(.builtInDisplayUnavailable)
        }

        let clampedBrightness = min(max(brightness, 0), 1)
        let result = setBrightnessFunction(displayID, clampedBrightness)
        guard result == 0 else {
            logger.error(
                "DisplayServicesSetBrightness failed for built-in display \(displayID, privacy: .public), requested brightness \(clampedBrightness, privacy: .public), status \(result, privacy: .public)"
            )
            return .failure(.writeFailed(result))
        }

        logger.info(
            "Changed built-in display \(displayID, privacy: .public) brightness to \(clampedBrightness, privacy: .public)"
        )
        return .success(())
    }

    private func builtInDisplayID() -> CGDirectDisplayID? {
        if let current = findBuiltInDisplayID() {
            cachedBuiltInDisplayID = current
            return current
        }

        // The built-in display can disappear from the online list while the lid is
        // closed. Its stable CoreGraphics ID remains usable for restoration later.
        return cachedBuiltInDisplayID
    }

    private func findBuiltInDisplayID() -> CGDirectDisplayID? {
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            return nil
        }

        var displayIDs = Array(repeating: CGDirectDisplayID(), count: Int(displayCount))
        guard CGGetOnlineDisplayList(displayCount, &displayIDs, &displayCount) == .success else {
            return nil
        }

        return displayIDs.prefix(Int(displayCount)).first { displayID in
            CGDisplayIsBuiltin(displayID) != 0
        }
    }

    private func loadDisplayServices() {
        let frameworkPaths = [
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            "/System/Library/PrivateFrameworks/DisplayServices.framework/Versions/A/DisplayServices"
        ]

        for path in frameworkPaths {
            if let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) {
                frameworkHandle = handle
                break
            }
        }

        guard let frameworkHandle else {
            if let error = dlerror() {
                logger.error(
                    "Unable to load DisplayServices: \(String(cString: error), privacy: .public)"
                )
            }
            return
        }

        if let symbol = dlsym(frameworkHandle, "DisplayServicesGetBrightness") {
            getBrightnessFunction = unsafeBitCast(symbol, to: GetBrightnessFunction.self)
        }
        if let symbol = dlsym(frameworkHandle, "DisplayServicesSetBrightness") {
            setBrightnessFunction = unsafeBitCast(symbol, to: SetBrightnessFunction.self)
        }

        if getBrightnessFunction == nil || setBrightnessFunction == nil {
            logger.error("DisplayServices is missing one or more required brightness functions")
        }
    }
}
