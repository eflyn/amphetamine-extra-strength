import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let automaticallyLaunchAmphetamine = "automaticallyLaunchAmphetamine"
        static let relaunchAmphetamine = "relaunchAmphetamine"
        static let dimWhenLidClosed = "dimWhenLidClosed"
        static let requireActiveSession = "requireActiveSession"
        static let launchAtLogin = "launchAtLogin"
        static let restoreBrightnessOnExit = "restoreBrightnessOnExit"
        static let completedOnboarding = "completedOnboarding"
        static let sessionAccessRequested = "sessionAccessRequested"
    }

    private let defaults: UserDefaults

    @Published var automaticallyLaunchAmphetamine: Bool {
        didSet { defaults.set(automaticallyLaunchAmphetamine, forKey: Key.automaticallyLaunchAmphetamine) }
    }

    @Published var relaunchAmphetamine: Bool {
        didSet { defaults.set(relaunchAmphetamine, forKey: Key.relaunchAmphetamine) }
    }

    @Published var dimWhenLidClosed: Bool {
        didSet { defaults.set(dimWhenLidClosed, forKey: Key.dimWhenLidClosed) }
    }

    @Published var requireActiveSession: Bool {
        didSet { defaults.set(requireActiveSession, forKey: Key.requireActiveSession) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }

    @Published var restoreBrightnessOnExit: Bool {
        didSet { defaults.set(restoreBrightnessOnExit, forKey: Key.restoreBrightnessOnExit) }
    }

    @Published var completedOnboarding: Bool {
        didSet { defaults.set(completedOnboarding, forKey: Key.completedOnboarding) }
    }

    @Published var sessionAccessRequested: Bool {
        didSet { defaults.set(sessionAccessRequested, forKey: Key.sessionAccessRequested) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.automaticallyLaunchAmphetamine: true,
            Key.relaunchAmphetamine: true,
            Key.dimWhenLidClosed: true,
            Key.requireActiveSession: true,
            Key.launchAtLogin: false,
            Key.restoreBrightnessOnExit: true,
            Key.completedOnboarding: false,
            Key.sessionAccessRequested: false
        ])

        automaticallyLaunchAmphetamine = defaults.bool(forKey: Key.automaticallyLaunchAmphetamine)
        relaunchAmphetamine = defaults.bool(forKey: Key.relaunchAmphetamine)
        dimWhenLidClosed = defaults.bool(forKey: Key.dimWhenLidClosed)
        requireActiveSession = defaults.bool(forKey: Key.requireActiveSession)
        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        restoreBrightnessOnExit = defaults.bool(forKey: Key.restoreBrightnessOnExit)
        completedOnboarding = defaults.bool(forKey: Key.completedOnboarding)
        sessionAccessRequested = defaults.bool(forKey: Key.sessionAccessRequested)
    }
}
