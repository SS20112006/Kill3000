#!/usr/bin/env bash
set -euo pipefail

# Kill3000 Application Bundle Packaging Script
# Compiles Kill3000 in release mode, constructs the macOS .app bundle,
# installs Info.plist with LSUIElement=true, and applies ad-hoc codesigning.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
APP_DIR="${BUILD_DIR}/Kill3000.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
PLIST_SOURCE="${PROJECT_ROOT}/Resources/Info.plist"

echo "==> Building Kill3000 in release mode with Swift Package Manager..."
cd "${PROJECT_ROOT}"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/Kill3000App"

if [ ! -f "${BIN_PATH}" ]; then
    echo "Error: Compiled binary not found at ${BIN_PATH}" >&2
    exit 1
fi

echo "==> Creating macOS App Bundle directory structure..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "==> Installing executable into bundle..."
cp "${BIN_PATH}" "${MACOS_DIR}/Kill3000App"
chmod +x "${MACOS_DIR}/Kill3000App"

echo "==> Installing Info.plist..."
if [ -f "${PLIST_SOURCE}" ]; then
    cp "${PLIST_SOURCE}" "${CONTENTS_DIR}/Info.plist"
else
    echo "Error: Info.plist not found at ${PLIST_SOURCE}" >&2
    exit 1
fi

echo "==> Applying ad-hoc codesign to bundle..."
codesign --force --deep -s - "${APP_DIR}"

echo "==> Verifying codesign integrity..."
codesign --verify --deep --strict "${APP_DIR}"

echo "==> Creating distribution archives in ${BUILD_DIR}..."
cd "${BUILD_DIR}"
rm -f Kill3000.zip Kill3000-v1.0.0.zip
ditto -c -k --keepParent "Kill3000.app" "Kill3000.zip"
cp "Kill3000.zip" "Kill3000-v1.0.0.zip"

echo "==> Build and packaging complete!"
echo "    App bundle: ${APP_DIR}"
echo "    Zip archive: ${BUILD_DIR}/Kill3000.zip"
