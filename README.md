# Amphetamine Extra Strength

[![CI](https://github.com/eflyn/amphetamine-extra-strength/actions/workflows/ci.yml/badge.svg)](https://github.com/eflyn/amphetamine-extra-strength/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/eflyn/amphetamine-extra-strength)](https://github.com/eflyn/amphetamine-extra-strength/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A small native macOS menu-bar companion for
[Amphetamine](https://apps.apple.com/app/amphetamine/id937984704). It saves the
built-in display and keyboard-backlight brightness when the MacBook lid closes,
sets both to zero, and restores them when the lid opens or the configured
Amphetamine state ends.

## Why this exists

Amphetamine is especially useful for keeping a Mac awake while coding agents or
other long-running tasks continue with the lid closed. That setup works best
with Amphetamine's **Allow display sleep** option unchecked, but the built-in
display can remain at its previous brightness after the lid closes and waste
battery unless it is turned down manually.

Amphetamine Extra Strength automates that missing step. It does not start,
stop, or otherwise control Amphetamine sessions.

## Download

Download the ready-built universal app and its SHA-256 checksum from the
[latest release](https://github.com/eflyn/amphetamine-extra-strength/releases/latest).

1. Unzip `Amphetamine-Extra-Strength-<version>-macOS.zip`.
2. Move **Amphetamine Extra Strength.app** to `/Applications`.
3. Open the app and complete its short permission walkthrough.
4. Optionally enable **Launch at Login** from the menu-bar utility.

Requirements:

- macOS 13 Ventura or newer
- An Apple Silicon or Intel MacBook with a built-in display
- [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704)

The downloadable build is ad-hoc signed and is not notarized. On first launch,
macOS may require you to try opening the app and then choose **Open Anyway** in
**System Settings → Privacy & Security**. Review
[Apple's safety guidance](https://support.apple.com/102445) before overriding
Gatekeeper for any unnotarized software. The release checksum lets you verify
that your download matches the artifact produced by this repository's release
workflow:

```sh
VERSION=1.1.0
shasum -a 256 -c "Amphetamine-Extra-Strength-$VERSION-macOS.zip.sha256"
```

## First launch and permissions

The onboarding panel explains every requested capability. Amphetamine session
checking is opt-in: choose **Allow Session Checking** to let this utility send
Amphetamine's read-only `session is active` Apple event. If access is declined,
the utility continues to report running and installation state. You can turn
off **Require an active Amphetamine session** to dim whenever Amphetamine is
running.

Launch at login uses macOS `SMAppService`. macOS may require approval in
**System Settings → General → Login Items**.

## What it controls

- Only the built-in display selected with `CGDisplayIsBuiltin`
- Only a backlight CoreBrightness identifies as belonging to the built-in
  keyboard
- Only while the lid and configured Amphetamine conditions are satisfied

It never sends brightness commands to external displays or external keyboard
lighting. A nonzero manual adjustment relinquishes ownership for that device
until the conditions reset. Display and keyboard brightness are saved and
restored independently, including after an interrupted dim cycle.

macOS does not expose a supported public API for hardware display or keyboard
backlight brightness. This utility dynamically loads DisplayServices and
CoreBrightness at runtime and reports an actionable unavailable state if either
interface changes in a future macOS release.

## Build from source

Install Xcode or the Apple Command Line Tools, then run:

```sh
./scripts/build-app.sh
open "dist/Amphetamine Extra Strength.app"
```

The build script produces a universal, ad-hoc-signed app in `dist/`. To create
the same ZIP and checksum used for GitHub releases:

```sh
./scripts/package-release.sh
```

The project is a Swift package and can also be opened directly in Xcode.

## Development

Run the state-machine verification harness:

```sh
./scripts/run-tests.sh
```

Watch detailed production diagnostics:

```sh
log stream --level debug \
  --predicate 'subsystem == "com.eflyn.AmphetamineExtraStrength"'
```

The logs cover lifecycle, monitoring decisions, lid reads, Amphetamine session
queries and launch cooldowns, brightness ownership, manual overrides, and
restore retries. No analytics, telemetry, or personal information is collected
or transmitted.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development and release process.

## License and attribution

Released under the [MIT License](LICENSE).

This is an independent community project. It is not affiliated with, endorsed
by, or part of Amphetamine or its developer.
