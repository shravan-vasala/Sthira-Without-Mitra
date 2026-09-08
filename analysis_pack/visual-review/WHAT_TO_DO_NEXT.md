**Sthira: visual review and next actions**

**Completed analysis handoff:** [Start here](D:/from/boyd/meal-ai-audit-20260908/START_HERE.md). The [master prompt](D:/from/boyd/meal-ai-audit-20260908/MASTER_ANTIGRAVITY_PROMPT.md) now includes the final source findings and all earlier subject prompts. Use that entry point and its implementation checklist rather than running overlapping whole-app tasks.

**Latest priority update:** the [deeper technical audit](D:/from/boyd/meal-ai-audit-20260908/STHIRA_DEEP_TECHNICAL_AUDIT.md) identifies account-isolation, friend-permission, outbox, and restore-validation defects. Its implementation order supersedes the earlier visual sequence below: protect data and correct calculations first, then complete UI states and styling. Use the [consolidated implementation prompt](D:/from/boyd/meal-ai-audit-20260908/STHIRA_DEEP_FIX_ANTIGRAVITY_PROMPT.md) for the next development pass.

The user confirmed `sthira_design_system.md` is the correct reference. The old APK has been excluded from this review; it was not installed or used as evidence of the current UI. No Flutter SDK is installed in the checked environment.

**What is complete**

- Source review: all 58 screen-local files are covered by the [detailed audit](D:/from/boyd/meal-ai-audit-20260908/STHIRA_UI_UX_AUDIT.md), alongside shared components and relevant logic. This does not prove every runtime path is bug-free.
- Reference rendering: the embedded HTML in the design document has been rendered and visually inspected. Its old branding and decorative borders are visible contradictions to the user's intended Sthira style.
- Proposed design examples: six browser-rendered screens use the actual Cabinet Grotesk and General Sans fonts from the repository. They were captured and visually inspected. The first render exposed a navigation/content clearance problem in the preview itself; that was corrected, and Meal/Progress primary actions were moved into their own visible area above navigation.
- Browser checks: the six 360 px panels have no outer horizontal overflow, fonts loaded, the checked 390 px gallery viewport has no horizontal overflow, and no page JavaScript errors were reported. Main-preview content bounds do not overlap navigation. These checks apply only to the HTML previews. They are not Flutter layout, accessibility, native-control or performance tests.

**What remains unverified**

Actual current-app screenshots; pixel comparison against running Flutter; native keyboard/dialog behavior; real navigation and backend states; large text/screen-reader behavior; animation smoothness; and device-specific safe areas. Browser previews cannot establish these facts. A current build captured on a device, or a Flutter test/device environment, is needed for that part. The outdated APK would not answer these questions.

**Preview files**

- [All six examples in a scrollable gallery](D:/from/boyd/meal-ai-audit-20260908/visual-review/all-component-previews.html).
- [Home, Meals and Progress image](D:/from/boyd/meal-ai-audit-20260908/visual-review/proposed-components.png).
- [Onboarding, Profile and Social image](D:/from/boyd/meal-ai-audit-20260908/visual-review/more-proposed-components.png).
- [Original reference-document image](D:/from/boyd/meal-ai-audit-20260908/visual-review/original-design-reference.png).

These are design proposals with demonstration data, not reconstructions or screenshots of the current Flutter app. Controls illustrate the intended appearance; only the gallery/phone scrolling is implemented. Native Flutter rendering may differ. The six examples do not replace the subpage inventory in the audit.

**What should be done, in order**

| Order | Work | Definition of done |
|---|---|---|
| 1 | Correct the design reference | Use Sthira branding, remove contradictory outlined-pill/decorative-border examples, and record one set of card/input/button/sheet/type/chevron tokens. Preserve data marks such as chart lines and progress tracks. |
| 2 | Fix correctness before broad UI migration | Repair missing import, workout log overwrite, meal arithmetic and units, empty nutrient charts, incorrect entry actions, stale sleep completion, date context, restore state and misleading Social/cloud/share feedback. Regression cases in the audit must pass in the implementation environment. |
| 3 | Build consistent shared controls | One borderless navigation tile, filled input, tonal choice/secondary action, error state and keyboard-aware sheet. Explicit accessible action/selected semantics. Entire single-destination tiles are tappable. Use dark text on peach. |
| 4 | Apply those controls to active pages | Start with Home/Meals, then onboarding/entry sheets, Progress, Profile, Social and workout subpages. Keep data behavior and navigation intent consistent. Check before/after results rather than replacing every layout at once. |
| 5 | Add restrained feedback | Short selection, saved-state, completion and conditional-expansion transitions. Retain useful photo gestures. Remove decorative repetition. Reduced-motion state changes remain understandable. |
| 6 | Complete actual-app verification | Capture current Flutter pages/subpages and meaningful states; verify fonts, large text, small phones, keyboard, navigation/timer clearance, errors and empty states. Measure smoothness on an actual runtime before claiming it. |

**Specific design decisions I recommend**

| Area | Recommendation | Why |
|---|---|---|
| Home | Keep compact section counts and clear next actions. Use a consistent card anatomy and one chevron size. | Helps the user scan what is done and what is next without more decoration. |
| Meals | Keep one clear energy summary, readable macro labels/units, meal-slot tiles and a reachable Add meal action. Display the actual selected date. | The hierarchy should make both quantities and logging context clear. |
| Progress | Show range selection and whether the hero is an average, latest value or total. Include observation coverage and tooltip units. | A large number without aggregation/date context can mislead. |
| Onboarding | Separate current and goal weight. Avoid silently presenting default demographic/activity assumptions as personalization. Keep optional steps clearly optional. | The plan should reflect the inputs the user actually supplied. |
| Profile | Group profile/goals, connections and data/preferences. Use a unit selector rather than a chevron that toggles immediately. | Control appearance should predict behavior. |
| Social | Put requests in the same scroll flow as friends, use local accept/decline feedback and show actual last-update times. | Reduces layout pressure and prevents stale data from appearing live. |
| Forms/sheets | Persistent labels, explicit date/unit, inline validation and a stable Save action. Preserve draft data on error. | These affect task completion more than decorative changes. |
| Bottom actions | Reserve space for the action and navigation rather than covering content. Use fixed primary actions selectively on entry/logging flows. | Fixed controls improve reachability but consume vertical space; other content must remain scrollable. |

**Motion decisions**

Keep tab selection, a single completion check/haptic, save feedback, photo zoom and comparison dragging. Add short size transitions when form controls appear and when a real list item is inserted/removed. Remove repeated CTA shimmer, aura loops, old-badge shimmer, excessive whole-card shrink and slow dashboard count-ups. Do not animate historical numbers from zero or make an operation wait for a visual effect. Coordinate badge/day-complete feedback so one action does not trigger several celebrations.

The [updated Antigravity prompt](D:/from/boyd/meal-ai-audit-20260908/STHIRA_DESIGN_ANTIGRAVITY_PROMPT.md) contains the detailed implementation instructions. Use these previews as visual guidance alongside the audit, not evidence that the app already implements the proposed design.
