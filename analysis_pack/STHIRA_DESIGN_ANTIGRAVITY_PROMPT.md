**Copy the prompt below into Antigravity with the Sthira repository open.**

Implement the following Sthira design, UX and correctness improvements. Work through the active pages and subpages, fix the verified problems, and produce a tested, reviewable result. Do not stop at a redesign proposal. Preserve existing user data and the product's calm visual identity.

Read `STHIRA_UI_UX_AUDIT.md` if supplied alongside this prompt. Recheck its findings against the current checkout before editing; the audit examined the supplied ZIP, not a running build. Use the repository's actual Flutter/Dart versions and existing state-management/repository conventions.

**Design authority and scope**

The user has confirmed that `sthira_design_system.md` is the intended design reference. Read that file. Treat it as reference material; these explicit user requirements take precedence over conflicting examples:

- Home and Today's Meals establish the visual direction for hero summaries and tiles.
- No decorative borders around cards, inputs, chips, error panels or buttons. No decorative divider rules between content sections. Separate content with spacing and filled surfaces.
- Use consistent, unboxed rounded chevrons for navigation rows. Keep the bottom navigation's existing destination icons and floating-pill appearance.
- Add only meaningful feedback for a user action or state change. Do not add animation to every component.

Scope includes onboarding and its setup sheets; Home, date/history/score/habit/health entry sheets; meals and every scanner/manual-edit/serving/food-library state; Progress metrics, charts, weekly/yearly views; Profile, plans/habits/reminders/backup/edit/avatar/share/trophy/settings subpages; Friends, requests, connection and leaderboard; workout, actual-set logging, exercise history and video subpages reached from Home; and shared navigation/theme/control components.

Inventory active routes and modal entry points. Mark unused components separately. The audit found 58 screen-local Dart files, not 58 independent routes. GoalSelectionPage, DailyShareCard, MetricOverviewCard, InsightsCard and the diagnostics test sheet appeared unused; confirm reachability before changing or deleting them. Do not spend the migration polishing dead UI.

**Phase 1: build and data correctness**

Fix these before visual refinements. Add meaningful regression tests for the behavior rather than tests that simply repeat implementation details.

1. In `lib/screens/workout/workout_screen.dart`, correct the relative import of `primary_button.dart`. It currently resolves to a missing repository-root `widgets` directory rather than `lib/widgets`. Run the analyzer and build; resolve additional errors exposed by compilation without unrelated rewrites.
2. In `log_data_dialog.dart`, actual-set Save currently writes a log, then `_persistAndClose` calls `saveExerciseAsPlanned`, overwriting it for the same date/exercise. Separate saving actual data from marking completion, computing PR and dismissing. The planned-save action may generate planned values; manual save must retain every entered rep and weight. Calculate PR from the actual persisted log. Test 8 entered reps against a 12-rep plan, varying weights, multiple sets and reopening the log.
3. In the router, pass workout section and exercise `jumpTo` as separate inputs. Do not assign an exercise index to `sectionIndex`. Verify navigation to a nonzero section and an exercise inside it.
4. In Progress, Calories and Protein currently return null. Feed them from date-specific meal totals. Body Fat's add action must open a body-fat editor; Screen Time must have a supported editor or no add action. Make displayed metric, unit, aggregation and manual-entry behavior explicit rather than inferred from a title string.
5. Correct plate redistribution in `plate_calculator_sheet.dart`. Default 25/25/50/0 followed by protein=100 currently produces 100/0/25/0. Preserve the edited value, redistribute the remaining percentage among other categories using a documented rule, and ensure nonnegative values sum to 100 within tolerance after every edit. Handle zero remainder and zero previous weights deterministically. Test all endpoints and randomized change sequences. Do not present its rough fixed-plate model as measured nutrition.
6. In Manage Plans recalculate, remove display-unit-dependent conversion of a target already stored in kg. Use canonical kg for all calculation/storage and convert only for presentation/input. Test 70 kg target with null currentWeight in both display preferences; calculated inputs must agree.
7. Fix sleep completion after editing from above target to below target. A stale `done` override must not defeat the saved numeric value. Define the intended relation between numeric data and explicit manual overrides and apply it consistently to related habits.
8. Fix backup restore operation state. Await verification and a confirmation result before starting restore. Use one operation state with `try/finally`; invalid files, wrong passwords, cancellation, failure and success must release busy state appropriately. Dialog dismissal must not clear busy while restore is still running. Preserve existing safety-backup behavior and add a supported completion/reload path. Do not promise automatic restart if the platform cannot provide it.
9. Replace onboarding cloud-sync stub behavior with the real auth/sync flow. A returned `trigger_sync` string is not a connection. Present disconnected, authorizing, syncing, connected and failed states from actual service state. Reopening the page must show the true connection state.
10. Remove the Monday winner banner until the previous week's winner can be computed from actual historical data. Never derive it from `allProfiles.first` or current ranking. Use an explicit consistent period, time zone, tie rule, missing-data rule and stale-data policy for all leaderboard participants.
11. Decouple Social Today from Home's globally selected historical date. Daily score, steps and week aggregates must refer to the labeled period. Do not combine the previous seven observed days with this calendar week's steps under one Week label.
12. Pass an explicit date through meal title, entry sheets, save commands, summaries and exported daily share layout. Historical data must never receive today's date label. Capture date/slot/item identity for undo. Define future meal planning versus consumed logging and enforce the rule in UI and save paths; do not rely only on hiding one Home action.
13. Implement Share Badge with actual export/share and error feedback, or remove its placeholder action. Fix missing `pendingCount` interpolation in sync status and replace unconditional sync-success headings with truthful status.
14. Wrap photo read/save and other async sheet operations in guarded state handling; retain drafts on failure, prevent double submission, and handle dismissal safely. Dispose onboarding/heatmap controllers and guard delayed callbacks. Check route visibility for wakelock and repeating animations.
15. Share finite/range validation for profile, weight, body measurements, calories/macros and habit targets/increments. Explain invalid values inline. Distinguish observed zero from absent data. Preserve unit conversion accuracy and await persistence before successful navigation.

