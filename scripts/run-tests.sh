#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
test_temp_directory="$(mktemp -d)"
trap 'rm -rf "$test_temp_directory"' EXIT

swiftc \
    "$project_root/Sources/AmphetamineExtraStrength/Models.swift" \
    "$project_root/Sources/AmphetamineExtraStrength/Services/BrightnessService.swift" \
    "$project_root/Sources/AmphetamineExtraStrength/Services/BrightnessGuard.swift" \
    "$project_root/Tests/AmphetamineExtraStrengthTests/BrightnessGuardTests.swift" \
    -o "$test_temp_directory/BrightnessGuardTests"

"$test_temp_directory/BrightnessGuardTests"
