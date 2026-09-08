# Sthira: deeper technical and product audit

**Final handoff:** read the [D24–D31 additions](D:/from/boyd/meal-ai-audit-20260908/STHIRA_FINAL_ANALYSIS_ADDENDUM.md) alongside this report. The [master implementation prompt](D:/from/boyd/meal-ai-audit-20260908/MASTER_ANTIGRAVITY_PROMPT.md) incorporates the core, nutrition, design, Steps, and final requirements; use it as the single implementation entry point.

Reviewed 8 September 2026. Source: the supplied `Sthira-Without-Mitra-main (6) (1).zip`, extracted into the adjacent source directory. This report extends the earlier meal, UI, and Daily Progress audits. It does not claim that this archive is the latest version currently under development.

## Decision

**Fix data correctness, account isolation, sharing permissions, and restore safety before a visual redesign.** The app has useful foundations, but the supplied source does not yet justify calling meal calculation accurate, cloud sync reliable, or backup restore safe. Speed remains unmeasured. Several displayed scores and success messages can be misleading even when the UI looks consistent.

Your Steps observation was an important clue: the disconnected and connected states use different components. The same underlying problem appears elsewhere—different screens and services have different definitions of the same state, date, completion, or saved value.

Recommended release blockers are D01, D02, D03, and D06 below, plus the previously demonstrated meal-unit and workout-log overwrite defects. P0 here means fix before exposing the affected data/sharing/restore feature to users; it does not mean a production incident has been observed.

## Evidence and limits

- **Source defect:** a concrete implementation path contradicts its required behavior. File links identify the path. Execution in the actual app is still required to validate the fix.
- **Conditional failure:** the outcome requires a particular ordering, account transition, backend deployment, or input. The condition is stated rather than presented as an observed production event.
- **Product decision:** behavior requires a consistent policy, such as whether a habit streak counts calendar days or scheduled occurrences.
- Fourteen source-guarded Python models reproduce problematic decisions using synthetic data. These are **not Dart tests, Isar restore tests, Firebase emulator tests, or benchmarks**. See [evidence](<D:/from/boyd/meal-ai-audit-20260908/deep-audit-evidence.json>) and [reproduction script](<D:/from/boyd/meal-ai-audit-20260908/reproduce_deep_audit.py>).
- No Flutter/Dart SDK or Android runtime is available here. The outdated APK was excluded. Earlier browser images are labeled component proposals/source approximations, not screenshots of this app running. Native layout, accessibility semantics, jank, camera behavior, Health Connect, notifications, and deployed Firebase rules remain unverified.
- Attached comments and documents were inspected as evidence. The user's explicit **no borders** requirement takes precedence over the design document's outlined examples.

## A. Protect data and accounts first

### D01 · P0 · Queued data can be replayed into a different account

**Trigger:** account A has a failed write in the local queue; the same installation signs into B; a queue flush occurs and backend rules permit B to write B's private data.

Queue records contain `uid`, but `flushQueue` reads every record, deduplicates only by collection/document, and obtains the destination from the **current** auth user. It never checks the queued owner. A second defect records `_auth.uid` only when a delayed write fails, which can label A's earlier payload with B's identity after an account change. This is a source-level cross-account data path, not evidence of a live leak. [lib/services/firestore_sync_service.dart:89](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/firestore_sync_service.dart:89>) [lib/services/firestore_sync_service.dart:146](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/firestore_sync_service.dart:146>)

**Fix:** capture the owner and operation ID when saving; persist an account-scoped outbox atomically with the local mutation; bind destinations to that owner; stop/restart work on auth transitions; include owner in deduplication keys. Do not replay another user's queue merely because somebody is signed in.

**Acceptance test:** two synthetic accounts, the same document date, offline writes, an account switch during a pending request, and reconnect. No payload or acknowledgement may cross accounts. Test with Firebase emulator rules matching the intended private-data policy.

### D02 · P0 · Local storage has no deliberate account-switch boundary

Signing out calls the auth service, while the local repositories remain populated. The new-cloud-user branch then uploads local collections. A new account B can therefore inherit A's locally retained data unless a separate ownership boundary is introduced. The repositories' date-keyed records and the one shared Isar database do not establish that boundary. [lib/screens/profile/profile_screen.dart:918](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/profile/profile_screen.dart:918>) [lib/screens/profile/profile_screen.dart:721](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/profile/profile_screen.dart:721>) [lib/main.dart:71](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/main.dart:71>)

**Fix:** choose account-specific databases or explicit owner IDs enforced throughout queries. Provide a deliberate guest-data import decision on first sign-in. Preserve recoverable offline data; do not solve this with an unconditional database clear on sign-out. Reset account-derived UI state and subscriptions as part of switching accounts.

