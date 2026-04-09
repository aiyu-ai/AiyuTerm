#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

source "$ROOT_DIR/scripts/sparkle_tools.sh"

ARCHIVE_DSYM_SCRIPT="${ARCHIVE_DSYM_SCRIPT:-$ROOT_DIR/scripts/archive_dsym.sh}"
UPLOAD_DSYM_SCRIPT="${UPLOAD_DSYM_SCRIPT:-$ROOT_DIR/scripts/upload_dsym_to_sentry.sh}"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/AiyuTerm.xcodeproj}"
SCHEME="${SCHEME:-AiyuTerm}"
APP_NAME="${APP_NAME:-AiyuTerm}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-AiyuTerm}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-}"
VERSION="${VERSION:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
RELEASE_ARCHS="${RELEASE_ARCHS:-arm64 x86_64}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
APPCAST_SOURCE_FILE="${APPCAST_SOURCE_FILE:-$ROOT_DIR/appcast.xml}"

SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-${APPLE_PASSWORD:-${APP_SPECIFIC_PASSWORD:-}}}"
AIYUTERM_RELEASE_HOME="${AIYUTERM_RELEASE_HOME:-$HOME/.aiyuterm_release}"
SPARKLE_PRIVATE_KEY_FILE="${SPARKLE_PRIVATE_KEY_FILE:-$AIYUTERM_RELEASE_HOME/sparkle_private_key}"
SPARKLE_MAX_VERSIONS="${SPARKLE_MAX_VERSIONS:-10}"
SPARKLE_CHANNEL="${SPARKLE_CHANNEL:-}"

SKIP_PUSH="${SKIP_PUSH:-0}"
SKIP_TAG="${SKIP_TAG:-0}"
SKIP_GH_RELEASE="${SKIP_GH_RELEASE:-0}"
SKIP_NOTARIZE="${SKIP_NOTARIZE:-0}"
SKIP_SENTRY_DSYM_UPLOAD="${SKIP_SENTRY_DSYM_UPLOAD:-0}"
RELEASE_NOTES_FILE=""
APPCAST_STAGING_DIR=""

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

cleanup() {
  if [[ -n "$RELEASE_NOTES_FILE" && -f "$RELEASE_NOTES_FILE" ]]; then
    rm -f "$RELEASE_NOTES_FILE"
  fi
  if [[ -n "$APPCAST_STAGING_DIR" && -d "$APPCAST_STAGING_DIR" ]]; then
    rm -rf "$APPCAST_STAGING_DIR"
  fi
}
trap cleanup EXIT

for cmd in git xcodebuild xcrun; do
  require_cmd "$cmd"
done

if [[ "$SKIP_SENTRY_DSYM_UPLOAD" != "1" && ! -x "$UPLOAD_DSYM_SCRIPT" ]]; then
  echo "Missing executable dSYM upload script: $UPLOAD_DSYM_SCRIPT" >&2
  exit 1
fi

if [[ ! -x "$ARCHIVE_DSYM_SCRIPT" ]]; then
  echo "Missing executable dSYM archive script: $ARCHIVE_DSYM_SCRIPT" >&2
  exit 1
fi

if [[ -n "$SIGNING_IDENTITY" ]]; then
  require_cmd codesign
  require_cmd spctl
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Missing Xcode project: $PROJECT_PATH" >&2
  exit 1
fi

BUILD_SETTINGS_CACHE=""

load_build_settings() {
  if [[ -n "$BUILD_SETTINGS_CACHE" ]]; then
    return
  fi

  BUILD_SETTINGS_CACHE="$(
    xcodebuild \
      -project "$PROJECT_PATH" \
      -scheme "$SCHEME" \
      -configuration Release \
      -destination 'platform=macOS,arch=arm64' \
      -showBuildSettings
  )"
}

build_setting() {
  local key="$1"
  load_build_settings
  awk -F ' = ' -v key="$key" '$1 ~ "^[[:space:]]*" key "$" { print $2; exit }' <<< "$BUILD_SETTINGS_CACHE"
}

VERSION="${VERSION:-$(build_setting MARKETING_VERSION)}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-$(build_setting PRODUCT_BUNDLE_IDENTIFIER)}"
if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="$(build_setting CURRENT_PROJECT_VERSION)"
fi

if [[ -z "$VERSION" ]]; then
  echo "VERSION is empty" >&2
  exit 1
fi

if [[ -z "$BUNDLE_IDENTIFIER" ]]; then
  echo "BUNDLE_IDENTIFIER is empty" >&2
  exit 1
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  echo "BUILD_NUMBER is empty" >&2
  exit 1
fi

APP_BUNDLE_PATH="$OUTPUT_DIR/$APP_NAME.app"
DMG_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION.dmg"
ZIP_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION.app.zip"
DSYM_PATH="$OUTPUT_DIR/dSYMs/$APP_NAME-$VERSION.app.dSYM"
DSYM_ZIP_PATH="$DSYM_PATH.zip"
APPCAST_OUTPUT_PATH="$OUTPUT_DIR/appcast.xml"
TAG="${TAG:-v$VERSION}"

