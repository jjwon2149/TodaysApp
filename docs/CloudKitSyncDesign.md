# CloudKit Sync Design

Status: design contract for PHO-50, blocked from implementation until the media path contract and export QA pass in baseline code.

## Current Storage Contract

- Entries live in `Application Support/DailyFrame/app-state.json`.
- Entry media files live in `Application Support/DailyFrame/Entries/`.
- `DailyPhotoEntry.imageLocalPath` and `thumbnailLocalPath` are portable media references, not app container absolute paths. The current implementation stores flat filenames relative to the Entries directory.
- Legacy absolute paths and `file://` URLs are normalized by filename during launch maintenance and resolved against the current Entries directory.
- Thumbnail reads use original-image fallback when the thumbnail file is missing and the original image still exists.

## Proposed CloudKit Records

Use a private CloudKit database only.

`DFEntry`

- `recordName`: `entry:<localDateString>`
- `localDateString`: `String`, unique per user day
- `updatedAtUTC`: `Date`
- `createdAtUTC`: `Date`
- `timezoneIdentifier`: `String`
- `timezoneOffsetMinutes`: `Int64`
- `memo`: `String?`
- `moodCode`: `String?`
- `missionId`: `String?`
- `missionCompleted`: `Bool`
- `sourceType`: `String`
- `isDeleted`: `Bool`

`DFEntryMedia`

- `recordName`: `entry-media:<localDateString>:image` and `entry-media:<localDateString>:thumbnail`
- `entry`: reference to `DFEntry`
- `role`: `image` or `thumbnail`
- `asset`: `CKAsset`
- `fileName`: the portable Entries filename used locally
- `updatedAtUTC`: `Date`

## Identity And Merge Policy

- The MVP identity is one active entry per `localDateString` per user. Multiple local devices must converge on that single day record.
- Last-writer-wins applies to scalar entry fields using `updatedAtUTC`.
- Delete is a tombstone, not a hard delete. A tombstone wins over older edits and remains until every device has observed it.
- If two devices edit the same day while offline, the later `updatedAtUTC` wins for scalar fields. Media records are replaced only when the winning entry update references new media.
- Same-day duplicates created before sync support must be imported as conflict candidates and merged into the `entry:<localDateString>` record rather than uploaded as separate day records.

## Offline And iCloud Disabled Policy

- The app stays local-first. Users can create, edit, and delete entries offline.
- Offline changes are queued by local `updatedAtUTC` and uploaded when the private database is available.
- If iCloud is disabled, sync is unavailable but local persistence and manual export remain available.
- The UI should report sync disabled/unavailable without blocking local entry creation or export.
- CloudKit quota or account failures must leave local JSON and Entries files untouched.

## Missing Media Policy

- Missing image asset: keep the entry record, show a recoverable missing-media state, and do not overwrite the remote asset with nil unless the user explicitly deletes or replaces the image.
- Missing thumbnail asset: regenerate from the original image when possible. If regeneration fails, use original-image fallback in UI and export.
- Export packages include manifest warnings for missing media instead of silently dropping entries.
- CloudKit implementation must use the same resolver as local UI/export, so stale container paths never drive upload decisions.

## MVP Sync Flow

1. Run launch media maintenance before sync starts.
2. Normalize local media references to Entries-relative filenames.
3. Fetch changed `DFEntry` records from CloudKit private database.
4. Merge by `localDateString` and `updatedAtUTC`.
5. Resolve local media references through `ImageStorageService` before creating `CKAsset` files.
6. Upload entry scalars and media assets only after local JSON has been saved successfully.
7. Treat export ZIP as the user-visible backup fallback until end-to-end CloudKit QA passes.

## QA Gates

- Stale absolute path JSON resolves to current Entries filenames.
- Thumbnail-only missing files fall back to the original image.
- Export ZIP includes `manifest.json` and every resolvable media file.
- iCloud disabled leaves local save/edit/delete/export usable.
- Same date edits from two devices converge to one record with documented last-writer/tombstone behavior.
