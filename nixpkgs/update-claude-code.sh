#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq python3
# shellcheck shell=bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

BASE_URL="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

version=$(curl -s "$BASE_URL/latest")
echo "Latest claude-code version: $version"

current=$(jq -r '.version' claude-code-hashes.json)
echo "Current version: $current"

if [[ "$version" == "$current" ]]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating from $current to $version"

manifest=$(curl -s "$BASE_URL/$version/manifest.json")

hex_to_sri() {
  echo "sha256-$(echo "$1" | python3 -c "import sys,base64,binascii; print(base64.b64encode(binascii.unhexlify(sys.stdin.read().strip())).decode())")"
}

darwin_arm64_sri=$(hex_to_sri "$(echo "$manifest" | jq -r '.platforms."darwin-arm64".checksum')")
linux_x64_sri=$(hex_to_sri "$(echo "$manifest" | jq -r '.platforms."linux-x64".checksum')")

echo "aarch64-darwin: $darwin_arm64_sri"
echo "x86_64-linux: $linux_x64_sri"

cat > claude-code-hashes.json << EOF
{
  "version": "$version",
  "hashes": {
    "aarch64-darwin": "$darwin_arm64_sri",
    "x86_64-linux": "$linux_x64_sri"
  }
}
EOF

echo "Updated to $version"
