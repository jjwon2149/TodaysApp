# Backup And Export QA Contract

Status: baseline checklist for PHO-51, PHO-52, PHO-62, and PHO-70.

## Media Path Contract

- New entries store `imageLocalPath` and `thumbnailLocalPath` as filenames relative to `Application Support/DailyFrame/Entries/`.
- Launch maintenance normalizes legacy app container absolute paths and `file://` values to filenames.
- Runtime image loading, thumbnail loading, deletion, thumbnail backfill, and export all resolve through `ImageStorageService`.
- Stored JSON must not rely on stale app container absolute paths after launch maintenance or after a user edits an existing entry.

## Export Package Contract

The Profile export action creates a ZIP file named `DailyFrame-Export-<UTC timestamp>.zip`.

Archive contents:

- `manifest.json`
- `Media/<image files>`
- `Media/<thumbnail files>` when a separate thumbnail exists

Manifest guarantees:

- Only active entries are exported.
- Entry metadata remains present even when media is missing.
- Media references inside the manifest are archive-relative paths such as `Media/2026-05-13-UUID.jpg`.
- Missing images or thumbnails are reported in `warnings`.
- If the thumbnail is missing but the original image exists, the manifest points thumbnail usage to the original image path and records a warning.

## PHO-52 Resume Scenarios

- App container path changes: seed JSON with old absolute paths, place matching filenames in the current Entries directory, run launch maintenance, then verify UI and export resolve the images.
- Thumbnail-only missing: remove only the thumbnail file and verify Calendar uses original-image fallback and export records `thumbnail_missing_using_image`.
- Original image missing: remove the original image and verify UI shows the missing image state and export keeps the entry with an `image_missing` warning.
- Image replacement: edit an entry with a new image and verify old image/thumbnail files are removed while new JSON stores only filenames.
- Image deletion: delete an entry and verify the active export omits it while file cleanup remains best effort.
- iCloud disabled: CloudKit sync remains unavailable by design, but local save/edit/delete/export continues to work.
- Same-date multi-device conflict: CloudKit design converges by `localDateString`, last-writer-wins for scalar edits, and tombstone-wins over older edits.

## Release Gate

Backup/export QA can resume when:

- Unit tests cover media normalization, thumbnail fallback, and export manifest/package behavior.
- Simulator build and unit tests pass.
- `docs/CloudKitSyncDesign.md` records the sync, conflict, offline, and missing-media policies.
