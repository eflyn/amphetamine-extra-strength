#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
cd "$project_root"

sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
architectures=(arm64 x86_64)
release_binaries=()

for architecture in "${architectures[@]}"; do
    scratch_directory="$project_root/.build/release-$architecture"
    target_triple="$architecture-apple-macosx13.0"

    swift build \
        -c release \
        --scratch-path "$scratch_directory" \
        --triple "$target_triple" \
        --sdk "$sdk_path"

    binary_directory="$(swift build \
        -c release \
        --scratch-path "$scratch_directory" \
        --triple "$target_triple" \
        --sdk "$sdk_path" \
        --show-bin-path)"
    release_binaries+=("$binary_directory/AmphetamineExtraStrength")
done

app_bundle="$project_root/dist/Amphetamine Extra Strength.app"
contents_directory="$app_bundle/Contents"

rm -rf "$app_bundle"
mkdir -p "$contents_directory/MacOS"
mkdir -p "$contents_directory/Resources"

ditto "$project_root/Config/Info.plist" "$contents_directory/Info.plist"
lipo -create "${release_binaries[@]}" \
    -output "$contents_directory/MacOS/AmphetamineExtraStrength"
chmod 755 "$contents_directory/MacOS/AmphetamineExtraStrength"

codesign --force --deep --sign - --timestamp=none "$app_bundle"

echo "Built: $app_bundle"
