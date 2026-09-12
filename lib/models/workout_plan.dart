import 'package:isar/isar.dart';

part 'workout_plan.g.dart';

@collection
class WorkoutPlan {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  final String planName;
  final List<WorkoutDay> days;

  WorkoutPlan({required this.planName, required this.days});

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      planName: json['planName'] as String,
      days: (json['days'] as List)
          .map((d) => WorkoutDay.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'planName': planName,
    'days': days.map((d) => d.toJson()).toList(),
  };
}

@embedded
class WorkoutDay {
  String? dayId;
  String? label;
  List<WorkoutSection> sections;

  WorkoutDay({this.dayId, this.label, this.sections = const []});

  int? get weekday {
    if (dayId == null) return null;
    switch (dayId?.toLowerCase()) {
      case 'monday':
        return DateTime.monday;
      case 'tuesday':
        return DateTime.tuesday;
      case 'wednesday':
        return DateTime.wednesday;
      case 'thursday':
        return DateTime.thursday;
      case 'friday':
        return DateTime.friday;
      case 'saturday':
        return DateTime.saturday;
      case 'sunday':
        return DateTime.sunday;
      default:
        return null;
    }
  }

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    return WorkoutDay(
      dayId: json['dayId'] as String,
      label: json['label'] as String?,
      sections: (json['sections'] as List)
          .map((s) => WorkoutSection.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'dayId': dayId,
    if (label != null) 'label': label,
    'sections': sections.map((s) => s.toJson()).toList(),
  };
}

@embedded
class WorkoutSection {
  String? title;
  List<Exercise> exercises;

  WorkoutSection({this.title, this.exercises = const []});

  factory WorkoutSection.fromJson(Map<String, dynamic> json) {
    return WorkoutSection(
      title: json['title'] as String,
      exercises: (json['exercises'] as List)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
}

@embedded
class Exercise {
  @ignore
  String? instanceId;

  String? name;
  String? displayName;
  String? youtubeUrl;
  List<String> reps;
  String note;
  String sideInfo;
  int restSecondsAfterSet;
  double? weightKg;
  int? durationSeconds;

  Exercise({
    this.name,
    this.displayName,
    this.youtubeUrl,
    this.reps = const [],
    this.note = '',
    this.sideInfo = 'None',
    this.restSecondsAfterSet = 0,
    this.weightKg,
    this.durationSeconds,
  });

  String? get youtubeVideoId {
    if (youtubeUrl == null || youtubeUrl!.isEmpty) return null;
    final uri = Uri.tryParse(youtubeUrl!);
    if (uri == null) return null;

    // Handle youtu.be/ID format
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }

    // Handle youtube.com/watch?v=ID or youtube.com/shorts/ID format
    if (uri.host.contains('youtube.com')) {
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'shorts') {
        if (uri.pathSegments.length > 1) {
          return uri.pathSegments[1];
        }
      }
      return uri.queryParameters['v'];
    }
    return null;
  }

  String get thumbnailUrl {
    final id = youtubeVideoId;
    if (id == null || id.isEmpty || id == 'XXXX') {
      return '';
    }
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  String get repsDisplay {
    if (durationSeconds != null && durationSeconds! > 0) {
      return '${durationSeconds}s';
    }
    if (reps.isEmpty) return '';
    final bool allSame = reps.every((r) => r == reps.first);
    if (allSame && reps.length > 1) {
      return '${reps.length} × ${reps.first}';
    }
    if (reps.length == 1) return reps.first;
    return reps.join(', ');
  }

  int get setCount => reps.length;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: json['name'] as String,
      displayName: json['displayName'] as String?,
      youtubeUrl: json['youtubeUrl'] as String?,
      reps: (json['reps'] as List).map((r) => r.toString()).toList(),
      note: json['note'] as String? ?? '',
      sideInfo: json['sideInfo'] as String? ?? 'None',
      restSecondsAfterSet: json['restSecondsAfterSet'] as int? ?? 0,
      weightKg: json['weightKg'] != null
          ? (json['weightKg'] as num).toDouble()
          : null,
      durationSeconds: json['durationSeconds'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (displayName != null) 'displayName': displayName,
    if (youtubeUrl != null && youtubeUrl!.isNotEmpty) 'youtubeUrl': youtubeUrl,
    'reps': reps,
    'note': note,
    'sideInfo': sideInfo,
    'restSecondsAfterSet': restSecondsAfterSet,
    if (weightKg != null) 'weightKg': weightKg,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
  };
}