SPARKLE_USE_KEYCHAIN="${SPARKLE_USE_KEYCHAIN:-0}"
if [[ "$SPARKLE_USE_KEYCHAIN" != "1" && ! -f "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
  echo "Missing Sparkle private key file: $SPARKLE_PRIVATE_KEY_FILE" >&2
  echo "Run scripts/setup_sparkle_keys.sh first, set SPARKLE_PRIVATE_KEY_FILE / AIYUTERM_RELEASE_HOME," >&2
  echo "or set SPARKLE_USE_KEYCHAIN=1 to read the key from macOS Keychain." >&2
  exit 1
fi

if [[ "$SKIP_GH_RELEASE" != "1" ]]; then
  require_cmd gh
  if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI is not authenticated. Run: gh auth login" >&2
    exit 1
  fi
fi

if [[ -n "$(git status --short)" ]]; then
  echo "Working tree is not clean. Commit or stash changes before release." >&2
  exit 1
fi

if [[ "$SKIP_PUSH" != "1" ]]; then
  git push origin "$(git branch --show-current)"
fi

APP_NAME="$APP_NAME" \
EXECUTABLE_NAME="$EXECUTABLE_NAME" \
BUNDLE_IDENTIFIER="$BUNDLE_IDENTIFIER" \
VERSION="$VERSION" \
BUILD_NUMBER="$BUILD_NUMBER" \
RELEASE_ARCHS="$RELEASE_ARCHS" \
OUTPUT_DIR="$OUTPUT_DIR" \
PROJECT_PATH="$PROJECT_PATH" \
SCHEME="$SCHEME" \
SIGNING_IDENTITY="$SIGNING_IDENTITY" \
"$ROOT_DIR/scripts/build_macos_app.sh"

if [[ -n "$SIGNING_IDENTITY" ]]; then
  spctl --assess --type execute "$APP_BUNDLE_PATH"
fi

if [[ "$SKIP_NOTARIZE" != "1" ]]; then
  if [[ -n "$NOTARYTOOL_PROFILE" ]]; then
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
  elif [[ -n "$APPLE_ID" && -n "$APPLE_TEAM_ID" && -n "$APPLE_APP_SPECIFIC_PASSWORD" ]]; then
    xcrun notarytool submit "$DMG_PATH" \
      --apple-id "$APPLE_ID" \
      --team-id "$APPLE_TEAM_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --wait
  else
    cat >&2 <<EOF
Notarization credentials missing.
Set one of:
  NOTARYTOOL_PROFILE=<keychain-profile>
  APPLE_ID + APPLE_TEAM_ID + APPLE_APP_SPECIFIC_PASSWORD
Or set:
  SKIP_NOTARIZE=1
EOF
    exit 1
  fi

  xcrun stapler staple "$APP_BUNDLE_PATH"
  xcrun stapler staple "$DMG_PATH"
fi

APP_NAME="$APP_NAME" \
VERSION="$VERSION" \
OUTPUT_DIR="$OUTPUT_DIR" \
"$ARCHIVE_DSYM_SCRIPT" --version "$VERSION"

if [[ ! -d "$DSYM_PATH" || ! -f "$DSYM_ZIP_PATH" ]]; then
  echo "Missing archived dSYM artifacts: $DSYM_PATH / $DSYM_ZIP_PATH" >&2
  exit 1
fi

if [[ "$SKIP_SENTRY_DSYM_UPLOAD" != "1" ]]; then
  APP_NAME="$APP_NAME" \
  OUTPUT_DIR="$OUTPUT_DIR" \
  DSYM_PATH="$DSYM_PATH" \
  "$UPLOAD_DSYM_SCRIPT"
fi

if [[ "$SKIP_TAG" != "1" ]]; then
  if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    echo "Tag already exists: $TAG" >&2
    exit 1
  fi
  git tag "$TAG"
  if [[ "$SKIP_PUSH" != "1" ]]; then
    git push origin "$TAG"
  fi
fi

RELEASE_NOTES_FILE="$(mktemp "${TMPDIR:-/tmp}/aiyuterm-release-notes.XXXXXX.md")"
cat > "$RELEASE_NOTES_FILE" <<EOF
## AiyuTerm $VERSION

- GitHub release: https://github.com/aiyu-ai/AiyuTerm/releases/tag/$TAG
EOF

sparkle_create_app_zip "$APP_BUNDLE_PATH" "$ZIP_PATH"

if [[ "$SPARKLE_USE_KEYCHAIN" == "1" ]]; then
  # Sign with Keychain key and manually update appcast.xml
  SIGN_TOOL="$(sparkle_tool_path sign_update "$ROOT_DIR" "$PROJECT_PATH" "$SCHEME")"
  SIGN_OUTPUT="$("$SIGN_TOOL" --account "${SPARKLE_KEY_ACCOUNT:-aiyuterm}" "$ZIP_PATH")"
  ED_SIGNATURE="$(echo "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
  ZIP_LENGTH="$(echo "$SIGN_OUTPUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p')"

  RELEASE_NOTES_HTML="<h2>AiyuTerm $VERSION</h2><ul><li>See release notes on GitHub</li></ul>"
  PUB_DATE="$(date -R)"

  # Build new item XML
  NEW_ITEM=$(cat <<XMLEOF
        <item>
            <title>v$VERSION</title>
            <link>https://github.com/aiyu-ai/AiyuTerm/releases/tag/$TAG</link>
            <sparkle:version>$BUILD_NUMBER</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.6</sparkle:minimumSystemVersion>
            <pubDate>$PUB_DATE</pubDate>
            <enclosure url="https://github.com/aiyu-ai/AiyuTerm/releases/download/$TAG/$APP_NAME-$VERSION.app.zip"
                       length="$ZIP_LENGTH"
                       type="application/octet-stream"
                       sparkle:edSignature="$ED_SIGNATURE" />
            <description><![CDATA[$RELEASE_NOTES_HTML]]></description>
        </item>
XMLEOF
  )

  # Insert new item after <language>en</language>
  if [[ -f "$APPCAST_SOURCE_FILE" ]]; then
    sed -i '' "/<language>en<\/language>/a\\
$NEW_ITEM
" "$APPCAST_SOURCE_FILE"
    cp "$APPCAST_SOURCE_FILE" "$APPCAST_OUTPUT_PATH"
  fi
else
  APPCAST_STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/aiyuterm-appcast.XXXXXX")"
  ZIP_BASENAME="$(basename "$ZIP_PATH" .zip)"

  cp "$ZIP_PATH" "$APPCAST_STAGING_DIR/"
  cp "$RELEASE_NOTES_FILE" "$APPCAST_STAGING_DIR/$ZIP_BASENAME.md"
  if [[ -f "$APPCAST_SOURCE_FILE" ]]; then
    cp "$APPCAST_SOURCE_FILE" "$APPCAST_STAGING_DIR/appcast.xml"
  fi

  sparkle_generate_appcast \
    "$APPCAST_STAGING_DIR" \
    "$SPARKLE_PRIVATE_KEY_FILE" \
    "https://github.com/aiyu-ai/AiyuTerm/releases/download/$TAG/" \
    "https://github.com/aiyu-ai/AiyuTerm/releases/tag/$TAG" \
    "https://github.com/aiyu-ai/AiyuTerm" \
    "$SPARKLE_MAX_VERSIONS" \
    "$SPARKLE_CHANNEL" \
    "$ROOT_DIR" \
    "$PROJECT_PATH" \
    "$SCHEME"

  cp "$APPCAST_STAGING_DIR/appcast.xml" "$APPCAST_OUTPUT_PATH"
  rm -rf "$APPCAST_STAGING_DIR"
  APPCAST_STAGING_DIR=""
fi

rm -f "$RELEASE_NOTES_FILE"
RELEASE_NOTES_FILE=""

if [[ "$SKIP_GH_RELEASE" != "1" ]]; then
  UPLOAD_ASSETS=("$DMG_PATH" "$ZIP_PATH" "$APPCAST_OUTPUT_PATH")
  [[ -f "$DSYM_ZIP_PATH" ]] && UPLOAD_ASSETS+=("$DSYM_ZIP_PATH")

  if gh release view "$TAG" >/dev/null 2>&1; then
    gh release upload "$TAG" "${UPLOAD_ASSETS[@]}" --clobber
    gh release edit "$TAG" \
      --title "$APP_NAME $VERSION" \
      --notes "Release $VERSION"
  else
    gh release create "$TAG" "${UPLOAD_ASSETS[@]}" \
      --title "$APP_NAME $VERSION" \
      --notes "Release $VERSION"
  fi
fi

# Auto-commit updated appcast.xml back to the repo
SKIP_APPCAST_COMMIT="${SKIP_APPCAST_COMMIT:-0}"
if [[ "$SKIP_APPCAST_COMMIT" != "1" && -f "$APPCAST_SOURCE_FILE" ]]; then
  if ! diff -q "$APPCAST_OUTPUT_PATH" "$APPCAST_SOURCE_FILE" >/dev/null 2>&1; then
    cp "$APPCAST_OUTPUT_PATH" "$APPCAST_SOURCE_FILE"
  fi
  if [[ -n "$(git diff -- "$APPCAST_SOURCE_FILE")" ]]; then
    git add "$APPCAST_SOURCE_FILE"
    git commit -m "chore: update appcast for v$VERSION Sparkle update"
    if [[ "$SKIP_PUSH" != "1" ]]; then
      git push origin "$(git branch --show-current)"
    fi
  fi
fi

echo "Release ready:"
echo "  App bundle: $APP_BUNDLE_PATH"
echo "  DMG: $DMG_PATH"
echo "  ZIP: $ZIP_PATH"
echo "  Appcast: $APPCAST_OUTPUT_PATH"
