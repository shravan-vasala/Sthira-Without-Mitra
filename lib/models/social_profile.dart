class SocialProfile {
  final String uid;
  final String name;
  final String? avatarUrl;
  final int todaySteps;
  final int todayWorkouts;
  final int currentStreak;
  final String? latestBadge;
  final DateTime lastUpdatedAt;

  SocialProfile({
    required this.uid,
    required this.name,
    this.avatarUrl,
    required this.todaySteps,
    required this.todayWorkouts,
    required this.currentStreak,
    this.latestBadge,
    required this.lastUpdatedAt,
  });

  factory SocialProfile.fromJson(Map<String, dynamic> json) {
    return SocialProfile(
      uid: json['uid'] ?? '',
      name: json['name'] ?? 'Unknown',
      avatarUrl: json['avatarUrl'],
      todaySteps: json['todaySteps'] ?? 0,
      todayWorkouts: json['todayWorkouts'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      latestBadge: json['latestBadge'],
      lastUpdatedAt: json['lastUpdatedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastUpdatedAt'] as int)
          : DateTime.now(),
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
      'latestBadge': latestBadge,
      'lastUpdatedAt': lastUpdatedAt.millisecondsSinceEpoch,
    };
  }
}
