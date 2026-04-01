# Next

## File Browser / Viewer Follow-ups

Scope: keep the current sheet-based file browser and improve reliability and clarity without turning it into a full repo tree or editor subsystem.

### 1. External change detection and reload flow

Why:
- Liney already supports opening files in an external editor.
- The current sheet has no notion of "changed on disk after load", so users can end up looking at stale content or overwrite newer disk state.

Todo:
- Track the selected file's last-known modification date and size when preview content is loaded.
- Re-check file metadata when the sheet becomes active again, when selection changes back to the same file, and before save.
- If the file changed on disk and the editor is clean, show a lightweight banner and offer `Reload`.
- If the file changed on disk and the editor is dirty, show a conflict warning and require explicit user choice before overwriting.
- Keep the behavior local to the file browser sheet; do not add a global file watching system yet.

Acceptance:
- Editing a file in an external editor is reflected in the sheet after reload.
- Dirty local edits are not silently overwritten.
- The UI clearly distinguishes stale preview vs unsaved local changes.

### 2. Stronger unsupported-preview states

Why:
- The current unsupported path is functional, but it only tells the user that a file is large or binary.
- For Liney, unsupported preview should still be a useful terminal point with clear next actions.

Todo:
- Expand unsupported states to include more context such as file size and reason.
- Keep `Reveal in Finder` and `Open in External Editor` available and prominent in unsupported states.
- Consider adding `Copy Path` if it can be done with minimal UI cost.
- Tighten the copy so the messages are explicit: binary, too large, unreadable, or missing.

Acceptance:
- Unsupported files never render garbled text.
- Users can immediately understand why preview is unavailable.
- Users still have a clear next step from the unsupported state.

### 3. Preview loading strategy optimization

Why:
- The current preview path reads the entire file into memory before checking size.
- This is unnecessary for large files and makes the sheet less robust on big repositories.

Todo:
- Check file metadata first and reject over-limit files before reading contents.
- Only read text files that are within the preview threshold.
- Consider a bounded preview read path if partial preview is useful later, but do not expand scope in the first pass.
- Add focused tests for "size checked before read" behavior and error handling around missing files.

Acceptance:
- Oversized files are rejected without full-file reads.
- Selecting a large file stays responsive.
- Existing UTF-8 preview and save behavior remains unchanged for normal-sized files.

## Order

1. External change detection and reload flow
2. Preview loading strategy optimization
3. Stronger unsupported-preview states

## Non-goals

- No repo tree / outline navigation
- No editor replacement or syntax-highlighting project
- No shared filesystem abstraction beyond the current sheet feature
- No background recursive watch service in this phase
