import '../models/user_profile.dart';

String formatWeight(UserProfile profile, double weightKg) {
  if (profile.useKg) {
    return '${weightKg.toStringAsFixed(1)} kg';
  } else {
    final weightLb = weightKg * 2.20462;
    return '${weightLb.toStringAsFixed(1)} lb';
  }
}
