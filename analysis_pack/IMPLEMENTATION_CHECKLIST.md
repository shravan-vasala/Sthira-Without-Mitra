# Sthira implementation and acceptance checklist

Analysis is complete for the supplied archive; every checkbox below tracks implementation or acceptance, not more open-ended source analysis. D/F/meal findings overlap: use one fix with cross-references rather than inflating a unique-bug count.

For every item record: owner, changed files, migration impact, actual test/result, and remaining limitation. A checked box means behavior is verified or the current checkout is demonstrably already correct.

## Technical findings

- [ ] D01: Queued data can be replayed into a different account
- [ ] D02: Local storage has no deliberate account-switch boundary
- [ ] D03: Friend acceptance markers can cause unauthorized sharing
- [ ] D04: Ordinary social updates erase the friends access list
- [ ] D05: Friend acceptance is repeated, non-atomic, and tied to startup
- [ ] D06: Restore can clear the database with an empty payload; promised safety backup is absent
- [ ] D07: Backup coverage and retention do not match a complete recovery workflow
- [ ] D08: Deleted photos can remain on disk and re-enter backups
- [ ] D09: A successful queue batch can delete work that it never sent
- [ ] D10: Pending writes and deletions are not durably ordered
- [ ] D11: Duplicate sync instances and auth-independent subscriptions
- [ ] D12: “Full sync” is incomplete and can report success after failures
- [ ] D13: Cloud imports use inconsistent conflict rules
- [ ] D14: Removing one meal slot may not remove its cloud value
- [ ] D15: Weekly history can stay cached after a save
- [ ] D16: Selecting a different day changes the same week's habit denominator
- [ ] D17: Badge streak counts stored records instead of adjacent dates
- [ ] D18: Missing observations are treated as successful completion or ignored corrections
- [ ] D19: Social scores and trophy lists do not follow all relevant data changes
- [ ] D20: Summary metrics confuse configured slots, logged content, and observed weight
- [ ] D21: Updating reminders cancels an active workout rest notification
- [ ] D22: Permission and haptic preferences are not consistently respected
- [ ] D23: Current CI can be green without testing important persistence paths
- [ ] D24: Health history can be marked complete despite failed or denied reads
- [ ] D25: Android home-screen widget uses inconsistent targets and habit eligibility
- [ ] D26: Changing display units can drop the active AI credential
- [ ] D27: Midnight rollover resets deliberate historical selection
- [ ] D28: CSV habit export omits override-only records
- [ ] D29: Overlapping coach requests can replace newer output; partial fallback can mix text
- [ ] D30: Rest-day rule overrides the configured plan
- [ ] D31: Missing signing configuration silently uses a debug key

## Earlier functional findings

- [ ] F01 (P0): Workout screen imports a nonexistent local file.
- [ ] F02 (P1): Manual exercise sets are overwritten with planned sets.
- [ ] F03 (P1): Calories and Protein charts always have no data.
- [ ] F04 (P1): Monday's “last week” winner is fabricated by list position.
- [ ] F05 (P1): Restore loading state is incorrect.
- [ ] F06 (P1): Plate calculator can allocate 125% of a plate.
- [ ] F07 (P1): Recalculate can double-convert target weight in pounds mode.
- [ ] F08 (P1): Onboarding cloud setup reports progress without starting it.
- [ ] F09 (P1): Today's Social score can use a historical Home date.
- [ ] F10 (P1): Sleep completion can stay done after reducing sleep.
- [ ] F11 (P2): Workout deep-link parameters are conflated.
- [ ] F12 (P2): Progress entry controls do not match their labels.
- [ ] F13 (P2): Historical data is labeled as today.
- [ ] F14 (P2): Share Badge only closes the sheet.
- [ ] F15 (P2): Failed progress-photo save can leave Save disabled.
- [ ] F16 (P2): Onboarding animation lifecycle is incomplete.
- [ ] F17 (P2): Profile validation is weaker than onboarding.
- [ ] F18 (P2): Sync pending count is missing from its own message.

## Nutrition and shared interaction contracts

- [ ] N01: quantity/unit/per-100-g/per-serving/total arithmetic and plate invariants
- [ ] N02: provenance, estimates, user corrections, personal-food memory, and data-preserving migration
- [ ] N03: schema/value validation and ambiguity review instead of silent partial matches
- [ ] N04: cache versioning/invalidation, bounded requests, cancellation, classified errors, and fallback
- [ ] N05: labeled quality dataset plus measured cold/warm p50/p95 and correction rate
- [ ] UX01: shared borderless heroes, metric tiles, buttons, inputs, sheets, type and chevrons
- [ ] UX02: stable Steps tile across all eleven listed connection/data/date states
- [ ] UX03: correct dates, units, source/freshness labels, empty/error states and recovery
- [ ] UX04: actual handlers for every visible action, plus photo/meal/workout edit and delete recovery
- [ ] UX05: meaningful microinteractions, reduced motion, haptic settings, and focus/semantics
- [ ] UX06: 320/360/412 logical widths, large text, long labels, keyboard, sheets and safe areas
- [ ] UX07: all page-specific rows in STHIRA_UI_UX_AUDIT.md checked, including non-numbered findings
## Progress plotting acceptance

