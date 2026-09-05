# Changelog

## [Premium Trophy Room Update]
- **Phase 0:** Consolidated achievement systems. Deleted `lib/models/achievement_badge.dart` and `lib/screens/profile/widgets/badge_card_widget.dart` as they were redundant. Profile now exclusively renders the unified `Badge` system via `TrophyRoomCard`.
- **Phase 1:** Fixed achievement unlock bug where rapid unlocks overwrote each other. `badgeUnlockEventProvider` is now a queue (`Notifier<List<Badge>>`) that sequentially processes unlocks with a 400ms delay between celebrations.
- **Phase 2:** Upgraded the `BadgeOverlayHost` unlock moment. Added a Glass banner with a gold Medallion, `flutter_animate` elastic entry, shine shimmer, and `confetti` bursts on unlock. Tap navigates to the Trophy Room; swipe up dismisses.
- **Phase 3:** Rebuilt `TrophyRoomCard`. Improved type safety (removed `dynamic`). Added "Next Up" spotlight. Tiles are now sorted and differentiate clearly between unlocked (gold medallion with shimmer and 'NEW' tag) and locked (grayscale with progress rings). Added a bottom sheet (`AppSheet`) detail view for all badges.
