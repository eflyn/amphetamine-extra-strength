import Darwin
import Foundation

@main
struct BrightnessGuardTests {
    private static var failures = 0

    static func main() {
        run(
            "Dimming happens once and never replaces the saved brightness with zero",
            dimsOnceAndNeverReplacesSavedBrightnessWithZero
        )
        run("An existing zero is never claimed", doesNotClaimBrightnessThatWasAlreadyZero)
        run("Brightness restores only once", restoresOnlyOnceWhenConditionsEnd)
        run(
            "A manual adjustment relinquishes ownership and suppresses re-dimming",
            manualAdjustmentRelinquishesOwnershipAndSuppressesRedimming
        )
        run("A failed restore stays pending and retries", failedRestoreRemainsPendingAndRetriesLater)
        run(
            "A crash recovery record is restored before a new dim",
            crashRecoveryRecordIsRestoredBeforeNewDimming
        )
        run(
            "Display and keyboard ownership remain independent",
            displayAndKeyboardOwnershipRemainIndependent
        )

        if failures == 0 {
            print("All 7 brightness guard tests passed.")
        } else {
            fputs("\(failures) brightness guard test(s) failed.\n", stderr)
            exit(1)
        }
    }

    static func dimsOnceAndNeverReplacesSavedBrightnessWithZero() throws {
        let brightness = MockBrightnessController(brightness: 0.72)
        let recovery = MockRecoveryStore()
        let guardUnderTest = BrightnessGuard(
            controller: brightness,
            recoveryStore: recovery
        )

        guardUnderTest.reconcile(shouldDim: true)
        guardUnderTest.reconcile(shouldDim: true)

        try expect(brightness.setRequests == [0], "Expected exactly one zero write")
        try expect(
            abs((recovery.savedBrightness ?? 0) - 0.72) < 0.0001,
            "Expected the original brightness to remain saved"
        )
        try expect(
            guardUnderTest.state == .dimmed(savedBrightness: 0.72),
            "Expected owned dim state"
        )
    }

    static func doesNotClaimBrightnessThatWasAlreadyZero() throws {
        let brightness = MockBrightnessController(brightness: 0)
        let recovery = MockRecoveryStore()
        let guardUnderTest = BrightnessGuard(
            controller: brightness,
            recoveryStore: recovery
        )

        guardUnderTest.reconcile(shouldDim: true)

        try expect(brightness.setRequests.isEmpty, "Expected no brightness write")
        try expect(recovery.savedBrightness == nil, "Expected no recovery record")
        try expect(guardUnderTest.state == .idle, "Expected idle state")
    }

    static func restoresOnlyOnceWhenConditionsEnd() throws {
        let brightness = MockBrightnessController(brightness: 0.61)
        let recovery = MockRecoveryStore()
        let guardUnderTest = BrightnessGuard(
            controller: brightness,
            recoveryStore: recovery
        )

        guardUnderTest.reconcile(shouldDim: true)
        guardUnderTest.reconcile(shouldDim: false)
        guardUnderTest.reconcile(shouldDim: false)

        try expect(
            brightness.setRequests == [0, 0.61],
            "Expected one dim and one restore write"
        )
        try expect(recovery.savedBrightness == nil, "Expected recovery to clear")
        try expect(guardUnderTest.state == .idle, "Expected idle state")
    }

    static func manualAdjustmentRelinquishesOwnershipAndSuppressesRedimming() throws {
        let brightness = MockBrightnessController(brightness: 0.84)
        let recovery = MockRecoveryStore()
        let guardUnderTest = BrightnessGuard(
            controller: brightness,
            recoveryStore: recovery
        )

        guardUnderTest.reconcile(shouldDim: true)
        brightness.brightness = 0.33
        guardUnderTest.reconcile(shouldDim: true)
        guardUnderTest.reconcile(shouldDim: true)

        try expect(brightness.setRequests == [0], "Expected no second dim write")
        try expect(
            abs(brightness.brightness - 0.33) < 0.0001,
            "Expected the manual value to remain"
        )
        try expect(recovery.savedBrightness == nil, "Expected ownership to clear")
        try expect(
            guardUnderTest.isSuppressedForCurrentConditionCycle,
            "Expected suppression for the current cycle"
        )

        guardUnderTest.reconcile(shouldDim: false)
        try expect(
            !guardUnderTest.isSuppressedForCurrentConditionCycle,
            "Expected suppression to reset"
        )
    }

