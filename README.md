# Amphetamine Extra Strength

A small native macOS menu-bar utility that works alongside
[Amphetamine](https://apps.apple.com/app/amphetamine/id937984704). When the
MacBook lid closes during the configured Amphetamine state, it saves the
built-in display brightness, sets that display to zero, and restores the saved
value when the conditions end.

It has no Dock icon, windows are optional after onboarding, and it does not
control Amphetamine sessions or external displays.

## Requirements

- macOS 13 Ventura or newer
- Amphetamine
- Apple Command Line Tools or Xcode to build

## Build and run

```sh
./scripts/build-app.sh
open "dist/Amphetamine Extra Strength.app"
```

For a stable Automation permission and launch-at-login registration, move the
built app to `/Applications` before the first launch. The build is ad-hoc signed
for local use.

The project is a Swift package, so it can also be opened directly in Xcode.

## First launch and permissions

The first-run panel explains every requested capability. Amphetamine session
checking is opt-in: choose **Allow Session Checking** to let this utility send
Amphetamine's read-only `session is active` Apple event. If access is declined,
the utility continues to report running/installation state. You can turn off
**Require an active Amphetamine session** to dim whenever Amphetamine is
running.

Launch at login uses macOS `SMAppService`. macOS may require approval in
**System Settings → General → Login Items**.

## Reliability model

- The built-in display is selected with `CGDisplayIsBuiltin`; external display
  IDs are never passed to brightness control.
- Brightness ownership is persisted before the zero-brightness write.
- An existing zero is never saved as the original brightness.
- The saved brightness is immutable for the entire owned dim cycle.
- A nonzero manual adjustment relinquishes ownership and suppresses re-dimming
  until the conditions reset.
- Failed restores remain pending and are retried after timer, wake, session,
  application, and display-configuration events.
- Amphetamine launch failures use an exponential cooldown capped at two
  minutes.
- Two consecutive running/session samples are required before dimming.

macOS does not expose a supported public API for changing hardware display
brightness. This utility dynamically loads the system DisplayServices
brightness functions at runtime and reports an actionable unavailable state if
they cannot be loaded on a future macOS release.

## Development

Run the state-machine tests:

```sh
./scripts/run-tests.sh
```

The verification harness intentionally has no XCTest dependency, so it runs
with either Apple Command Line Tools or full Xcode.

Watch detailed production diagnostics:

```sh
log stream --level debug \
  --predicate 'subsystem == "com.dawar.AmphetamineExtraStrength"'
```

The logs cover lifecycle, monitoring decisions, lid reads, Amphetamine session
queries and launch cooldowns, brightness ownership, manual overrides, and
restore retries. No analytics, telemetry, or personal information is collected
or transmitted.