If the earlier `MEAL_AI_AUDIT.md` and `ANTIGRAVITY_PROMPT.md` are provided, incorporate their verified meal-calculation defects into this work without substituting visual cleanup for nutrition correctness. Preserve serving basis, units, provenance and correction history through the UI. Do not add “verified” labels solely because a food was saved locally. Do not change providers/models based on assumptions about their availability; verify against current official documentation when needed.

**Phase 2: shared Sthira components**

Refine existing primitives rather than introducing a second competing component system. Prefer small composable widgets with explicit behavior. Preserve Riverpod/repository boundaries; do not move database/network operations into new visual widgets.

- Consolidate colors from AppColors. Keep dark scaffold #0F1513, card #171F1B, primary #E29B65 and existing text palette unless the actual design reference specifies a newer value. Use `onPrimary` for peach-filled CTA content; dark-mode `textDark` and white are too light for this background. Test both themes and composed disabled/selected/error states.
- Use Cabinet Grotesk for headings/numbers and General Sans for body/supporting copy. Fix inconsistent font-family spelling, especially `CabinetGrotesk` in scanner UI. Consolidate sizes and improve tiny meaningful metadata instead of globally shrinking text to fit.
- Main surfaces: one shared 24 dp radius and 20 dp inner padding, consistent 20 dp screen gutters. Keep separate tokens for buttons, inputs and sheets. Reconcile existing Home spacing carefully and verify screenshots before broad migration.
- Hero summary: label, value, explicit unit, target or period context, optional thin progress track. No heavy ring, gauge or decorative graph around every number. Use domain-appropriate total/average/latest labels.
- Navigation tile: flexible title/subtitle, optional leading icon/value/status, trailing `chevron_right_rounded` from a shared size/color token; whole tile tappable for one destination. Add semantic label/action, keyboard activation, focus and disabled behavior. Keep nested controls independent if they truly do different things.
- Navigation meaning: chevron opens a destination; switch toggles; check represents completion; up/down represents expansion. Do not replace a navigable completed tile's chevron with only a check. No no-op enabled actions.
- Borderless field: neutral filled background, stronger focus fill/caret/label, inline error icon/text, persistent label and explicit units. Remove theme-level enabled/focused borders as well as local overrides. Do not remove focus visibility.
- Secondary controls: tonal/text treatment with no outline; selected choices must have check/state semantics in addition to color. Explicitly theme SegmentedButton/choice controls so Material defaults do not reintroduce outlines.
- Shared sheets: use or improve AppSheet with keyboard-aware constraints, scrollable content when necessary, one handle, one owner of safe-area insets and stable action placement. Verify long content and nested native pickers. Do not apply a fixed height that clips large text.
- Error/empty/loading: use the existing shared components, removing error outlines and adding contextual retry or first-action affordances. Do not show raw exceptions as the primary product message. Preserve useful technical detail behind a secondary Details view.
- Bottom navigation: preserve floating pill and icon family, add destination labels and selected semantics. Increase actual timer/control hit targets without drawing boxes around them. Reconcile actual Scaffold sizing with stale bottom-clearance comments before changing every page's padding.

