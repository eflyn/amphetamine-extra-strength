import Foundation
import IOKit
import os

protocol LidStateReading: AnyObject {
    func currentLidState() -> LidState
}

final class SystemLidStateService: LidStateReading {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.dawar.AmphetamineExtraStrength",
        category: "lid"
    )

    func currentLidState() -> LidState {
        let matchingDictionary = IOServiceMatching("IOPMrootDomain")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matchingDictionary)
        guard service != IO_OBJECT_NULL else {
            logger.error("IOPMrootDomain is unavailable; lid state cannot be read")
            return .unavailable
        }
        defer { IOObjectRelease(service) }

        guard let property = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else {
            logger.error("AppleClamshellState is unavailable in IOPMrootDomain")
            return .unavailable
        }

        guard CFGetTypeID(property) == CFBooleanGetTypeID() else {
            logger.error("AppleClamshellState had an unexpected type")
            return .unavailable
        }

        return CFBooleanGetValue((property as! CFBoolean)) ? .closed : .open
    }
}
