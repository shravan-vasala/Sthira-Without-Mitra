import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/scanned_meal_log.dart';

class PhotoMealRepository {
  late Isar _isar;
  late String _baseDir;

  Future<void> init(Isar isar) async {
    _isar = isar;
    if (!kIsWeb) {
      final appDir = await getApplicationDocumentsDirectory();
      _baseDir = '${appDir.path}/trufit_meal_photos';
      await Directory(_baseDir).create(recursive: true);
    } else {
      _baseDir = 'trufit_meal_photos';
    }
  }

  Future<ScannedMealLog> saveScannedMeal({
    required String date,
    required String sourcePhotoPath,
    required String mealType,
    required String foodName,
    required int estimatedCalories,
    required double proteinGrams,
    required double carbsGrams,
    required double fatGrams,
    required double portionMultiplier,
  }) async {
    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final uuidStr = const Uuid().v4();
    final ext = sourcePhotoPath.contains('.')
        ? sourcePhotoPath.split('.').last
        : 'jpg';

    final relPath = '${date}_${timestampMs}_$uuidStr.$ext';
    final destPath = kIsWeb ? sourcePhotoPath : '$_baseDir/$relPath';

    File? copiedFile;
    if (!kIsWeb) {
      copiedFile = await File(sourcePhotoPath).copy(destPath);
    }

    final storedPath = kIsWeb ? destPath : relPath;

    final log = ScannedMealLog(
      id: 'photo_meal_${timestampMs}_$uuidStr',
      date: date,
      photoPath: storedPath,
      mealType: mealType,
      foodName: foodName,
      estimatedCalories: estimatedCalories,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      portionMultiplier: portionMultiplier,
      timestamp: DateTime.now().toIso8601String(),
    );

    try {
      await _isar.writeTxn(() async {
        await _isar.scannedMealLogs.put(log);
      });
    } catch (e) {
      if (copiedFile != null && await copiedFile.exists()) {
        try {
          await copiedFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
    return log;
  }

  String getAbsolutePath(String storedPath) {
    if (storedPath.contains('..')) {
      throw ArgumentError('Path traversal detected');
    }
    if (kIsWeb) return storedPath;
    if (storedPath.startsWith('/')) {
      // legacy absolute path
      if (storedPath.contains('trufit_meal_photos/')) {
        final rel = storedPath.split('trufit_meal_photos/').last;
        return '$_baseDir/$rel';
      }
      return storedPath;
    }
    return '$_baseDir/$storedPath';
  }

  List<ScannedMealLog> getScannedMealsForDate(String date) {
    return _isar.scannedMealLogs
        .filter()
        .dateEqualTo(date)
        .sortByTimestampDesc()
        .findAllSync();
  }

  int getTotalScannedCaloriesForDate(String date) {
    final meals = getScannedMealsForDate(date);
    return meals.fold(0, (sum, m) => sum + m.totalCalories);
  }

  Future<void> deleteScannedMeal(String id) async {
    final log = await _isar.scannedMealLogs.where().idEqualTo(id).findFirst();
    if (log != null) {
      await _isar.writeTxn(() async {
        await _isar.scannedMealLogs.delete(log.idInternal);
      });
      if (!kIsWeb) {
        final file = File(getAbsolutePath(log.photoPath));
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
    }
  }
}