- [ ] G01–G12: complete the plotting review fixes, including overlaps with earlier findings.
- [ ] Execute all ten plotting fixtures with actual Dart/widget/native checks; preserve units, zero/missing distinctions, calendar trends, gaps, coverage and in-place selection.



## Screen-file implementation acceptance inventory

These 58 files are not 58 routes. For each, exercise reachable states or record that it is unused. Also inspect shared widgets/sheets and the native widget; screen-file presence alone does not prove runtime coverage.

- [ ] lib/screens/home/body_stats_screen.dart
- [ ] lib/screens/home/home_screen.dart
- [ ] lib/screens/home/meal_detail_screen.dart
- [ ] lib/screens/home/photo_compare_screen.dart
- [ ] lib/screens/home/photo_viewer_screen.dart
- [ ] lib/screens/home/physique_pictures_screen.dart
- [ ] lib/screens/home/share_preview_sheet.dart
- [ ] lib/screens/home/sleep_entry_dialog.dart
- [ ] lib/screens/home/steps_entry_dialog.dart
- [ ] lib/screens/home/water_entry_dialog.dart
- [ ] lib/screens/home/weight_entry_dialog.dart
- [ ] lib/screens/home/widgets/add_meal_slot_dialog.dart
- [ ] lib/screens/home/widgets/add_progress_photo_sheet.dart
- [ ] lib/screens/home/widgets/ai_meal_suggestion_card.dart
- [ ] lib/screens/home/widgets/coach_notes_card.dart
- [ ] lib/screens/home/widgets/daily_insight_card.dart
- [ ] lib/screens/home/widgets/daily_progress_grid.dart
- [ ] lib/screens/home/widgets/daily_score_sheet.dart
- [ ] lib/screens/home/widgets/daily_share_card.dart
- [ ] lib/screens/home/widgets/day_complete_sheet.dart
- [ ] lib/screens/home/widgets/habits_card.dart
- [ ] lib/screens/home/widgets/meals_card.dart
- [ ] lib/screens/home/widgets/past_day_summary_sheet.dart
- [ ] lib/screens/home/widgets/photo_calorie_scanner_sheet.dart
- [ ] lib/screens/home/widgets/sync_status_sheet.dart
- [ ] lib/screens/home/widgets/timer_entry_dialog.dart
- [ ] lib/screens/home/widgets/week_calendar_strip.dart
- [ ] lib/screens/meals/widgets/plate_calculator_sheet.dart
- [ ] lib/screens/onboarding/onboarding_screen.dart
- [ ] lib/screens/onboarding/pages/about_you_page.dart
- [ ] lib/screens/onboarding/pages/connect_page.dart
- [ ] lib/screens/onboarding/pages/goal_selection_page.dart
- [ ] lib/screens/onboarding/pages/welcome_page.dart
- [ ] lib/screens/onboarding/pages/your_plan_page.dart
- [ ] lib/screens/onboarding/widgets/sthira_aura_background.dart
- [ ] lib/screens/profile/backup_restore_screen.dart
- [ ] lib/screens/profile/manage_habits_screen.dart
- [ ] lib/screens/profile/manage_plans_screen.dart
- [ ] lib/screens/profile/profile_screen.dart
- [ ] lib/screens/profile/reminders_screen.dart
- [ ] lib/screens/profile/widgets/journey_stats_strip.dart
- [ ] lib/screens/profile/widgets/trophy_room_card.dart
- [ ] lib/screens/progress/progress_screen.dart
- [ ] lib/screens/progress/weekly_summary_screen.dart
- [ ] lib/screens/progress/widgets/activity_heatmap.dart
- [ ] lib/screens/progress/widgets/insights_card.dart
- [ ] lib/screens/progress/widgets/metric_overview_card.dart
- [ ] lib/screens/progress/widgets/shared_chart_card.dart
- [ ] lib/screens/progress/yearly_activity_screen.dart
- [ ] lib/screens/social/connect_screen.dart
- [ ] lib/screens/social/social_feed_screen.dart
- [ ] lib/screens/social/widgets/friend_status_card.dart
- [ ] lib/screens/workout/exercise_progress_screen.dart
- [ ] lib/screens/workout/log_data_dialog.dart
- [ ] lib/screens/workout/widgets/exercise_card.dart
- [ ] lib/screens/workout/widgets/rest_timer_label.dart
- [ ] lib/screens/workout/workout_screen.dart
- [ ] lib/screens/workout/youtube_player_screen.dart

## Final acceptance gates

- [ ] Analyze, actual persistence/widget tests, supported Android build; no hidden empty passing suites
- [ ] Firebase emulator: owner isolation, request authorization, retries, conflicts, ordered deletion and two-device convergence
- [ ] Isolated restore/export round trips and failure injection with original data intact
- [ ] Current-source native screenshots for routes, sheets and meaningful states; exclude old APK and HTML proposals
- [ ] Android health/usage/notification permissions, revoke/regrant, background/kill/resume, midnight/timezone and offline switching
- [ ] Release signing inputs and certificate/upgrade verification
- [ ] Measured meal quality/latency and runtime rendering performance, with environment/sample size
- [ ] Final change report maps every finding to evidence; production deployment is a separate action
