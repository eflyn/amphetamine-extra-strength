# Contributing

Thanks for helping improve Amphetamine Extra Strength.

## Development setup

You need macOS 13 or newer and either Xcode or the Apple Command Line Tools.

```sh
git clone https://github.com/eflyn/amphetamine-extra-strength.git
cd amphetamine-extra-strength
./scripts/run-tests.sh
./scripts/build-app.sh
```

The app is intentionally a small Swift package with no third-party runtime
dependencies. Keep changes focused, preserve the built-in-device safety checks,
and add diagnostic logging for new state transitions or hardware interactions.

## Testing changes

Before opening a pull request:

```sh
./scripts/run-tests.sh
swift build
./scripts/build-app.sh
```

Hardware behavior should also be checked on a MacBook. Never test new
brightness-control behavior on a machine you cannot recover directly.

## Pull requests

- Explain the user-visible behavior and failure modes.
- Include tests for state-machine changes.
- Include relevant unified-log excerpts when diagnosing hardware behavior, but
  remove personal or machine-specific information first.
- Do not commit `.build`, `dist`, signing credentials, or provisioning data.

## Releases

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in
   `Config/Info.plist`.
2. Update `CHANGELOG.md` and merge the release commit to `main`.
3. Create and push an annotated `v<version>` tag.
4. The release workflow builds the universal app, verifies that the tag matches
   the plist version, and publishes the ZIP plus SHA-256 checksum.

GitHub releases are ad-hoc signed unless a future workflow is configured with a
Developer ID Application certificate and Apple notarization credentials.
