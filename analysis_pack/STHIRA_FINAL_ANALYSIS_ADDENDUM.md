# Sthira: final source-review additions and handoff

8 September 2026. This closes the requested analysis of the supplied archive and supplements D01–D23 in the deep technical audit. These are source findings and conditional failure paths, not observations from a running APK. Implementation and native/emulator verification belong to the next development phase.

## D24 · P1 · Health history can be marked complete despite failed or denied reads

`backfillLast90Days` ignores the result of requesting history access, reads each day, and unconditionally stores the backfill-done flag. Read exceptions become null inside the helper methods. A denied history request or temporary platform failure can therefore produce partial/empty history that is never automatically retried as a backfill. The controller also advances its historical-sync timestamp after these best-effort reads. [lib/services/health_connect_service.dart:161](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/health_connect_service.dart:161>) [lib/providers/sync_controller.dart:95](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/sync_controller.dart:95>)

The same service sums the duration of every returned sleep session. If sources return overlapping sessions, the overlap is counted more than once; the code does not reconcile source priority or merge intervals. This is a conditional aggregation defect, not a claim that the installed plugin always returns duplicates. [lib/services/health_connect_service.dart:132](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/health_connect_service.dart:132>)

**Implement:** structured read results distinguishing unavailable/denied/failed/success-empty/success-data; resumable per-range checkpoints; a retry path after granting history access; an explicit sleep attribution and overlap policy. Preserve manual data. Avoid serially blocking the current-day UI on the entire 90-day import. Use calendar boundaries for date windows and verify timezone changes.

**Verify:** denied then granted history permission, a failure halfway through import, successful empty history, overlapping 22:00–06:00 and 23:00–07:00 sleep sessions, and resume after cancellation. Their union is nine hours, not sixteen, if both describe the same night's sleep and union is the chosen policy.

## D25 · P2 · Android home-screen widget uses inconsistent targets and habit eligibility

The widget updater divides steps by a hardcoded 10,000, reads all habits without filtering the current weekday, and obtains meal totals from a plan count that can differ from custom-slot configuration. Home can therefore show a different completion fraction from the widget for the same data. Its two-second delayed update on app pause is also best-effort rather than a guaranteed flush. [lib/services/widget_update_service.dart:26](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/widget_update_service.dart:26>) [lib/services/widget_update_service.dart:79](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/widget_update_service.dart:79>) [lib/providers/sync_controller.dart:31](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/sync_controller.dart:31>)

**Implement:** project the shared date-addressed daily statistics into widget data, including the configured target, eligible habits, and consistent meal-count semantics. Refresh relevant changes and clear/rebind account-owned widget data during account transitions. Keep freshness/date guards in the native provider.

**Verify:** a 6,000-step target at 3,000 steps shows 50% in both places; a Monday-only habit is excluded Tuesday; custom meals agree; background/restart and account switch do not leave another account's current-day values visible.

## D26 · P1 · Changing display units can drop the active AI credential

`toggleUnit` finishes by assigning `repo.getProfile()` directly to provider state. The Gemini key is deliberately excluded from Isar, so this profile does not carry the active key. The profile stream restores a key using the current state or the startup key, making the eventual result dependent on event order and potentially reverting a key updated during the session. Coach and food services derive their keys from this provider. [lib/providers/profile_providers.dart:21](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/profile_providers.dart:21>) [lib/providers/profile_providers.dart:54](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/profile_providers.dart:54>) [lib/models/user_profile.dart:31](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/models/user_profile.dart:31>) [lib/providers/app_providers.dart:280](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/app_providers.dart:280>)

This is a state-preservation problem, **not a discovered plaintext database-key leak**. The model's ignored field and secure-storage path are useful existing protections. Secure-storage write errors are currently swallowed by `updateGeminiKey`, so callers can also appear to finish setup when persistence failed.

**Implement:** separate credential state from the persisted profile, or preserve the current credential across every profile reload. Do not use a startup snapshot to overwrite a newer key. Return a persistence error when secure storage fails, keep the user's input recoverable, and define whether credentials are device-scoped or account-scoped. Do not put keys in cloud payloads, backups, logs, or screenshots.

**Verify:** start with key A, replace it with synthetic key B, toggle units, edit profile, reload providers, and restart. B remains active only when successfully stored. An injected write failure is visible. Use dummy strings, not actual credentials, in tests.

## D27 · P1 · Midnight rollover resets deliberate historical selection

The midnight timer invalidates `selectedDateProvider`, whose initializer returns today. That changes the date even when the user intentionally selected history. Several editors/notifiers read the global date at save time, so a sheet spanning midnight needs a captured editing date to prevent a context change from redirecting its save. Home does activate this timer; it is not dead code. [lib/providers/midnight_tick_provider.dart:24](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/midnight_tick_provider.dart:24>) [lib/providers/app_providers.dart:81](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/app_providers.dart:81>) [lib/providers/habit_providers.dart:31](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/habit_providers.dart:31>) [lib/screens/home/home_screen.dart:251](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/home_screen.dart:251>)

**Implement:** distinguish “following today” from an explicit historical date. Advance only the former, refresh the clock on resume/timezone changes, and capture the target date when opening an editor or starting an operation. Do not change an open edit's destination silently.

**Verify:** remain on today across midnight; browse a historical date across midnight; keep a habit/meal/weight editor open across rollover; resume after a timezone change. Labels, reads, saves, and share dates must agree.

