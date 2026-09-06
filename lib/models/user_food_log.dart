import 'package:isar/isar.dart';

part 'user_food_log.g.dart';

@collection
class UserFoodLog {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  final String normalizedName; // e.g., "idli", "sambar", "chicken curry"

  final String originalName;

  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  final DateTime addedAt;

  UserFoodLog({
    required this.normalizedName,
    required this.originalName,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'name': originalName,
        'kcal': kcal,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      };
}
