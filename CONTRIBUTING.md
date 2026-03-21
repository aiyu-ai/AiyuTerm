# Contributing

## Development

Build locally with:

```bash
xcodebuild \
  -project Liney.xcodeproj \
  -scheme Liney \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Run tests with:

```bash
xcodebuild \
  -project Liney.xcodeproj \
  -scheme Liney \
  -destination 'platform=macOS,arch=arm64' \
  test
```

## Pull Requests

- Keep changes focused and easy to review.
- Include tests when touching git parsing, worktree handling, persistence, or layout logic.
- Call out any manual verification you performed for sidebar, pane, or terminal behavior.
- Avoid changing vendored binaries in `Liney/Vendor/` unless the change explicitly requires it.
- Keep `docs/` in sync when changing terminal layering, testing conventions, or contributor workflows.

## Discussions

- Bug reports and feature requests: <https://github.com/wuwenrui/liney/issues>
- Security reports: see `SECURITY.md`