**Acceptance test:** A → sign out → guest → B → A, with both offline changes and existing cloud data. Verify local screens, uploads, friends, photos, and queued writes retain their correct owner.

### D03 · P0 · Friend acceptance markers can cause unauthorized sharing

The supplied rules allow either endpoint to create/update a friend-request document without validating its fields or the transition to `accepted`. Startup processing trusts every `accepted: true` marker and calls `acceptFriendRequest(fromUid)`, which adds that UID to the current user's readers **before** checking a corresponding legitimate outgoing request. An authenticated sender can therefore supply a marker that the recipient later treats as consent. [firestore.rules:10](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/firestore.rules:10>) [lib/providers/app_providers.dart:162](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/app_providers.dart:162>) [lib/services/social_sync_service.dart:90](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/social_sync_service.dart:90>) [lib/services/social_sync_service.dart:106](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/social_sync_service.dart:106>)

This path depends on these rules being deployed, marker processing running, and the recipient's social profile existing. No request was made to a live project. Its effect is access to the affected **social profile fields**, not demonstrated access to all private app records.

**Fix:** define a request state machine with immutable sender/recipient IDs and explicit recipient acceptance. Authorize transitions in rules or a trusted backend; validate allowed fields and types. Grant sharing only from a verified accepted relationship. A routine sender-controlled document must not act as proof of recipient consent. Firebase supports validating changed fields and types in rules. [Official field validation guidance](https://firebase.google.com/docs/firestore/security/rules-fields).

**Acceptance test:** emulator cases for forged acceptance, changed sender identity, replay, missing outgoing request, declined/revoked relationship, and legitimate acceptance. The first five must not grant access.

### D04 · P1 · Ordinary social updates erase the friends access list

`_pushProfile` constructs a `SocialProfile` without readers; its default is an empty list. `toJson` includes that list, and `pushProfile` writes it with merge enabled. Merge preserves omitted fields; it does not protect an explicitly supplied empty array. Consequently, an ordinary steps/profile update can replace existing readers with `[]`. The code comment claiming readers are preserved is incorrect. [lib/providers/app_providers.dart:250](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/app_providers.dart:250>) [lib/models/social_profile.dart:27](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/models/social_profile.dart:27>) [lib/models/social_profile.dart:68](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/models/social_profile.dart:68>) [lib/services/social_sync_service.dart:17](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/social_sync_service.dart:17>)

**Fix:** separate the public-statistics payload from relationship/permission data. Do not serialize permissions into routine profile pushes. Capture and verify the auth UID before the debounce; the callback currently uses a fresh `_auth.uid!`, allowing a logout null assertion or an A-payload/B-document write during a quick switch.

**Acceptance test:** establish two friends, update steps/name/score repeatedly, and verify both readers remain. Switch/logout before a debounce fires and verify no write targets a different identity.

### D05 · P1 · Friend acceptance is repeated, non-atomic, and tied to startup

The pending-acceptance processor calls the same method used by the request recipient. That method writes another acceptance marker back to the other user, so processing a marker can generate another marker. The workflow also grants access, deletes a request, and creates a marker in separate writes. A failure between them leaves partial state. The processor runs in a one-time microtask and does not observe auth changes, so signing in after signed-out startup does not necessarily process acceptances. Removal errors are logged and swallowed. [lib/providers/app_providers.dart:147](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/app_providers.dart:147>) [lib/services/social_sync_service.dart:106](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/social_sync_service.dart:106>) [lib/services/social_sync_service.dart:149](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/social_sync_service.dart:149>)

**Fix:** separate accepting a request from acknowledging acceptance; make both idempotent. Observe the authenticated identity and relationship stream. Use an atomic relationship transition where possible and expose pending/failed revocation until it is confirmed.

**Acceptance test:** interrupt each step, restart both clients repeatedly, sign in after startup, and retry remove-friend offline. No endless markers, duplicate friends, or false revocation success.

### D06 · P0 · Restore can clear the database with an empty payload; promised safety backup is absent

The verifier accepts a parseable manifest without checking `data.json`. Restore accepts a map, passes it through an identity migration function, clears Isar, and imports only recognized non-null keys. A ZIP containing a manifest and `data.json: {}` can therefore reach a successful empty replacement. Unsupported legacy keys can also import nothing. The UI promises a pre-restore safety backup, but the restore path does not create one. [lib/services/backup_service.dart:154](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/backup_service.dart:154>) [lib/services/backup_service.dart:243](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/backup_service.dart:243>) [lib/services/backup_service.dart:255](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/backup_service.dart:255>) [lib/services/schema_migration_service.dart:66](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/schema_migration_service.dart:66>)

The database replacement **does use an Isar transaction**; import exceptions can roll it back. That does not prevent a valid-looking empty map from committing. This was modeled without touching an actual database.

**Fix:** validate schema/version, required files, collection shapes, counts, record types, and media references before replacing anything. Reject unknown formats. Handle intentionally empty backups explicitly. Create and verify the promised safety backup before replacement. Stage and validate restored data, then commit with recovery available.

**Acceptance test:** empty map, manifest only, unknown version, incompatible legacy keys, invalid record, wrong password, corrupt media, and valid empty/full backups. Failed validation leaves all original records and media unchanged.

### D07 · P1 · Backup coverage and retention do not match a complete recovery workflow

The backup exports 16 collections but omits friends and app configuration. Restore clears the entire database, so omitted user-owned state and pending sync intents are lost. Cache exclusion is reasonable; it needs an explicit policy rather than treating every omitted collection alike. Media is restored after the database transaction, and photo failures still return `success: true` with a failure count. [lib/services/backup_service.dart:81](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/backup_service.dart:81>) [lib/services/backup_service.dart:276](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/backup_service.dart:276>)

Auto-backup runs at startup without a weekly time gate and retains only three archives. Several launches can rotate out older recovery points. Backup creation also uses a shared `backup_staging` directory and deletes it at the start, so overlapping automatic/manual exports can interfere. [lib/main.dart:156](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/main.dart:156>) [lib/services/backup_service.dart:69](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/backup_service.dart:69>) [lib/services/backup_service.dart:301](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/backup_service.dart:301>)

**Fix:** publish a collection/settings/media coverage manifest; include user-owned data or explicitly preserve it. Reconcile the outbox against restored data instead of blindly restoring or discarding stale operations. Use unique staging directories and an operation lock. Keep retention by useful time intervals, and distinguish complete recovery from partial media recovery.

**Acceptance test:** full round trip including friends/settings/media, overlapping export attempts, multiple same-day launches, and an injected photo-write failure. Verify recovery points remain usable.

### D08 · P1 · Deleted photos can remain on disk and re-enter backups

Saving stores a relative path under the app's media directory. Deletion removes the database row and then opens `File(photoPath)` directly, resolving that relative path against the process directory instead of the media root. Usually the file check fails and the real photo remains. Backups enumerate media files, so an orphan can still be included. [lib/repositories/media_repository.dart:33](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/repositories/media_repository.dart:33>) [lib/repositories/media_repository.dart:94](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/repositories/media_repository.dart:94>) [lib/repositories/media_repository.dart:145](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/repositories/media_repository.dart:145>)

**Fix:** use the shared absolute-path resolver and verify the resolved path stays under the media root. Make deletion failure visible/retryable. Export referenced media according to policy and provide a safe orphan-cleanup routine.

**Acceptance test:** save → delete → restart → export. Neither the metadata nor the corresponding image may remain in the export. Also test legacy absolute paths without deleting outside the media root.

## B. Make sync durable and truthful

### D09 · P1 · A successful queue batch can delete work that it never sent

Flush snapshots the queue, awaits its batch, then clears the **entire** queue. A new entry appended during that await is removed even though it was never part of the batch. Invalid JSON entries are silently skipped and then cleared too. There is no single-flight protection. [lib/services/firestore_sync_service.dart:151](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/firestore_sync_service.dart:151>) [lib/services/firestore_sync_service.dart:173](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/firestore_sync_service.dart:173>)

**Fix:** acknowledge only the exact operation IDs/revisions committed. Keep malformed records in a diagnosable failed state. Serialize flushes and batch within supported limits.

**Acceptance test:** append/update an operation while commit is blocked; release commit; verify new work remains. Repeat with concurrent flushes and one malformed payload.

### D10 · P1 · Pending writes and deletions are not durably ordered

Normal writes live in a three-second timer before reaching Firestore; only failures enter the application queue. `flushNow` flushes the queue, not these timers. Closing the process before a timer fires can leave a local change with no durable application sync intent. This is lost cloud delivery intent, not necessarily loss of the locally saved record. Profile-write failures are only logged. Deletes neither cancel pending upserts nor enter an offline delete queue; an earlier delayed upsert can recreate a just-deleted document. [lib/services/firestore_sync_service.dart:48](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/firestore_sync_service.dart:48>) [lib/services/firestore_sync_service.dart:82](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/firestore_sync_service.dart:82>) [lib/services/firestore_sync_service.dart:109](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/firestore_sync_service.dart:109>) [lib/services/firestore_sync_service.dart:122](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/firestore_sync_service.dart:122>)

**Fix:** persist writes and deletions first, then debounce delivery. Give deletes ordered tombstones or equivalent conflict semantics. `flushNow` should report actual pending work and confirmed results. Preserve Firestore's own offline behavior without assuming it can persist an operation that has not yet been submitted.

**Acceptance test:** save then terminate before three seconds; save then delete; delete offline then reconnect; profile write failure. No lost intent or resurrection.

### D11 · P1 · Duplicate sync instances and auth-independent subscriptions

`main` creates the service attached to repositories, while `firestoreSyncServiceProvider` creates another; the first instance is not supplied as that provider's override. Both construct connectivity listeners. Repository cloud listeners are attached only if already signed in during attachment; there is no account-lifecycle subscription management at that boundary. [lib/main.dart:130](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/main.dart:130>) [lib/main.dart:168](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/main.dart:168>) [lib/providers/auth_provider.dart:61](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/auth_provider.dart:61>) [lib/repositories/daily_log_repository.dart:11](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/repositories/daily_log_repository.dart:11>) [lib/repositories/meal_repository.dart:13](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/repositories/meal_repository.dart:13>)

**Fix:** inject one lifecycle-owned sync coordinator, observe auth identity, and retain/cancel subscriptions. Attach the correct account on sign-in and detach on sign-out. Make disposal explicit.

**Acceptance test:** startup signed out → sign in → cloud update; startup signed in → switch identity. Assert one coordinator/flush, no stale account listeners, and live updates for the active account.

### D12 · P1 · “Full sync” is incomplete and can report success after failures

The cloud-exists branch pulls profile and five collections. It does not pull habit configuration/completions, exercise history/PRs, badges, coach notes, or user foods. The empty-cloud branch uploads a different set. A single has-data boolean is not a bidirectional reconciliation strategy. Service methods swallow failures into empty maps, null, false, or a completed future, while the UI reports successful sign-in/sync. [lib/screens/profile/profile_screen.dart:690](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/profile/profile_screen.dart:690>) [lib/screens/profile/profile_screen.dart:666](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/profile/profile_screen.dart:666>) [lib/services/firestore_sync_service.dart:189](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/firestore_sync_service.dart:189>)

The supplied Firestore rules only match social profiles and friend requests; they contain no `users/{uid}` private-data match. If this is the deployed ruleset, the app's private cloud operations are denied. Deployment was not inspected. Firestore grants access through matching allow rules, so the required private paths need an explicit, tested policy. [Official rules structure](https://firebase.google.com/docs/firestore/security/rules-structure).

**Fix:** define a shared collection registry, per-collection progress/results, and reconciliation in both directions. Distinguish “cloud empty” from “could not read cloud.” Surface retryable failures and a last confirmed sync time. Do not broaden deployed permissions without testing the intended owner-only rules.

**Acceptance test:** fresh-device round trip of every advertised cloud collection; permission denial; offline check; one failed collection among successes. The UI must not call a failed/partial run fully synced.

### D13 · P1 · Cloud imports use inconsistent conflict rules

Live daily/meal listeners overwrite differing local records without comparing revisions. Manual daily import checks timestamps, but manual meal import only inserts missing dates. Thus a stale remote snapshot can replace a newer local edit on one path, while a newer remote meal can be ignored on another. [lib/repositories/daily_log_repository.dart:14](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/repositories/daily_log_repository.dart:14>) [lib/repositories/daily_log_repository.dart:159](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/repositories/daily_log_repository.dart:159>) [lib/repositories/meal_repository.dart:16](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/repositories/meal_repository.dart:16>) [lib/repositories/meal_repository.dart:195](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/repositories/meal_repository.dart:195>)

**Fix:** share one conflict policy across listeners, manual sync, and retries. Record revisions/ownership and pending local operations. Whole-day documents need an explicit strategy for concurrent changes to different fields/meal slots; timestamp-only last-write-wins can discard unrelated edits.

**Acceptance test:** two devices edit different fields on one date; delayed old snapshot; newer meal edit on an existing date; deletion versus retry. Document the expected result and verify convergence.

### D14 · P1 · Removing one meal slot may not remove its cloud value

The meal document serializes `customSlots` as a nested map. Generic sync uses merge writes. If breakfast is removed locally while lunch remains, the outgoing nonempty map contains lunch and omits breakfast; omission is not an explicit field deletion. Breakfast can remain in the remote document and return on import. [lib/models/daily_meal_log.dart:84](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/models/daily_meal_log.dart:84>) [lib/services/firestore_sync_service.dart:84](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/firestore_sync_service.dart:84>)

**Fix:** use an intentional replacement of the owned map, explicit deleted fields, or per-slot records with deletion semantics, coordinated with D13. Do not assume an omitted nested key means delete. Firebase documents merge writes, explicit deletion, and the special overwrite behavior of an empty map. [Official write semantics](https://firebase.google.com/docs/firestore/manage-data/add-data).

**Acceptance test:** store two slots, remove one, sync/restart/pull on another device. The removed slot must stay removed. Test remove-all separately because an empty map has different merge behavior.

## C. Make scores, history, and completion consistent

### D15 · P1 · Weekly history can stay cached after a save

The daily and meal range providers read synchronous repository snapshots and watch only the repository object. Mutating its data does not replace that object. The save paths do not invalidate these range families. A week already read can therefore keep old values even if another provider rebuilds the parent screen. [lib/providers/daily_log_notifier.dart:127](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/daily_log_notifier.dart:127>) [lib/providers/meal_providers.dart:52](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/meal_providers.dart:52>) [lib/providers/weekly_summary_provider.dart:107](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/weekly_summary_provider.dart:107>)

**Fix:** expose watched database range queries or an explicit data revision dependency. Use the same change source for charts, weekly summaries, and scores.

**Acceptance test:** read a week's provider, edit a meal/steps entry inside it, and read again without changing dates or manually invalidating in the test. The summary must update.

### D16 · P1 · Selecting a different day changes the same week's habit denominator

`habitsProvider` filters by the selected weekday. Weekly summary then reuses that filtered list for every date in the current and previous week. A Monday-only habit is counted across seven dates when Monday is selected and omitted when Tuesday is selected. Historical scoring also needs review wherever it reuses this provider. [lib/providers/habit_providers.dart:7](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/habit_providers.dart:7>) [lib/providers/weekly_summary_provider.dart:130](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/weekly_summary_provider.dart:130>) [lib/providers/weekly_summary_provider.dart:162](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/weekly_summary_provider.dart:162>)

**Fix:** obtain the full habit configuration and evaluate eligibility for each requested date. Decide how historical schedule/target edits take effect; do not silently recalculate an old week using an unrelated current configuration.

**Acceptance test:** Monday-only habit, one completion, select each day of that week. Scheduled instances and score remain invariant. Add habit creation/deletion midweek and a schedule edit.

### D17 · P1 · Badge streak counts stored records instead of adjacent dates

The badge engine walks stored logs backward while `hasAnyActivity` is true and increments a counter. It never checks date adjacency or whether the latest activity is current. Activity on September 1, 4, and 8 can count as a three-day streak. [lib/providers/badge_engine_provider.dart:58](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/badge_engine_provider.dart:58>)

**Fix:** calculate streaks from dates using one shared policy, an injected clock, and explicit treatment of today/yesterday. Keep lifetime unlocked badges distinct from current streak progress. Scheduled habits need a separate decision about whether non-scheduled days break a streak.

**Acceptance test:** gaps, no activity today, yesterday-only activity, backfilled records, and scheduled days. Three separated dates must not unlock a three-consecutive-day badge.

### D18 · P1 · Missing observations are treated as successful completion or ignored corrections

Screen-time progress defaults null to zero; an `atMost` habit then evaluates `0 <= target` as completed. A user without permission/data can receive completion credit. Separately, Health Connect updates only accept positive steps/sleep, so a successfully observed zero cannot correct an earlier positive synced value. [lib/models/habit.dart:319](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/models/habit.dart:319>) [lib/models/habit.dart:354](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/models/habit.dart:354>) [lib/repositories/daily_log_repository.dart:91](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/repositories/daily_log_repository.dart:91>)

**Fix:** represent missing, partial, observed-zero, permission-denied, stale, and manual values explicitly. Decide when an upper-limit habit is finalized; “within limit so far” should not be indistinguishable from a completed day. Preserve deliberate manual override precedence.

**Acceptance test:** denied permission, no observation, observed zero, correction from positive to zero, partial current day, completed prior day, and manual override.

### D19 · P1 · Social scores and trophy lists do not follow all relevant data changes

Social pushes listen to daily-log/profile changes but not meal/habit completion changes. They read the globally selected daily score while pushing today's log, allowing mixed-date statistics. Badge evaluation only listens to daily logs; its plain list provider has no dependency on saved badge revisions. The overlay can announce an unlock while the trophy list retains a cached list. [lib/providers/app_providers.dart:147](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/app_providers.dart:147>) [lib/providers/app_providers.dart:248](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/app_providers.dart:248>) [lib/providers/badge_engine_provider.dart:6](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/badge_engine_provider.dart:6>) [lib/providers/badge_engine_provider.dart:40](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/badge_engine_provider.dart:40>)

**Fix:** make score calculation explicitly date-addressed and observable; trigger social publication and achievements from the actual data changes they depend on. Refresh badge-list state from repository changes. Share one definition of calendar week with ranking and share cards.

**Acceptance test:** meal-only edit, habit-only edit, viewing yesterday while today's health data changes, and badge unlock while Trophy Room is open. All relevant surfaces must agree.

### D20 · P1 · Summary metrics confuse configured slots, logged content, and observed weight

`DailyStatsSnapshot` counts a meal when a configured plan slot's key exists, rather than using the same nonempty-content rule used elsewhere. Custom slots outside the plan can be omitted. Missing current/past weights fall back to target weight, creating a number or change based on a goal rather than measurements. [lib/models/daily_stats_snapshot.dart:116](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/models/daily_stats_snapshot.dart:116>) [lib/models/daily_stats_snapshot.dart:130](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/models/daily_stats_snapshot.dart:130>)

**Fix:** define logged-meal eligibility once, including custom slots and empty records. Preserve nullable measurements, show “No weigh-in,” and compute trends from dated observations under a documented window policy.

**Acceptance test:** empty configured slot, populated custom slot, deleted last food, no weigh-ins, one weigh-in, and observations away from exactly seven days ago.

## D. Behavior and verification gaps

### D21 · P1 · Updating reminders cancels an active workout rest notification

Reminder synchronization calls plugin-wide `cancelAll()` before scheduling its own reminders. The rest timer uses the same notification plugin with ID 1000, so it is canceled too and is not included in the reminder rebuild. [lib/providers/reminders_provider.dart:45](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/reminders_provider.dart:45>) [lib/services/notification_service.dart:202](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/notification_service.dart:202>)

**Fix:** cancel only IDs owned by the reminder subsystem. Preserve/reconcile the active timer's absolute deadline across startup and settings changes.

**Acceptance test:** start a rest timer, edit a meal reminder, background the app, and verify one rest alert at the original deadline.

### D22 · P2 · Permission and haptic preferences are not consistently respected

Reminder permission denial is ignored while toggles remain enabled, presenting an operational state that the OS does not permit. Rest countdown haptics during the last three seconds do not use the same vibration preference gate as completion. [lib/providers/reminders_provider.dart:38](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/reminders_provider.dart:38>) [lib/providers/rest_timer_provider.dart:172](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/providers/rest_timer_provider.dart:172>)

**Fix:** distinguish user preference from effective OS permission and provide a clear settings action. Apply a common preference gate to all nonessential haptics. Test denial and vibration-disabled states on a device.

### D23 · P1 · Current CI can be green without testing important persistence paths

The workflow uses Ubuntu and runs `flutter test`, but three suites replace their tests with an empty passing test on Linux: daily score, coach-note notifier, and exercise-card tests. It also has no analyze/build step. This is a validation gap, not proof every other test is ineffective. [.github/workflows/main.yml:5](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/.github/workflows/main.yml:5>) [test/providers/daily_score_provider_test.dart:22](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/test/providers/daily_score_provider_test.dart:22>) [test/providers/coach_note_notifier_test.dart:19](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/test/providers/coach_note_notifier_test.dart:19>) [test/screens/workout/widgets/exercise_card_test.dart:16](<D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/test/screens/workout/widgets/exercise_card_test.dart:16>)

**Fix:** pin a supported Flutter toolchain, run analysis and an Android build, and provide working Isar test binaries or a supported runner. Report unavoidable skips visibly. Add behavior tests around the specific critical failures and a Firebase emulator suite; a model serialization test cannot prove sharing security or sync convergence.

**Acceptance test:** CI must actually execute the persistence assertions and fail when the workout overwrite, account-routing, restore-validation, or provider-refresh defects are deliberately reintroduced.

## E. Previously found defects remain in scope

These are carried forward rather than presented as new discoveries. Their detailed source references and reproductions are in the linked earlier reports.

| Area | Concrete problem | Required outcome |
|---|---|---|
| Build/workouts | Workout screen has a missing relative import; entered exercise data is subsequently overwritten by planned values; exercise jump index is confused with section index | Build successfully; save exactly the entered set values once; route to the requested section and exercise |
| Meal AI | Unit/basis errors, weak serving interpretation, silent subset matching, lost provenance, stale correction/cache handling | One validated nutrition contract; grams and servings explicit; preserve source/confidence; corrections survive reuse |
| Meal editor | Redistribution can produce 125% and 625 g allocated for a 500 g plate | Allocations always sum to 100% and the requested mass; locked fields behave predictably |
| Onboarding/plans | Goal weight used as current weight; demographic/activity assumptions; preview and saved targets differ; cloud-sync stub looks active | Ask for or visibly handle missing inputs; preview and save the same calculation; real loading/error states |
| Profile/plans | Existing kg target can be divided by the pounds conversion again when current weight is missing | Store canonical units; convert exactly once at display/input boundaries |
| Progress | Calories/protein passed as null; body-fat action opens weight entry; screen-time add has no implementation | Connect each metric to its actual source and correct action |
| Steps | Disconnected square-like CTA changes into a full-width tile after connection; stale date/auth state and hidden manual values | One stable row across connection, loading, empty, manual, stale, denied, and history states |
| Habits/sleep | A previous done override can survive reducing sleep below goal; local timer has tick/drift issues | Explicit override/reset rules; deadline-based timer completion with deterministic saving |
| Social | Monday winner uses the first profile, which can be the current user; mixed today/selected-date and week definitions | Rank actual eligible values with clear ties/empty states and one date window |
| Sheets/history | “Today” labels can accompany selected-day writes or shares | Pass and display the same explicit date through list, detail, editor, and share image |
| Backup/photos/trophies | Busy states can stick or finish early; photo-save failure lacks recovery; share-badge action only closes a sheet | Honest operation states, retry, and implemented actions |
| Visual system | Border styling, inconsistent type/chevrons/radii, cramped physique row, poor CTA text contrast | Borderless shared components, readable contrast, responsive text and consistent navigation cues |

Detailed references: [meal audit](<D:/from/boyd/meal-ai-audit-20260908/MEAL_AI_AUDIT.md>), [58-screen-file UI audit](<D:/from/boyd/meal-ai-audit-20260908/STHIRA_UI_UX_AUDIT.md>), [Daily Progress state audit](<D:/from/boyd/meal-ai-audit-20260908/DAILY_PROGRESS_STATE_AUDIT.md>).

## F. What each page family should become

| Page family and subpages | Priority corrections | Scope for useful improvement |
|---|---|---|
| Onboarding: intro, goals, body inputs, plan preview, completion, sign-in | Fix input semantics, preview/save consistency, disposal, and cloud stub | Resumable steps; visible units; inline validation; optional permissions explained at the point of use |
| Home: hero, daily progress, habits, workout links, metric sheets | Explicit selected date; correct jump target; stable Steps tile; data-aware completion | One clear next action, consistent tile anatomy, detail sheets that explain source/last update without crowding Home |
| Meals: Today Meals, scanner, description entry, food search, plate editor, My Foods, history | Fix nutrition math/provenance and slot persistence before styling | Review recognized foods and quantities; editable uncertainty; reuse corrected foods; reversible deletion; clear logged versus planned totals |
| Workouts: plan, exercise details, log dialog, rest timer, history | Preserve entered sets; correct exercise identity/routing; reliable rest alert | Fast set entry, repeat-last-set action, local save feedback, easy correction and cancellation |
| Progress: charts, weekly summary, body stats, photos, compare/share | Reactive history; observed values; correct habit schedule/streak/date; photo deletion | Show missing-data gaps, observation dates and sources; consistent units; accessible chart summaries |
| Profile: edit, plans, habits, reminders, backup, cloud sync, trophies | Account boundary, restore validation, truthful sync state, usable share action | Understandable backup coverage, sync result details, permission-aware reminders, recoverable operations |
| Social: friends, requests, rankings, profile detail | Repair authorization and acceptance protocol; correct scoring/ranking | Pending/accepted/revoked states; freshness/date labels; transparent tie rules; friend removal confirmation based on actual result |

Use the actual Home hero and Today Meals patterns as references **after** correcting their own defects. Do not copy an inconsistency merely because it appears on a reference page. Keep one shared hero pattern and one shared metric tile, with variants only for meaningful hierarchy.

Your no-border direction applies throughout: distinguish surfaces with fill, spacing, typography, and hierarchy. Use the existing navigation chevron language for disclosure, a back chevron for backward navigation, and no chevron on a noninteractive statistic. Do not replace a button's action icon with a chevron just to make every icon identical.

## G. Meaningful microinteractions

Durations below are starting design proposals, not measurements of the current app. Respect reduced-motion settings and haptic preferences. Flutter exposes a platform animation-disable signal that app-authored motion should consider. [Flutter API](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html).

| Interaction | Recommended behavior | Why it earns its place |
|---|---|---|
| Tile/button press | Brief 100–150 ms tonal response; optional very small scale only where it preserves readability | Confirms the target received the touch |
| Habit completion | Checkmark plus a short progress transition after local save; one optional haptic | Connects the user's action with a saved result |
| Steps connection | Keep tile geometry fixed; change status in place; expose Connecting, Retry, Manual, and Last updated in detail | Communicates state without the current square-to-tile layout shift |
| Meal scan | Named stages such as Reading photo → Review foods; cancellable operation; no fabricated percentage | Explains a real wait and lets the user recover |
| Food quantity edit | Update totals together with a short subdued transition; keep text entry stable | Makes cause and effect legible while preserving precise input |
| Delete meal/set | Immediate reversible local action with Undo, backed by ordered sync | Reduces accidental loss and avoids disruptive confirmation for every edit |
| Sheet/navigation | One consistent 180–240 ms transition; preserve focus and scroll position | Helps orientation without a new animation on each page |
| New badge | One restrained reveal once, with an accessible dismiss action | Marks a meaningful event without repeating on every visit |
| Rest timer | Stable digits, clear pause/extend actions, preference-controlled final cue | Supports attention during exercise |

Skip looping hero shimmer, staggered animation of every tile, bouncing chevrons, chart replay on every tab switch, celebratory effects on routine saves, and animation that delays input. Fix missing handlers and wrong values before animating their containers.

## H. Reliability, speed, and accuracy of meal calculation

**Accuracy: insufficient in the supplied implementation.** Earlier deterministic cases produced 130 kcal instead of 195 for the fixture's 150 g rice, 180 instead of 540 for its 300 g biryani, and 25,100 kcal from parsing “200g white rice” as 200 servings. These are fixture-based arithmetic/parser results, not clinical nutrition reference claims. The code must preserve whether a value is per 100 g, per serving, or already a total.

**Reliability: insufficient evidence for production readiness.** Provenance and serving basis can be lost between scan, edit, save, and reuse; corrections/cache behavior and asynchronous error handling need the fixes in the meal audit.

**Speed: unknown.** The earlier timeout analysis found possible serial stage budgets around 80 seconds for text and 115 seconds for vision/fallback paths. These are configured worst-path allowances, not measured latency. Do not claim the service normally takes that long or that a model change alone solves the problem.

Measure a labeled fixture set covering common Indian meals, mixed dishes, quantity/unit variants, poor photos, ambiguity, provider failures, cold/warm cache, and canceled requests. Record end-to-end p50/p95, first useful review time, request count, fallback rate, parse failure, correction frequency, and quantity/nutrition error separately. Prioritize deterministic local matches where the quantity is known; ambiguous results should reach an editable review rather than silently inventing precision. See the [meal implementation prompt](<D:/from/boyd/meal-ai-audit-20260908/ANTIGRAVITY_PROMPT.md>).

## I. Implementation order and acceptance gates

| Phase | Work | Exit gate |
|---|---|---|
| 1 — Contain serious failures | Account ownership, friend consent/rules, durable queue, restore validation/safety, workout overwrite, nutrition units, missing import | Adversarial emulator/local persistence tests pass; malformed restore never destroys existing data; entered nutrition/workout values survive round trips |
| 2 — Establish consistent data behavior | Shared sync coordinator, collection registry, conflict/delete policy, reactive ranges, date-addressed scores, missing-data semantics | Two devices converge; edits refresh all dependent screens; history does not change with the selected weekday |
| 3 — Complete page states | Stable Steps tile, corrected handlers, dates, units, operation/error states, backup coverage, social ranking | Every reachable route/sheet checked with empty, loading, success, failure, and relevant permission/account states |
| 4 — Apply design and restrained motion | Shared borderless hero/tile/button/sheet styles, chevrons, contrast, responsive layouts, optional interactions above | Native screenshots at 320/360/412 logical widths and large text; no clipping, ambiguous actions, or reduced-motion regressions |
| 5 — Measure and maintain | CI/toolchain repair, real device tests, meal latency/quality dataset, runtime profiling, structured diagnostics | Publish actual test results and latency/accuracy measurements; release claims match evidence |

Avoid a whole-app rewrite. Extract a few shared contracts where disagreement is causing bugs: account ownership/outbox, date-addressed daily statistics, metric observation state, nutrition quantity/basis, and design components. Migrate one vertical flow at a time with existing data preserved.

Remaining runtime review should include Android permission revocation, app background/kill/resume, offline account switch, midnight/timezone changes, rapid repeated taps, canceled camera/file-picker actions, large histories, long labels, large text, keyboard/sheet interactions, and native share/export. Browser proposals cannot settle these checks.

The companion [implementation prompt](<D:/from/boyd/meal-ai-audit-20260908/STHIRA_DEEP_FIX_ANTIGRAVITY_PROMPT.md>) turns these findings into a staged engineering task with explicit acceptance criteria.
