import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trufit_bodamma/providers/app_providers.dart';
import 'package:trufit_bodamma/repositories/daily_log_repository.dart';
import 'package:trufit_bodamma/repositories/habit_repository.dart';
import 'package:trufit_bodamma/repositories/workout_repository.dart';
import 'package:trufit_bodamma/repositories/meal_repository.dart';
import 'package:trufit_bodamma/repositories/profile_repository.dart';
import 'package:trufit_bodamma/repositories/exercise_log_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../helpers/test_hive_setup.dart';

void main() {
  late ProviderContainer container;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpTestHive();

    final habitRepo = HabitRepository();
    await habitRepo.init();

    final dailyRepo = DailyLogRepository();
    await dailyRepo.init();

    final workoutRepo = WorkoutRepository();
    await workoutRepo.init();

    final mealRepo = MealRepository();
    await mealRepo.init();

    final logRepo = ExerciseLogRepository();
    await logRepo.init();

    final profileRepo = ProfileRepository();
    await profileRepo.init();

    container = ProviderContainer(
      overrides: [
        habitRepoProvider.overrideWithValue(habitRepo),
        dailyLogRepoProvider.overrideWithValue(dailyRepo),
        workoutRepoProvider.overrideWithValue(workoutRepo),
        mealRepoProvider.overrideWithValue(mealRepo),
        exerciseLogRepoProvider.overrideWithValue(logRepo),
        profileRepoProvider.overrideWithValue(profileRepo),
        initialGeminiKeyProvider.overrideWithValue(''),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestHive();
  });

  test('yearlyActivityHeatmapProvider returns 365 days of valid scores', () async {
    final heatmap = await container.read(yearlyActivityHeatmapProvider.future);
    
    expect(heatmap.length, equals(365));
    
    // Check that all scores are valid percentages (0 to 100)
    for (final score in heatmap.values) {
      expect(score, greaterThanOrEqualTo(0));
      expect(score, lessThanOrEqualTo(100));
    }
  });
}
