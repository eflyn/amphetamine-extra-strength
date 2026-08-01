#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
cd "$project_root"

swift build -c release
binary_directory="$(swift build -c release --show-bin-path)"
app_bundle="$project_root/dist/Amphetamine Extra Strength.app"
contents_directory="$app_bundle/Contents"

mkdir -p "$contents_directory/MacOS"
mkdir -p "$contents_directory/Resources"

ditto "$project_root/Config/Info.plist" "$contents_directory/Info.plist"
ditto "$binary_directory/AmphetamineExtraStrength" \
    "$contents_directory/MacOS/AmphetamineExtraStrength"
chmod 755 "$contents_directory/MacOS/AmphetamineExtraStrength"

codesign --force --deep --sign - "$app_bundle"

echo "Built: $app_bundle"