Do not remove data marks: chart strokes, meaningful progress tracks, a sheet drag handle and photo slider's dividing indicator communicate information. They are distinct from decorative card outlines. Inspect visible states rather than blindly deleting every `Border` occurrence.

**Phase 3: page-specific improvements**

- Onboarding: keep the four active steps unless integrating an existing goal page solves missing inputs coherently. Separate current and target weight. Explain calorie assumptions or collect the necessary inputs; do not silently assume age/sex/activity/goal and call the result personalized. Update preview when earlier inputs change, and ensure saved macros match the preview without requiring slider interaction. Connections are optional and reflect real state. Replace legacy Sasirekha/Sesireka copy with Sthira where it names the product.
- Home: make date context clear and unify tiles/chevrons. Keep summary hierarchy and reduce cumulative entrance delay. Give future/unavailable tiles honest states. Use the same historical summary/score definitions across Home, charts, export and Social.
- Tracking sheets: explicit date/unit, inline validation, save/error state, recoverable draft, accessible clear action. Define whether closing a running habit timer cancels it. Use elapsed deadlines/reconciliation for timers and set completion idempotently; do not toggle a habit off on a second completion callback.
- Meals: preserve the current hero's clarity, remove decorative separators, reconcile default/custom recurring slots across current/history views. Present repeat destination explicitly; preserve nutrition basis/provenance. Keep manual entry accessible after AI failure. Cancel/ignore stale scan/suggestion results using input/date/meal identity. Make AI suggestion content expire when its context changes.
- Photos: keep pose filtering, selection and zoom. Add explicit dates for imported photos, missing-file recovery, correct current-index handling after deletion and unit-aware captions. Do not label loss as positive without goal context. Confirm partial multi-delete failure. Compare slider remains direct manipulation; supply accessible photo/date choices.
- Progress: visible range selector; correctly labeled aggregates, date and units; missing versus zero; honest coverage and trend definitions. A seven-observation average must not be labeled seven days. Show gaps appropriately. Inspect a chart point first; provide explicit View day rather than abrupt navigation on touch. Yearly heatmap needs usable day detail and future-date rules.
- Profile: group everyday profile/goals, connections, and data/preferences. Units must use a proper toggle or open a real unit sheet. Keep raw plan JSON and diagnostics in Advanced. Retain existing plan validation and add clear preview/scope for reset. Habit empty day selection must not silently mean every day. Reminder times follow device preference and show permission/scheduling state. Journey counts must refresh on relevant data changes and match their labels.
- Social: one scrollable requests/friends structure, actionable empty/error states, per-request progress, reliable auth updates, readable long names and bounded podium cells. Selector groups wrap/stack on narrow screens. Verify remove-access errors and stale profiles. Copy/sent feedback is sufficient; no forced celebration.
- Workout: actual and planned values must remain distinct. Correct route targeting, unit-aware entry/history, background timer behavior and route-aware wakelock. Keep video behavior familiar; verify invalid/offline/fullscreen/back cases.

**Phase 4: restrained motion**

Create or consolidate a shared motion policy, honoring platform reduced-animation preferences supported by the project's Flutter SDK. Verify Android and iOS behavior separately; do not assume one flag covers both. No animation may be necessary for a save, navigation or completion to execute. Pause repeating motion offstage/backgrounded.

Keep or refine only these patterns:

