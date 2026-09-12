class SocialProfile {
  final String uid;
  final String name;
  final String? avatarUrl;
  final int todaySteps;
  final int todayWorkouts;
  final int currentStreak;
  final int weeklySteps;
  final int weeklyWorkouts;
  final String? latestBadge;
  final DateTime lastUpdatedAt;
  final List<String>? allowedReaders;
  final int? todayScore;
  final int? weekScore;

  SocialProfile({
    required this.uid,
    required this.name,
    this.avatarUrl,
    required this.todaySteps,
    required this.todayWorkouts,
    required this.currentStreak,
    required this.weeklySteps,
    required this.weeklyWorkouts,
    this.latestBadge,
    required this.lastUpdatedAt,
    this.allowedReaders,
    this.todayScore,
    this.weekScore,
  });

  factory SocialProfile.fromJson(Map<String, dynamic> json) {
    return SocialProfile(
      uid: json['uid'] ?? '',
      name: json['name'] ?? 'Unknown',
      avatarUrl: json['avatarUrl'],
      todaySteps: json['todaySteps'] ?? 0,
      todayWorkouts: json['todayWorkouts'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      weeklySteps: json['weeklySteps'] ?? 0,
      weeklyWorkouts: json['weeklyWorkouts'] ?? 0,
      latestBadge: json['latestBadge'],
      lastUpdatedAt: json['lastUpdatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastUpdatedAt'] as int)
          : DateTime.now(),
      allowedReaders:
          (json['allowedReaders'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      todayScore: json['todayScore'] as int?,
      weekScore: json['weekScore'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'avatarUrl': avatarUrl,
      'todaySteps': todaySteps,
      'todayWorkouts': todayWorkouts,
      'currentStreak': currentStreak,
      'weeklySteps': weeklySteps,
      'weeklyWorkouts': weeklyWorkouts,
      'latestBadge': latestBadge,
      'lastUpdatedAt': lastUpdatedAt.millisecondsSinceEpoch,
      if (allowedReaders != null) 'allowedReaders': allowedReaders,
      if (todayScore != null) 'todayScore': todayScore,
      if (weekScore != null) 'weekScore': weekScore,
    };
  }
}
