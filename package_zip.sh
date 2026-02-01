#!/bin/bash
set -euo pipefail

APP_NAME="TimeDial"
PROJECT="timedial.xcodeproj"
SCHEME="timedial"
CONFIG="Release"
DERIVED_ROOT="$HOME/Library/Developer/Xcode/DerivedData"

VERSION=$(rg -n "MARKETING_VERSION = " "$PROJECT/project.pbxproj" | head -1 | sed 's/.*= //; s/;//' | tr -d '"')
if [ -z "${VERSION}" ]; then
  VERSION="0.0.0"
fi

echo "🔨 Building ${APP_NAME} (${CONFIG})..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" build

APP_PATH=$(find "$DERIVED_ROOT" -path "*/Build/Products/${CONFIG}/${APP_NAME}.app" -type d 2>/dev/null | grep -v "/Index.noindex/" | head -1)

if [ -z "${APP_PATH}" ]; then
  echo "❌ ${APP_NAME}.app not found after build."
  exit 1
fi

if [ ! -x "$APP_PATH/Contents/MacOS/${APP_NAME}" ]; then
  echo "❌ ${APP_NAME}.app is missing the executable."
  exit 1
fi

OUT_DIR="dist"
mkdir -p "$OUT_DIR"

ZIP_PATH="${OUT_DIR}/${APP_NAME}-${VERSION}.zip"
echo "📦 Creating ${ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "✅ Done."
echo "Upload: $ZIP_PATH"
