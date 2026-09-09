#!/usr/bin/env bash
set -euo pipefail

# Cloud Agent VM only — refuse to mutate a developer machine.
[ "$(uname -s)" = "Linux" ] || { echo "refusing: not a Linux Cloud Agent VM" >&2; exit 1; }
[ "$(hostname)" = "cursor" ] || { echo "refusing: hostname is not 'cursor' — stop and ask" >&2; exit 1; }

# Pinned Dart SDK version — matches the version enforced by .github/workflows/dart_ci.yml
# (the `format` job and the lower bound of the test matrix).
DART_VERSION=2.19.6
DART_SDK_DIR=/usr/lib/dart-sdk

# Install the pinned Dart SDK if it is missing or a different version. Idempotent:
# a matching SDK short-circuits the download so re-runs are cheap.
if ! command -v dart >/dev/null 2>&1 || ! dart --version 2>&1 | grep -q "$DART_VERSION"; then
  echo "Installing Dart SDK ${DART_VERSION}..."
  tmpzip="$(mktemp --suffix=.zip)"
  curl -fsSL "https://storage.googleapis.com/dart-archive/channels/stable/release/${DART_VERSION}/sdk/dartsdk-linux-x64-release.zip" -o "$tmpzip"
  sudo rm -rf "$DART_SDK_DIR"
  sudo unzip -q "$tmpzip" -d /usr/lib/
  sudo ln -sf "$DART_SDK_DIR/bin/dart" /usr/local/bin/dart
  rm -f "$tmpzip"
fi
dart --version

# Fetch dependencies for both packages. All dependencies are public pub.dev
# packages, so no Workiva (wk) / Artifactory / pub.workiva.org auth is required.
for pkg in w_common w_common_tools; do
  echo "== dart pub get (${pkg}) =="
  (cd "$pkg" && dart pub get)
done
