import AppKit
import Combine
import Foundation
import os

@MainActor
final class UtilityController: ObservableObject {
    let settings: SettingsStore

    @Published private(set) var snapshot = UtilitySnapshot()
    @Published private(set) var loginItemState: LoginItemState
    @Published private(set) var loginItemError: String?

    var onOpenSettings: (() -> Void)?

    private let amphetamineService: AmphetamineServicing
    private let lidService: LidStateReading
    private let brightnessController: BrightnessControlling
    private let brightnessGuard: BrightnessGuard
    private let keyboardBacklightController: BrightnessControlling
    private let keyboardBacklightGuard: BrightnessGuard
    private let loginItemService: LoginItemService
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.dawar.AmphetamineExtraStrength",
        category: "monitor"
    )

    private var timer: Timer?
    private var notificationTokens: [NSObjectProtocol] = []
    private var settingsCancellable: AnyCancellable?
    private var refreshInProgress = false
    private var refreshQueued = false
    private var launchInProgress = false
    private var nextAutomaticLaunchAttempt = Date.distantPast
    private var consecutiveLaunchFailures = 0
    private var consecutiveRunningSamples = 0
    private var consecutiveActiveSessionSamples = 0
    private var hasObservedAmphetamineRunning = false
    private var pendingTermination = false

    init(
        settings: SettingsStore? = nil,
        amphetamineService: AmphetamineServicing = SystemAmphetamineService(),
        lidService: LidStateReading = SystemLidStateService(),
        brightnessController: BrightnessControlling = SystemBrightnessService(),
        recoveryStore: BrightnessRecoveryStoring = UserDefaultsBrightnessRecoveryStore(),
        keyboardBacklightController: BrightnessControlling = SystemKeyboardBacklightService(),
        keyboardBacklightRecoveryStore: BrightnessRecoveryStoring =
            UserDefaultsBrightnessRecoveryStore(
                keyPrefix: "keyboardBacklightRecovery"
            ),
        loginItemService: LoginItemService? = nil
    ) {
        let resolvedLoginItemService = loginItemService ?? LoginItemService()
        self.settings = settings ?? SettingsStore()
        self.amphetamineService = amphetamineService
        self.lidService = lidService
        self.brightnessController = brightnessController
        self.brightnessGuard = BrightnessGuard(
            controller: brightnessController,
            recoveryStore: recoveryStore
        )
        self.keyboardBacklightController = keyboardBacklightController
        self.keyboardBacklightGuard = BrightnessGuard(
            controller: keyboardBacklightController,
            recoveryStore: keyboardBacklightRecoveryStore,
            resourceName: "built-in keyboard backlight"
        )
        self.loginItemService = resolvedLoginItemService
        self.loginItemState = resolvedLoginItemService.state
    }

    func start() {
        guard timer == nil else {
            return
        }

        logger.info(
            "Starting monitor with auto-launch \(self.settings.automaticallyLaunchAmphetamine, privacy: .public), relaunch \(self.settings.relaunchAmphetamine, privacy: .public), auto-dim \(self.settings.dimWhenLidClosed, privacy: .public), require active session \(self.settings.requireActiveSession, privacy: .public)"
        )

        installNotifications()
        if settings.launchAtLogin, loginItemService.state == .disabled {
            switch loginItemService.setEnabled(true) {
            case .success(let state):
                loginItemState = state
            case .failure(let error):
                loginItemError =
                    "Launch at login could not be restored: \(error.localizedDescription)"
            }
        }
        settingsCancellable = settings.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.refresh(reason: .settingsChanged)
            }
        }

        // Recover any persisted ownership record before considering a new dim.
        brightnessGuard.reconcile(shouldDim: false)
        keyboardBacklightGuard.reconcile(shouldDim: false)
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(reason: .timer)
            }
        }
        timer?.tolerance = 0.5
        refresh(reason: .startup)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        settingsCancellable = nil
        notificationTokens.forEach {
            NotificationCenter.default.removeObserver($0)
            NSWorkspace.shared.notificationCenter.removeObserver($0)
        }
        notificationTokens.removeAll()
        snapshot.isMonitoring = false
    }

    func refresh(reason: RefreshReason) {
        if refreshInProgress {
            refreshQueued = true
            return
        }

        refreshInProgress = true
        defer {
            refreshInProgress = false
            if refreshQueued {
                refreshQueued = false
                DispatchQueue.main.async { [weak self] in
                    self?.refresh(reason: .manual)
                }
            }
        }

        let installedURL = amphetamineService.installedApplicationURL()
        let isRunning = installedURL != nil && amphetamineService.isRunning()

        if isRunning {
            hasObservedAmphetamineRunning = true
            consecutiveRunningSamples += 1
            consecutiveLaunchFailures = 0
            snapshot.launchError = nil
        } else {
            consecutiveRunningSamples = 0
        }
        if installedURL == nil {
            snapshot.launchError = nil
        }

        let sessionState: AmphetamineSessionState
        if installedURL == nil {
            sessionState = .notInstalled
            consecutiveActiveSessionSamples = 0
        } else if !isRunning {
            sessionState = .notRunning
            consecutiveActiveSessionSamples = 0
        } else {
            sessionState = amphetamineService.sessionState(
                accessRequested: settings.sessionAccessRequested
            )
            if sessionState == .active {
                consecutiveActiveSessionSamples += 1
            } else {
                consecutiveActiveSessionSamples = 0
            }
        }

        let lidState = lidService.currentLidState()
        maybeLaunchAmphetamine(installedURL: installedURL, isRunning: isRunning)

        let amphetamineMeetsRequirement: Bool
        if settings.requireActiveSession {
            // Two consecutive positive samples prevent a transient application
            // launch or stale Apple event reply from triggering a dim.
            amphetamineMeetsRequirement =
                sessionState == .active && consecutiveActiveSessionSamples >= 2
        } else {
            amphetamineMeetsRequirement =
                isRunning && consecutiveRunningSamples >= 2
        }

        let shouldDim =
            !pendingTermination
            && settings.dimWhenLidClosed
            && lidState == .closed
            && amphetamineMeetsRequirement

        brightnessGuard.reconcile(shouldDim: shouldDim)
        keyboardBacklightGuard.reconcile(shouldDim: shouldDim)

        var currentBrightness: Float?
        var brightnessReadError: String?
        do {
            currentBrightness = try brightnessController.currentBrightness()
        } catch {
            brightnessReadError = error.localizedDescription
        }

        var currentKeyboardBacklightBrightness: Float?
        var keyboardBacklightReadError: String?
        do {
            currentKeyboardBacklightBrightness =
                try keyboardBacklightController.currentBrightness()
        } catch {
            keyboardBacklightReadError = error.localizedDescription
        }

        snapshot.installation = installedURL.map {
            AmphetamineInstallationState.installed($0)
        } ?? .notInstalled
        snapshot.amphetamineRunning = isRunning
        snapshot.session = sessionState
        snapshot.lid = lidState
        snapshot.builtInBrightness = currentBrightness
        snapshot.brightnessOwnership = brightnessGuard.state
        snapshot.brightnessError = brightnessGuard.lastError ?? brightnessReadError
        snapshot.keyboardBacklightBrightness = currentKeyboardBacklightBrightness
        snapshot.keyboardBacklightOwnership = keyboardBacklightGuard.state
        snapshot.keyboardBacklightError =
            keyboardBacklightGuard.lastError ?? keyboardBacklightReadError
        snapshot.isMonitoring = true
        loginItemState = loginItemService.state

        logger.debug(
            "Refresh \(reason.rawValue, privacy: .public): installed \(installedURL != nil, privacy: .public), running \(isRunning, privacy: .public), running samples \(self.consecutiveRunningSamples, privacy: .public), session \(sessionState.label, privacy: .public), active samples \(self.consecutiveActiveSessionSamples, privacy: .public), lid \(lidState.label, privacy: .public), should dim \(shouldDim, privacy: .public), owns display brightness \(self.brightnessGuard.state.isOwned, privacy: .public), owns keyboard backlight \(self.keyboardBacklightGuard.state.isOwned, privacy: .public)"
        )

        if pendingTermination,
            !brightnessGuard.state.isOwned,
            !keyboardBacklightGuard.state.isOwned
        {
            logger.info(
                "Pending display and keyboard backlight restoration completed; terminating normally"
            )
            pendingTermination = false
            stop()
            NSApp.terminate(nil)
        }
    }

    func launchAmphetamineNow() {
        guard !launchInProgress else {
            return
        }
        nextAutomaticLaunchAttempt = .distantPast
        performAmphetamineLaunch(isManual: true)
    }

    func restoreBrightnessNow() {
        brightnessGuard.restoreNow()
        keyboardBacklightGuard.restoreNow()
        refresh(reason: .manual)
    }

    func requestSessionAccess() {
        settings.sessionAccessRequested = true
        refresh(reason: .manual)
    }

    func openAutomationPrivacySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        loginItemError = nil
        switch loginItemService.setEnabled(enabled) {
        case .success(let state):
            settings.launchAtLogin = enabled
            loginItemState = state
            if state == .requiresApproval {
                loginItemError = "Approve launch at login in System Settings."
            }
        case .failure(let error):
            settings.launchAtLogin = loginItemService.state == .enabled
            loginItemState = loginItemService.state
            loginItemError = "Launch at login could not be changed: \(error.localizedDescription)"
        }
    }

    func openLoginItemSettings() {
        loginItemService.openSystemSettings()
    }

    func openSettings() {
        onOpenSettings?()
    }

    func requestQuit() {
        guard !pendingTermination else {
            return
        }

        if settings.restoreBrightnessOnExit,
            brightnessGuard.state.isOwned || keyboardBacklightGuard.state.isOwned
        {
            brightnessGuard.restoreNow()
            keyboardBacklightGuard.restoreNow()
            if brightnessGuard.state.isOwned || keyboardBacklightGuard.state.isOwned {
                pendingTermination = true
                snapshot.brightnessOwnership = brightnessGuard.state
                snapshot.keyboardBacklightOwnership = keyboardBacklightGuard.state
                snapshot.brightnessError =
                    brightnessGuard.state.isOwned
                    ? "Waiting for the built-in display to restore brightness before quitting"
                    : nil
                snapshot.keyboardBacklightError =
                    keyboardBacklightGuard.state.isOwned
                    ? "Waiting for the keyboard backlight to restore before quitting"
                    : nil
                logger.warning(
                    "Normal quit deferred because display or keyboard backlight restoration is pending; monitoring will continue"
                )
                return
            }
        }

        stop()
        NSApp.terminate(nil)
    }

    func prepareForSystemTermination() {
        if settings.restoreBrightnessOnExit {
            brightnessGuard.restoreNow()
            keyboardBacklightGuard.restoreNow()
        }
        stop()
    }

    func completeOnboarding() {
        settings.completedOnboarding = true
    }

    private func maybeLaunchAmphetamine(installedURL: URL?, isRunning: Bool) {
        guard installedURL != nil, !isRunning, !launchInProgress else {
            return
        }
        guard settings.automaticallyLaunchAmphetamine else {
            return
        }

        let shouldKeepRunning =
            !hasObservedAmphetamineRunning || settings.relaunchAmphetamine
        guard shouldKeepRunning, Date() >= nextAutomaticLaunchAttempt else {
            return
        }

        performAmphetamineLaunch(isManual: false)
    }

    private func performAmphetamineLaunch(isManual: Bool) {
        launchInProgress = true
        let attemptDate = Date()
        nextAutomaticLaunchAttempt = attemptDate.addingTimeInterval(10)
        logger.info(
            "Launching Amphetamine; manual request: \(isManual, privacy: .public), prior consecutive failures: \(self.consecutiveLaunchFailures, privacy: .public)"
        )

        amphetamineService.launch { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.launchInProgress = false

                switch result {
                case .success:
                    self.consecutiveLaunchFailures = 0
                    self.snapshot.launchError = nil
                    self.nextAutomaticLaunchAttempt = Date().addingTimeInterval(10)
                    self.logger.info("Amphetamine background launch request succeeded")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                        self?.refresh(reason: .applicationChanged)
                    }
                case .failure(let error):
                    self.consecutiveLaunchFailures += 1
                    let exponent = min(self.consecutiveLaunchFailures - 1, 5)
                    let cooldown = min(120.0, 5.0 * pow(2.0, Double(exponent)))
                    self.nextAutomaticLaunchAttempt = Date().addingTimeInterval(cooldown)
                    self.snapshot.launchError =
                        "Amphetamine could not be launched: \(error.localizedDescription)"
                    self.logger.error(
                        "Amphetamine launch failed; retry cooldown \(cooldown, privacy: .public) seconds: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
    }

    private func installNotifications() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let center = NotificationCenter.default

        notificationTokens.append(
            workspaceCenter.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let application = notification.userInfo?[
                    NSWorkspace.applicationUserInfoKey
                ] as? NSRunningApplication,
                    application.bundleIdentifier == SystemAmphetamineService.bundleIdentifier
                else {
                    return
                }
                Task { @MainActor in
                    self?.refresh(reason: .applicationChanged)
                }
            }
        )

        notificationTokens.append(
            workspaceCenter.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let application = notification.userInfo?[
                    NSWorkspace.applicationUserInfoKey
                ] as? NSRunningApplication,
                    application.bundleIdentifier == SystemAmphetamineService.bundleIdentifier
                else {
                    return
                }
                Task { @MainActor in
                    self?.refresh(reason: .applicationChanged)
                }
            }
        )

        let workspaceEvents: [(Notification.Name, RefreshReason)] = [
            (NSWorkspace.didWakeNotification, .wake),
            (NSWorkspace.screensDidWakeNotification, .wake),
            (NSWorkspace.sessionDidBecomeActiveNotification, .sessionChanged),
            (NSWorkspace.sessionDidResignActiveNotification, .sessionChanged)
        ]

        for (name, reason) in workspaceEvents {
            notificationTokens.append(
                workspaceCenter.addObserver(
                    forName: name,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in
                        self?.refresh(reason: reason)
                    }
                }
            )
        }

        notificationTokens.append(
            center.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh(reason: .screenConfiguration)
                }
            }
        )
    }
}
