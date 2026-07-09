# DailyFrame Growth Event Schema

This schema defines local, debug-only growth measurement for DailyFrame. It is a development aid for validating the private habit loop before any external analytics decision. It does not add an SDK, network transmission, account identifier, attribution identifier, or backend dependency.

## Storage And Retention

- Format: newline-delimited JSON, one object per event.
- Debug file: Application Support/DailyFrame/growth-events.jsonl.
- Build behavior: Debug builds may append local JSONL through GrowthEventLogger. Release builds compile the logger as a no-op surface and must not write the file.
- Retention: local debug logs are temporary QA artifacts. Delete after the related QA run or keep for no more than 30 days inside task evidence. The app must not expose this file to users or backups as a product feature.
- Privacy class: local operational telemetry for developer QA only. The schema is privacy-safe by design and contains no user identifier or content payload.

## Record Shape

Each JSONL record uses this shape:

```json
{
  "schema_version": 1,
  "event_name": "visit",
  "funnel_stage": "visit",
  "local_date": "2026-07-02",
  "properties": {
    "surface": "app_launch"
  }
}
```

Allowed top-level keys are `schema_version`, `event_name`, `funnel_stage`, `local_date`, and `properties`.

Allowed property values are short ASCII tokens or local date strings. Do not record free-form text.

## Privacy Rules

Never record photo content, photo file paths, image metadata, memo text, user profile values, contact details, identifiers, auth material, URLs from providers, signed URLs, precise location, device advertising identifiers, or push tokens.

D1 and D7 retention events are derived only from saved local date snapshots. They must not use account creation time, server timestamps, notification identifiers, image timestamps, EXIF data, or calendar/profile details.

## Event Catalog

| Event name | Funnel stage | Trigger point | Allowed properties | Privacy notes |
| --- | --- | --- | --- | --- |
| `visit` | visit | App launch or first visible root surface in a debug run | `surface` | Use a surface token such as `app_launch`; no device or user ID. |
| `onboarding_start` | start | Onboarding first screen appears | `surface` | Records only that onboarding started. |
| `first_record_start` | start | User opens the first-record editor from onboarding or Home | `surface` | Records the entry point token only. |
| `photo_selected` | start | User chooses camera or library media for the editor | `photo_source` | Use `camera` or `library`; never store asset IDs, paths, content, or metadata. |
| `first_record_saved` | activation | First photo entry save succeeds | `record_local_date` | Stores the local entry date string only. |
| `completion_viewed` | activation | Completion state is shown after save | `record_local_date` | Stores the local entry date string only. |
| `reminder_enabled` | return | User taps the post-completion reminder action and permission/scheduling resolves | `reminder_status` | Use status tokens such as `enabled`, `denied`, or `skipped`; no notification token. |
| `d1_return` | return | App is opened on local day 1 after activation | `activation_local_date`, `return_local_date`, `day_offset` | Calculated from local date snapshots only. |
| `d7_return` | return | App is opened on local day 7 after activation | `activation_local_date`, `return_local_date`, `day_offset` | Calculated from local date snapshots only. |
| `share_tapped` | share_placeholder | Future share-card experiment tap, if enabled by a later task | `surface`, `placeholder_context` | Placeholder only; do not log share target, recipient, or exported content. |
| `payment_interest_tapped` | payment_placeholder | Future payment/value-discovery tap, if enabled by a later task | `surface`, `placeholder_context` | Placeholder only; no product purchase, price, account, or payment provider data. |

## Funnel Mapping

- Visit: `visit`.
- Start: `onboarding_start`, `first_record_start`, `photo_selected`.
- Activation: `first_record_saved`, `completion_viewed`.
- Return: `reminder_enabled`, `d1_return`, `d7_return`.
- Share measurement placeholder: `share_tapped`.
- Payment measurement placeholder: `payment_interest_tapped`.

## Validation Rules

- Event names must be one of the catalog values.
- Properties must be in the allowlist for that exact event.
- `local_date`, `record_local_date`, `activation_local_date`, and `return_local_date` must use `YYYY-MM-DD`.
- `day_offset` is allowed only for `d1_return` and `d7_return`, with values `1` or `7`.
- Malformed dates, unknown property keys, empty values, or long/free-form values must be rejected before a JSONL line is written.
