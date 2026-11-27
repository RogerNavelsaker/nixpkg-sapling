#!/usr/bin/env bash
# Sync nix/package-manifest.json, package.json, bun.lock and bun.nix to the latest npm release.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

manifest=nix/package-manifest.json
name=$(jq -r .package.npmName "$manifest")
current=$(jq -r .package.version "$manifest")
latest=$(npm view "$name" version)

if [ "$latest" = "$current" ] || [ "$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -n1)" = "$current" ]; then
  echo "sapling up to date ($current; npm $latest)"
  exit 0
fi

url=$(npm view "$name@$latest" dist.tarball)
hash=$(npm view "$name@$latest" dist.integrity)

tmp=$(mktemp)
jq --arg v "$latest" --arg u "$url" --arg h "$hash" \
  '.package.version=$v | .package.packageRevision=1 | .dist.url=$u | .dist.hash=$h' "$manifest" > "$tmp"
mv "$tmp" "$manifest"
tmp=$(mktemp)
jq --arg n "$name" --arg v "$latest" '.version=$v | .dependencies[$n]=$v' package.json > "$tmp"
mv "$tmp" package.json

nix shell nixpkgs#bun -c bun install --lockfile-only
nix develop -c bun2nix -o bun.nix
echo "sapling synced $current -> $latest"