    static func failedRestoreRemainsPendingAndRetriesLater() throws {
        let brightness = MockBrightnessController(brightness: 0.45)
        let recovery = MockRecoveryStore()
        let guardUnderTest = BrightnessGuard(
            controller: brightness,
            recoveryStore: recovery
        )

        guardUnderTest.reconcile(shouldDim: true)
        brightness.nextSetError = .writeFailed(-1)
        guardUnderTest.reconcile(shouldDim: false)

        try expect(
            guardUnderTest.state == .restorePending(savedBrightness: 0.45),
            "Expected restore-pending state"
        )
        try expect(
            abs((recovery.savedBrightness ?? 0) - 0.45) < 0.0001,
            "Expected recovery record to remain"
        )

        guardUnderTest.reconcile(shouldDim: false)

        try expect(guardUnderTest.state == .idle, "Expected eventual idle state")
        try expect(
            abs(brightness.brightness - 0.45) < 0.0001,
            "Expected eventual restoration"
        )
        try expect(recovery.savedBrightness == nil, "Expected recovery to clear")
    }

    static func crashRecoveryRecordIsRestoredBeforeNewDimming() throws {
        let brightness = MockBrightnessController(brightness: 0)
        let recovery = MockRecoveryStore(savedBrightness: 0.69)
        let guardUnderTest = BrightnessGuard(
            controller: brightness,
            recoveryStore: recovery
        )

        guardUnderTest.reconcile(shouldDim: true)

        try expect(
            brightness.setRequests == [0.69],
            "Expected restoration before any new dim"
        )
        try expect(
            abs(brightness.brightness - 0.69) < 0.0001,
            "Expected the crash recovery value"
        )
        try expect(guardUnderTest.state == .idle, "Expected idle state")
        try expect(recovery.savedBrightness == nil, "Expected recovery to clear")
    }

    static func displayAndKeyboardOwnershipRemainIndependent() throws {
        let display = MockBrightnessController(brightness: 0.76)
        let keyboard = MockBrightnessController(brightness: 0.42)
        let displayRecovery = MockRecoveryStore()
        let keyboardRecovery = MockRecoveryStore()
        let displayGuard = BrightnessGuard(
            controller: display,
            recoveryStore: displayRecovery,
            resourceName: "built-in display"
        )
        let keyboardGuard = BrightnessGuard(
            controller: keyboard,
            recoveryStore: keyboardRecovery,
            resourceName: "built-in keyboard backlight"
        )

        displayGuard.reconcile(shouldDim: true)
        keyboardGuard.reconcile(shouldDim: true)
        keyboard.brightness = 0.21
        keyboardGuard.reconcile(shouldDim: true)
        displayGuard.reconcile(shouldDim: false)
        keyboardGuard.reconcile(shouldDim: false)

        try expect(
            display.setRequests == [0, 0.76],
            "Expected display to dim and restore independently"
        )
        try expect(
            keyboard.setRequests == [0],
            "Expected the keyboard manual override to remain untouched"
        )
        try expect(
            abs(keyboard.brightness - 0.21) < 0.0001,
            "Expected the keyboard manual value to remain"
        )
        try expect(
            displayRecovery.savedBrightness == nil
                && keyboardRecovery.savedBrightness == nil,
            "Expected both ownership records to clear independently"
        )
    }

    private static func run(
        _ name: String,
        _ test: () throws -> Void
    ) {
        do {
            try test()
            print("✓ \(name)")
        } catch {
            failures += 1
            fputs("✗ \(name): \(error)\n", stderr)
        }
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        guard condition() else {
            throw TestFailure(message: message)
        }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

private final class MockBrightnessController: BrightnessControlling {
    var brightness: Float
    var nextReadError: BrightnessControlError?
    var nextSetError: BrightnessControlError?
    private(set) var setRequests: [Float] = []

    init(brightness: Float) {
        self.brightness = brightness
    }

    func currentBrightness() throws -> Float {
        if let error = nextReadError {
            nextReadError = nil
            throw error
        }
        return brightness
    }

    func setBrightness(_ brightness: Float) throws {
        setRequests.append(brightness)
        if let error = nextSetError {
            nextSetError = nil
            throw error
        }
        self.brightness = brightness
    }
}

private final class MockRecoveryStore: BrightnessRecoveryStoring {
    private(set) var savedBrightness: Float?

    init(savedBrightness: Float? = nil) {
        self.savedBrightness = savedBrightness
    }

    func save(_ brightness: Float) {
        savedBrightness = brightness
    }

    func clear() {
        savedBrightness = nil
    }
}
