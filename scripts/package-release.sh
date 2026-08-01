#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
cd "$project_root"

version="$(/usr/libexec/PlistBuddy \
    -c "Print :CFBundleShortVersionString" \
    "$project_root/Config/Info.plist")"
archive_name="Amphetamine-Extra-Strength-$version-macOS.zip"
archive_path="$project_root/dist/$archive_name"
checksum_path="$archive_path.sha256"
app_bundle="$project_root/dist/Amphetamine Extra Strength.app"

"$project_root/scripts/build-app.sh"

rm -f "$archive_path" "$checksum_path"
ditto -c -k --sequesterRsrc --keepParent "$app_bundle" "$archive_path"

(
    cd "$project_root/dist"
    shasum -a 256 "$archive_name" > "$archive_name.sha256"
)

echo "Packaged: $archive_path"
echo "Checksum: $checksum_path"