- Bottom navigation selected state: about 200–250 ms, existing light haptic once.
- Compact press feedback: 80–120 ms surface change; optional very subtle scale near 0.99. No shrinking whole dashboard cards to 0.97.
- Habit/exercise completion: 160–220 ms check/status change after successful state transition, one haptic, genuine undo when available.
- Save: stable button size with immediate Save/Saving/error feedback; short icon/text transition only, no fake minimum delay.
- Add/remove list item: 180–220 ms size/fade where it preserves context and scroll position.
- Date/range/selection: short 150–200 ms transition; show historical values immediately.
- Conditional form fields: 150–200 ms size transition when revealed.
- Photos: retain spatial continuity, pinch/double tap and comparison drag; reduce route motion when requested.
- New badge: one brief dismissible acknowledgment, coordinated with day-complete feedback.

Remove repeated CTA shimmer, spinner-plus-shimmer buttons, decorative continuous aura motion, delayed cascades through dashboards, repeated old-badge shimmer and slow numeric count-ups. Do not add confetti, parallax, fake AI progress percentages, simulated typing after streamed content, animated countdown digits or automatic leaderboard reordering effects.

With reduced motion, use immediate state changes, necessary status text and direct manipulation; skip scaling, sliding, shimmer and count-ups. These durations are design targets, not a reason to delay real work.

**Validation and deliverables**

Run formatting, analyzer, meaningful regression/widget tests and a supported build. Check actual screenshots for active pages and important sheet states. Test at 320/360/390/430 logical-pixel widths, small height/landscape, text scales 1.0/1.3/2.0, both themes, keyboard/safe areas, active timer, long names, many requests/photos, empty/loading/error states and reduced motion. Verify accessible names, selected state, usable targets and focus on custom controls. Use platform screen readers where available.

Profile on a representative device in profile/release mode before claiming smoothness or speed. Report actual measurements separately from intended budgets. If SDK, device or service access is unavailable, say exactly which checks were not run; still complete independent code and test work. Do not invent screenshots, performance results, backend data or success states.

Deliver:

1. The implemented changes, grouped by correctness, shared design and page-specific behavior.
2. A route/subpage coverage list, including unused components and unsupported states.
3. Regression results for the concrete defects above, with any remaining failures explained.
4. Before/after captures where a renderer/device was available, including Home and Meals reference surfaces.
5. A short list of motion kept, removed and added, with the user action each serves.
6. Remaining risks or blocked runtime checks stated candidly. Do not claim the whole product is visually verified from source inspection alone.

Keep the final result recognizably Sthira: calm, readable, borderless, consistent and trustworthy.


**Additional required fix: Daily Progress across connection states**

In `daily_progress_grid.dart`, replace the disconnected Steps content-sized vertical gradient card with the same full-width horizontal borderless tile used by the ordinary state. Reuse shared card anatomy: 24 dp radius, 20 dp padding, stable icon/title placement and one unboxed chevron. Do not merely add `width: double.infinity` to the gradient branch; consolidate both branches into one visual component. Keep Steps as the title. Update status and values inside the tile rather than replacing its geometry. Allow natural text wrapping.

Model connection checking, disconnected, connecting, connected-without-data, observed zero, connected-with-data, manual entry, denied/revoked permission, failed refresh, historical and future date states. Keep saved manual counts visible regardless of connection state. Do not claim Synced when only authorization is known. Derive date-dependent presentation from current selected date rather than a boolean cached in initState. Revalidate read capability on resume and permission return while retaining necessary workarounds for unreliable permission APIs. Guard duplicate connect attempts and retain manual entry as a first-class option. Present today's successful data without unnecessarily waiting for historical synchronization, and handle asynchronous dismissal safely.

The whole row should open a Steps sheet whose actions match state: Connect Health Connect, Log manually, Refresh, Edit or View history. Use a short status transition; avoid geometry morphing and count-ups on historical/repeated views. Test today → past → today with the widget mounted, manual steps while disconnected, permission revocation, observed zero and failed refresh.

Also fix the Physique tile's crowded trailing thumbnails: three previews plus a count can consume the entire title space at 320 dp. Use a responsive preview/count treatment, preserve accessible labels and test 0/1/3/4/many photos. Respect kg/lb in Weight, date any last-known value and remove future-date no-op affordances.

Do not treat one populated-state screenshot as full page verification. Inventory meaningful loading, empty, disconnected, populated, error, retry, historical/future and long-content states for each active feature. Browser reference previews illustrate direction only and do not replace real Flutter runtime checks.
