import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trufit_bodamma/providers/app_providers.dart';
import 'package:trufit_bodamma/repositories/coach_note_repository.dart';
import 'package:trufit_bodamma/repositories/daily_log_repository.dart';
import 'package:trufit_bodamma/repositories/habit_repository.dart';
import 'package:trufit_bodamma/repositories/meal_repository.dart';
import 'package:trufit_bodamma/repositories/profile_repository.dart';
import 'package:trufit_bodamma/repositories/workout_repository.dart';
import 'package:trufit_bodamma/repositories/exercise_log_repository.dart';
import 'package:trufit_bodamma/models/coach_note.dart';
import 'package:isar/isar.dart';
import '../helpers/test_isar_setup.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
void main() {
  late ProviderContainer container;
  late CoachNoteRepository coachNoteRepo;
  late Isar isar;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    isar = await setUpTestIsar();

    coachNoteRepo = CoachNoteRepository();
    await coachNoteRepo.init(isar);

    final profileRepo = ProfileRepository();
    await profileRepo.init(isar);

    final dailyLogRepo = DailyLogRepository();
    await dailyLogRepo.init(isar);

    final habitRepo = HabitRepository();
    await habitRepo.init(isar);

    final mealRepo = MealRepository();
    await mealRepo.init(isar);

    final workoutRepo = WorkoutRepository();
    await workoutRepo.init(isar);

    final exerciseLogRepo = ExerciseLogRepository();
    await exerciseLogRepo.init(isar);

    container = ProviderContainer(
      overrides: [
        coachNoteRepoProvider.overrideWithValue(coachNoteRepo),
        profileRepoProvider.overrideWithValue(profileRepo),
        dailyLogRepoProvider.overrideWithValue(dailyLogRepo),
        habitRepoProvider.overrideWithValue(habitRepo),
        mealRepoProvider.overrideWithValue(mealRepo),
        workoutRepoProvider.overrideWithValue(workoutRepo),
        exerciseLogRepoProvider.overrideWithValue(exerciseLogRepo),
        initialGeminiKeyProvider.overrideWithValue(''),
        selectedDateProvider.overrideWith((ref) => DateTime(2023, 10, 2)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestIsar(isar);
  });

  test('CoachNoteNotifier uses cache hit', () async {
    final note = CoachNote(date: '2023-10-02', note: 'Cached Note', isAi: false);
    await coachNoteRepo.saveNote(note);

    final asyncValue = container.read(coachNoteProvider);
    expect(asyncValue.value?.note, 'Cached Note');
  });

  test('CoachNoteNotifier force refresh bypasses cache', () async {
    final note = CoachNote(date: '2023-10-02', note: 'Cached Note', isAi: false);
    await coachNoteRepo.saveNote(note);

    container.listen(coachNoteProvider, (_, _) {});

    await container.read(coachNoteProvider.notifier).fetchNote(force: true);

    final asyncValue = container.read(coachNoteProvider);
    // Templated fallback uses the profile name (empty → "friend"), not "Bodamma"
    expect(asyncValue.value?.note, isNotNull);
    expect(asyncValue.value!.note.isNotEmpty, isTrue);
    expect(asyncValue.value?.note, isNot('Cached Note'));
    expect(asyncValue.value?.isAi, false);
  });

  test('CoachNoteNotifier fallback without API key', () async {
    container.listen(coachNoteProvider, (_, _) {});

    await container.read(coachNoteProvider.notifier).fetchNote(force: true);

    final asyncValue = container.read(coachNoteProvider);
    expect(asyncValue.hasValue, isTrue);
    expect(asyncValue.value?.note, isNotNull);
    expect(asyncValue.value!.note.isNotEmpty, isTrue);
    expect(asyncValue.value?.isAi, false);
  });
}
