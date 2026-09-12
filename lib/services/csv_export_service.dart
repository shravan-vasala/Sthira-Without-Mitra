import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/daily_log.dart';
import '../models/exercise_log.dart';
import '../models/habit.dart';
import '../models/body_stats.dart';
import '../models/daily_meal_log.dart';

class CsvExportResult {
  final bool isSuccess;
  final String? filePath;
  final String? errorMessage;
  
  CsvExportResult({required this.isSuccess, this.filePath, this.errorMessage});
}

class CsvExportService {
  dynamic _sanitizeForCsv(dynamic value) {
    if (value is String) {
      if (value.startsWith('=') || value.startsWith('+') || value.startsWith('-') || value.startsWith('@') || value.startsWith('\t') || value.startsWith('\r')) {
        return "'$value";
      }
    }
    return value;
  }

  Future<CsvExportResult> exportData(DateTime? startDate) async {
    try {
      final archive = Archive();

      Future<void> addCsv(String name, String? csvText) async {
        if (csvText == null || csvText.isEmpty) return;
        final bytes = utf8.encode(csvText);
        archive.addFile(ArchiveFile.bytes(name, bytes));
      }

      final isar = Isar.getInstance();
      if (isar == null) return CsvExportResult(isSuccess: false, errorMessage: 'Database not initialized.');

      await addCsv('daily_logs.csv', await _exportDailyLogs(isar, startDate));
      await addCsv(
        'exercise_logs.csv',
        await _exportExerciseLogs(isar, startDate),
      );
      await addCsv(
        'habits.csv',
        await _exportHabitCompletions(isar, startDate),
      );
      await addCsv('body_stats.csv', await _exportBodyStats(isar, startDate));
      await addCsv('meals.csv', await _exportMeals(isar, startDate));

      if (archive.isEmpty) return CsvExportResult(isSuccess: false, errorMessage: 'No records found for the selected time range.');

      final zipData = ZipEncoder().encode(archive);

      final tempDir = await getTemporaryDirectory();

      // Cleanup old export files
      try {
        final files = tempDir.listSync();
        for (final file in files) {
          if (file is File && file.path.contains('trufit_export_') && file.path.endsWith('.zip')) {
            file.deleteSync();
          }
        }
      } catch (_) {}

      final fileName =
          'trufit_export_${DateTime.now().millisecondsSinceEpoch}.zip';
      final zipFile = File('${tempDir.path}/$fileName');
      await zipFile.writeAsBytes(zipData);

      return CsvExportResult(isSuccess: true, filePath: zipFile.path);
    } catch (e) {
      // ignore: avoid_print
      print('Export error: $e');
      return CsvExportResult(isSuccess: false, errorMessage: 'Export failed: $e');
    }
  }

  bool _isAfterStartDate(String dateStr, DateTime? startDate) {
    if (startDate == null) return true;
    try {
      final date = DateTime.parse(dateStr);
      return date.isAfter(startDate.subtract(const Duration(days: 1)));
    } catch (_) {
      return false;
    }
  }

  Future<String?> _exportDailyLogs(Isar isar, DateTime? startDate) async {
    final logs = isar.dailyLogs.where().findAllSync();
    final rows = <List<dynamic>>[];

    // Headers
    rows.add([
      'Date',
      'Weight (kg)',
      'Steps',
      'Steps Source',
      'Sleep Hours',
      'Sleep Source',
      'Body Fat',
      'Workout Completed',
      'Workout Day ID',
      'Water (ml)',
      'Screen Time (mins)',
      'Updated At',
    ].map(_sanitizeForCsv).toList());

    for (final log in logs) {
      try {
        if (!_isAfterStartDate(log.date, startDate)) continue;

        rows.add([
          log.date,
          log.weight ?? '',
          log.steps ?? '',
          log.stepsSource ?? '',
          log.sleepHours ?? '',
          log.sleepSource ?? '',
          log.bodyFat ?? '',
          log.workoutCompleted,
          log.workoutDayId ?? '',
          log.waterMl ?? '',
          log.screenTimeMinutes ?? '',
          log.updatedAt?.toIso8601String() ?? '',
        ].map(_sanitizeForCsv).toList());
      } catch (_) {}
    }

    if (rows.length == 1) return null; // Only headers
    return csv.encode(rows);
  }

