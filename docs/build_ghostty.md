# Rebuild GhosttyKit.xcframework

This note records the current manual process for rebuilding the vendored `Liney/Vendor/GhosttyKit.xcframework`.

Liney does not currently generate this framework in-repo. The xcframework is vendored into source control and updated manually when the embedded Ghostty runtime needs to change.

## What This Framework Is

Liney links against Ghostty's macOS library through `GhosttyKit.xcframework`.

Ghostty's upstream build system can emit an xcframework directly. In current upstream source:

- `app-runtime=none` means "build the library for a macOS app consumer" rather than a standalone Ghostty app runtime.
- `emit-xcframework=true` enables xcframework output.
- `xcframework-target=universal` produces a universal macOS library and also includes iOS and iOS Simulator slices in the xcframework bundle.

Relevant upstream sources:

- Ghostty build docs: <https://ghostty.org/docs/install/build>
- Ghostty build config: <https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/build/Config.zig>
- Ghostty xcframework builder: <https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/build/GhosttyXCFramework.zig>
- Ghostty runtime enum: <https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/apprt/runtime.zig>

## Important Constraints

- Prefer a specific Ghostty release tag or pinned commit. Do not vendor from upstream `main` casually.
- Ghostty requires a specific Zig version per Ghostty release. Check the official build docs before building.
- The current Liney release flow expects the macOS library slice to contain both `arm64` and `x86_64`.
- Replacing only the binary without the matching headers is risky because the C API surface can change between Ghostty revisions.

## Prerequisites

- macOS with full Xcode installed
- Active developer directory pointing at Xcode, not Command Line Tools
- macOS and iOS SDKs installed in Xcode
- Zig version matching the Ghostty version being built
- `gettext` installed, for example via Homebrew
- Metal toolchain installed

Example setup:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
xcodebuild -downloadComponent MetalToolchain
brew install gettext
```

## Fetch Upstream Source

For stable rebuilds, prefer Ghostty's source tarball or a pinned release tag.

Tarball example:

```bash
curl -LO https://release.files.ghostty.org/VERSION/ghostty-VERSION.tar.gz
tar -xf ghostty-VERSION.tar.gz
cd ghostty-VERSION
```

Git example:

```bash
git clone https://github.com/ghostty-org/ghostty
cd ghostty
git checkout <tag-or-commit>
```

If this repository starts depending on a specific Ghostty revision, record it in this file when updating the vendor bundle.

## Build The XCFramework

Run Ghostty's Zig build with the macOS app runtime disabled and xcframework output enabled:

```bash
zig build \
  -Doptimize=ReleaseFast \
  -Dapp-runtime=none \
  -Demit-xcframework=true \
  -Demit-macos-app=false \
  -Dxcframework-target=universal
```

Expected output:

```text
zig-out/macos/GhosttyKit.xcframework
```

Upstream currently writes the xcframework to `macos/GhosttyKit.xcframework` under `zig-out/`.

## Replace The Vendored Framework

From the Liney repository root:

```bash
rm -rf Liney/Vendor/GhosttyKit.xcframework
cp -R /path/to/ghostty/zig-out/macos/GhosttyKit.xcframework Liney/Vendor/GhosttyKit.xcframework
```

## Verify The Result

Confirm the macOS library is universal:

```bash
lipo -archs Liney/Vendor/GhosttyKit.xcframework/macos-arm64_x86_64/libghostty.a
```

Expected output:

```text
x86_64 arm64
```

Confirm the xcframework metadata advertises the same architecture set:

```bash
plutil -p Liney/Vendor/GhosttyKit.xcframework/Info.plist
```

Then verify Liney still builds:

```bash
scripts/build_macos_app.sh
```

If you only need a local macOS debug build, an `arm64`-only Ghostty library may still compile on Apple Silicon, but it will break the repository's current universal release flow.

## Update Notes For Maintainers

When refreshing `GhosttyKit.xcframework`, record these details in the commit or PR description:

- Ghostty source version or commit
- Zig version used
- Whether the macOS slice is `arm64 + x86_64`
- Whether the public headers changed