## D28 · P2 · CSV habit export omits override-only records

Export iterates only `completion.completions.entries` and looks up overrides for those keys. An automatic habit with an explicit done/not-done override but no entry in the completion map is omitted. The repository can save overrides independently. The result is an incomplete export even though that habit's status is visible in the app. [lib/services/csv_export_service.dart:153](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/csv_export_service.dart:153>) [lib/repositories/habit_repository.dart:142](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/repositories/habit_repository.dart:142>)

**Implement:** export the union of progress/completion and override keys, with explicit source/type/units where needed. State that exported meal rows are slot aggregates rather than a food-by-food archive, or extend coverage if detailed export is intended. Include units for weight columns and report skipped malformed rows instead of silently implying a full export. Normalize requested date-range boundaries. Test spreadsheet-safe handling of user-entered strings using the actual CSV package/version; this pass did not establish a formula-execution vulnerability.

**Verify:** override-only auto habit, numeric progress, ordinary checkbox, deleted/renamed habit, quoted/multiline labels, and date-boundary records. Compare exported rows against the user's visible history.

## D29 · P1 · Overlapping coach requests can replace newer output; partial fallback can mix text

Coach generation has a date guard but no same-date request generation/token. Two refreshes for the same date can interleave; the slower earlier request can overwrite/save after the newer one. A date guard alone does not resolve that race. The coach service can emit partial AI text, switch to a local marker after failure, and emit a template; the consumer changes the `isAi` flag without clearing already accumulated text. This can save combined partial-AI/template output labeled local. [lib/providers/coach_note_notifier.dart:47](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/coach_note_notifier.dart:47>) [lib/providers/coach_note_notifier.dart:139](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/coach_note_notifier.dart:139>) [lib/services/coach_service.dart:84](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/coach_service.dart:84>)

**Implement:** capture date/account/request ID at initiation, cancel or ignore superseded work, and permit only the active generation to update state/cache/timestamps. Replace partial text when switching to fallback, or use an explicit structured event that defines replacement semantics. Do not display incomplete output as a successfully cached final note after failure.

**Verify:** two same-date requests completing in reverse order; change date/account midstream; AI emits a prefix then fails; dispose during generation. Only the active request may publish the final result.

## D30 · P1 if Sunday training is supported · Rest-day rule overrides the configured plan

The plan resolver can find a scheduled Sunday with exercises, but `isRestDay` returns true for every Sunday regardless of the resolved plan. Downstream day-completion logic then returns true for that day without exercise logs. [lib/utils/workout_completion.dart:10](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/utils/workout_completion.dart:10>) [lib/utils/workout_completion.dart:16](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/utils/workout_completion.dart:16>) [lib/utils/workout_completion.dart:79](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/utils/workout_completion.dart:79>)

**Implement:** let the configured schedule determine rest days. If Sunday training is intentionally unsupported, enforce that restriction visibly at plan creation/import instead of accepting a contradictory plan. Preserve the distinction between rest-day adherence and a completed training session in badges/phase counts.

**Verify:** Sunday training with zero/some/all logs; a weekday rest day; imported schedules; no-plan fallback. A scheduled training day should not become complete merely because it is Sunday.

## D31 · P1 release configuration · Missing signing configuration silently uses a debug key

The Android release signing block falls back to the bundled debug keystore when `key.properties` is absent. That properties file is absent in this archive and the debug keystore exists. A release build made from this snapshot without additional configuration therefore selects debug signing. No key material was opened or reproduced. [android/app/build.gradle.kts:35](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/android/app/build.gradle.kts:35>)

**Implement:** fail a distributable release build with a clear error when release signing is unavailable. Keep debug-signed development artifacts in an explicitly named development build path. Supply signing inputs through the project's approved local/CI secret mechanism. Verify the intended application identity and upgrade compatibility; do not rename the Android package merely to remove old internal branding.

**Verify:** missing release inputs fail clearly; valid signing produces the intended certificate; a debug build remains easy to run. Android build and installation were not executed here.

## Analysis closure and decisions for implementation

The source-analysis handoff now consists of the meal audit, the 58-screen-file UI inventory, the Daily Progress state audit, D01–D23, and these D24–D31 additions. Counts overlap across reports; they must not be added together as a count of unique bugs. The implementation ledger maps work by root cause to avoid fixing the same defect repeatedly.

Recommended defaults that prevent unnecessary design decisions during implementation:

- Historical editing stays on its explicitly selected date. Only a view following today rolls forward automatically.
- Observed zero, missing data, partial day, manual input, and sync failure remain distinct.
- A rest day may count as plan adherence, but not as a performed workout session.
- A scheduled habit streak counts consecutive eligible occurrences; retain a separate calendar-day activity streak if the product uses both.
- Keep one stable borderless Steps tile. Put connection troubleshooting and source detail in its detail surface.
- Keep user edits and older uncertain nutrition records recoverable during migration; do not silently recalculate or erase history with ambiguous basis.
- Use minimal purposeful motion with reduced-motion and haptic preferences respected.

These are implementation defaults, not claims about policies already present in the source. Record any deliberate product changes in the final implementation notes.

Actual-app screenshots, Flutter compilation/tests, Firebase rule deployment behavior, Health Connect/platform semantics, latency/accuracy benchmarks, and release signing verification are explicitly assigned to implementation acceptance. They are not left as an unbounded request for more source analysis. No finite source review proves the absence of every possible bug.