  Future<String?> _exportExerciseLogs(Isar isar, DateTime? startDate) async {
    final logs = isar.exerciseLogs.where().findAllSync();
    final rows = <List<dynamic>>[];

    rows.add(['Date', 'Exercise', 'Set', 'Reps', 'Weight (kg)'].map(_sanitizeForCsv).toList());

    for (final log in logs) {
      try {
        if (!_isAfterStartDate(log.date, startDate)) continue;

        for (final set in log.sets) {
          rows.add([
            log.date,
            log.exerciseName,
            set.setNumber,
            set.reps,
            set.weight,
          ].map(_sanitizeForCsv).toList());
        }
      } catch (_) {}
    }

    if (rows.length == 1) return null;
    return csv.encode(rows);
  }

  Future<String?> _exportHabitCompletions(
    Isar isar,
    DateTime? startDate,
  ) async {
    final completions = isar.habitCompletions.where().findAllSync();
    final habitList = isar.habits.where().findAllSync();

    final habits = <String, Habit>{};
    for (final h in habitList) {
      habits[h.id] = h;
    }

    final rows = <List<dynamic>>[];
    rows.add(['Date', 'Habit ID', 'Habit Name', 'Value', 'Override'].map(_sanitizeForCsv).toList());

    for (final completion in completions) {
      try {
        if (!_isAfterStartDate(completion.date, startDate)) continue;

        for (final entry in completion.completions.entries) {
          final habitId = entry.key;
          final habitName = habits[habitId]?.name ?? habitId;
          final val = entry.value;
          final override = completion.overrides[habitId] ?? '';

          rows.add([completion.date, habitId, habitName, val, override].map(_sanitizeForCsv).toList());
        }
      } catch (_) {}
    }

    if (rows.length == 1) return null;
    return csv.encode(rows);
  }

  Future<String?> _exportBodyStats(Isar isar, DateTime? startDate) async {
    final statsList = isar.bodyStats.where().findAllSync();
    final rows = <List<dynamic>>[];

    rows.add([
      'Date',
      'Unit',
      'Waist',
      'Hips',
      'Chest',
      'Left Arm',
      'Right Arm',
      'Left Thigh',
      'Right Thigh',
      'Neck',
    ].map(_sanitizeForCsv).toList());

    for (final stats in statsList) {
      try {
        if (!_isAfterStartDate(stats.date, startDate)) continue;

        rows.add([
          stats.date,
          stats.unit,
          stats.waist ?? '',
          stats.hips ?? '',
          stats.chest ?? '',
          stats.leftArm ?? '',
          stats.rightArm ?? '',
          stats.leftThigh ?? '',
          stats.rightThigh ?? '',
          stats.neck ?? '',
        ].map(_sanitizeForCsv).toList());
      } catch (_) {}
    }

    if (rows.length == 1) return null;
    return csv.encode(rows);
  }

  Future<String?> _exportMeals(Isar isar, DateTime? startDate) async {
    final logs = isar.dailyMealLogs.where().findAllSync();
    final rows = <List<dynamic>>[];

    rows.add([
      'Date',
      'Slot',
      'Total Calories',
      'Total Protein (g)',
      'Total Carbs (g)',
      'Total Fat (g)',
    ].map(_sanitizeForCsv).toList());

    for (final log in logs) {
      try {
        if (!_isAfterStartDate(log.date, startDate)) continue;

        for (final entry in log.customSlots.entries) {
          final slotName = entry.key;
          final slot = entry.value;

          if (slot.totalCalories > 0 || slot.items.isNotEmpty) {
            rows.add([
              log.date,
              slotName,
              slot.totalCalories,
              slot.totalProtein,
              slot.totalCarbs,
              slot.totalFat,
            ].map(_sanitizeForCsv).toList());
          }
        }
      } catch (_) {}
    }

    if (rows.length == 1) return null;
    return csv.encode(rows);
  }
}
