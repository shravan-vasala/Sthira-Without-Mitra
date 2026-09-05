# Changelog

## [Premium Trophy Room Update]
- **Phase 0:** Consolidated achievement systems. Deleted `lib/models/achievement_badge.dart` and `lib/screens/profile/widgets/badge_card_widget.dart` as they were redundant. Profile now exclusively renders the unified `Badge` system via `TrophyRoomCard`.
- **Phase 1:** Fixed achievement unlock bug where rapid unlocks overwrote each other. `badgeUnlockEventProvider` is now a queue (`Notifier<List<Badge>>`) that sequentially processes unlocks with a 400ms delay between celebrations.
- **Phase 2:** Upgraded the `BadgeOverlayHost` unlock moment. Added a Glass banner with a gold Medallion, `flutter_animate` elastic entry, shine shimmer, and `confetti` bursts on unlock. Tap navigates to the Trophy Room; swipe up dismisses.
- **Phase 3:** Rebuilt `TrophyRoomCard`. Improved type safety (removed `dynamic`). Added "Next Up" spotlight. Tiles are now sorted and differentiate clearly between unlocked (gold medallion with shimmer and 'NEW' tag) and locked (grayscale with progress rings). Added a bottom sheet (`AppSheet`) detail view for all badges.

## [AI Architecture Simplification]
- **Root Cause & Fix:** The `useFirebase` flag silently rerouted signed-in users from their Google AI Studio API key to a deactivated Firebase Vertex AI backend, causing food scanning and coach generation to fail. The entire Firebase path has been stripped. All AI features now exclusively use the user's provided Gemini API key.
- **Error Hygiene:** Upgraded `AiErrorCause` classifier to intercept `PERMISSION_DENIED`, `SERVICE_DISABLED`, and deactivated keywords, mapping them to a clear human-readable message instructing the user to check their Google AI Studio project status.
- **Settings Clarity:** Cleaned up the AI Setup Sheet in the Profile screen to clearly state that food scanning and coach depend on the Gemini API key, removing outdated statements about Cloud Sync exceptions.
