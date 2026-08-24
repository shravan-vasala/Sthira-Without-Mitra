import 'package:flutter/material.dart';

enum BadgeCategory { frequency, streaks, milestones, aiSupport }

class AchievementBadge {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final BadgeCategory category;
  final int progress;
  final int maxProgress;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const AchievementBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.category,
    required this.progress,
    required this.maxProgress,
    this.isUnlocked = false,
    this.unlockedAt,
  });
}
