import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';
import '../models/daily_log.dart';
import '../models/habit.dart';
import '../models/meal_plan.dart';
import '../models/badge.dart';
import '../models/scanned_meal_log.dart';
import '../models/progress_photo.dart';
import '../models/exercise_log.dart';
import '../models/exercise_pr.dart';
import '../models/workout_plan.dart';
import '../models/workout_session.dart';
import '../models/coach_note.dart';
import '../models/body_stats.dart';
import '../models/daily_meal_log.dart';
import '../models/habit.dart';
import '../models/user_food_log.dart';
import 'schema_migration_service.dart';
import 'backup_encryption_service.dart';

class BackupRestoreResult {
  final bool success;
  final int failedPhotosCount;
  BackupRestoreResult({required this.success, this.failedPhotosCount = 0});
}

class BackupVerificationResult {
  final bool isValid;
  final int totalEntries;
  final int photoCount;
  final String? errorMessage;
  final bool isEncrypted;
  final int schemaVersion;
  final String appVersion;
  final String createdAt;

  BackupVerificationResult({
    required this.isValid,
    required this.totalEntries,
    required this.photoCount,
    this.errorMessage,
    this.isEncrypted = false,
    this.schemaVersion = 0,
    this.appVersion = 'Unknown',
    this.createdAt = 'Unknown',
  });
}

class BackupService {
  static const int _maxAutoBackups = 3;

  /// Creates a zipped backup in the application documents directory containing
  /// Isar JSON and the media directory. Returns the local path.
  Future<String?> createBackup({String? password, bool includeMedia = true}) async {
    if (kIsWeb) {
      debugPrint('BackupService: Web backup not supported yet.');
      return null;
    }

    try {
      final isar = Isar.getInstance();
      if (isar == null) throw Exception('Isar instance not found.');

      final appDir = await getApplicationDocumentsDirectory();
      final stagingName = 'backup_staging_${DateTime.now().millisecondsSinceEpoch}';
      final backupStagingDir = Directory('${appDir.path}/$stagingName');
      if (await backupStagingDir.exists()) {
        await backupStagingDir.delete(recursive: true);
      }
      await backupStagingDir.create(recursive: true);

      try {

      final dataFile = File('${backupStagingDir.path}/data.json');
      final manifestFile = File('${backupStagingDir.path}/manifest.json');

      final dataMap = <String, dynamic>{};
      
      // Dump collections we care about
      dataMap['userProfiles'] = isar.userProfiles.where().exportJsonSync();
      dataMap['dailyLogs'] = isar.dailyLogs.where().exportJsonSync();
      dataMap['habits'] = isar.habits.where().exportJsonSync();
      dataMap['mealPlans'] = isar.mealPlans.where().exportJsonSync();
      dataMap['badges'] = isar.badges.where().exportJsonSync();
      dataMap['scannedMealLogs'] = isar.scannedMealLogs.where().exportJsonSync();
      dataMap['progressPhotos'] = isar.progressPhotos.where().exportJsonSync();
      dataMap['exerciseLogs'] = isar.exerciseLogs.where().exportJsonSync();
      dataMap['exercisePrs'] = isar.exercisePrs.where().exportJsonSync();
      dataMap['workoutPlans'] = isar.workoutPlans.where().exportJsonSync();
      dataMap['workoutSessions'] = isar.workoutSessions.where().exportJsonSync();
      dataMap['coachNotes'] = isar.coachNotes.where().exportJsonSync();
      dataMap['bodyStats'] = isar.bodyStats.where().exportJsonSync();
      dataMap['dailyMealLogs'] = isar.dailyMealLogs.where().exportJsonSync();
      dataMap['habitCompletions'] = isar.habitCompletions.where().exportJsonSync();
      dataMap['userFoodLogs'] = isar.userFoodLogs.where().exportJsonSync();

      int recordCount = 0;
      for (final collection in dataMap.values) {
        if (collection is List) recordCount += collection.length;
      }

      await dataFile.writeAsString(jsonEncode(dataMap));

      final manifest = {
        'schemaVersion': SchemaMigrationService.currentSchemaVersion,
        'appVersion': 'Sthira V1', // Stub for now, can be read from package_info
        'createdAt': DateTime.now().toIso8601String(),
        'totalEntries': recordCount,
      };
      await manifestFile.writeAsString(jsonEncode(manifest));

      final encoder = ZipFileEncoder();
      final zipPath = '${backupStagingDir.path}/temp_backup.zip';
      encoder.create(zipPath);

      encoder.addFile(manifestFile);
      encoder.addFile(dataFile);

      if (includeMedia) {
        final mediaDirs = [
          'sthira_media',
          'trufit_media',
          'trufit_meal_photos',
          'trufit_profile_photos',
          'profile_photos',
        ];

        for (final dirName in mediaDirs) {
          final targetMedia = Directory('${appDir.path}/$dirName');
          if (await targetMedia.exists()) {
            encoder.addDirectory(targetMedia, includeDirName: true);
          }
        }
      }

      encoder.close();

      final finalZipPath = '${appDir.path}/sthira_backup_${DateTime.now().millisecondsSinceEpoch}.zip';

      if (password != null && password.isNotEmpty) {
        final zipFile = File(zipPath);
        final zipBytes = await zipFile.readAsBytes();
        final encryptedZip = BackupEncryptionService.encryptBytes(zipBytes, password);
        await File(finalZipPath).writeAsBytes(encryptedZip);
      } else {
        await File(zipPath).copy(finalZipPath);
      }

      return finalZipPath;
      } finally {
        if (await backupStagingDir.exists()) {
          await backupStagingDir.delete(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('Backup creation failed: $e');
      return null;
    }
  }

  Future<BackupVerificationResult> verifyBackup(String zipPath, {String? password}) async {
    try {
      final file = File(zipPath);
      if (!await file.exists()) {
        return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, errorMessage: 'File not found');
      }
      
      Uint8List bytes = file.readAsBytesSync();
      bool isEncrypted = false;
      
      // Check for magic bytes 'TFBK'
      if (bytes.length > 4 && bytes[0] == 84 && bytes[1] == 70 && bytes[2] == 66 && bytes[3] == 75) {
        isEncrypted = true;
        if (password == null || password.isEmpty) {
          return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, isEncrypted: true, errorMessage: 'Password required');
        }
        try {
          bytes = BackupEncryptionService.decryptBytes(bytes, password);
        } catch (e) {
          return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, isEncrypted: true, errorMessage: 'Incorrect password or corrupted file');
        }
      }

      final archive = ZipDecoder().decodeBytes(bytes);

      ArchiveFile? manifestFile;
      ArchiveFile? dataFile;
      int photoCount = 0;

      for (final archiveFile in archive) {
        if (archiveFile.name == 'manifest.json') {
          manifestFile = archiveFile;
        } else if (archiveFile.name == 'data.json') {
          dataFile = archiveFile;
        } else if (archiveFile.name.toLowerCase().endsWith('.jpg') || 
                   archiveFile.name.toLowerCase().endsWith('.jpeg') || 
                   archiveFile.name.toLowerCase().endsWith('.png') ||
                   archiveFile.name.toLowerCase().endsWith('.webp') ||
                   archiveFile.name.toLowerCase().endsWith('.gif')) {
          photoCount++;
        }
      }

      if (manifestFile == null) {
        return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, isEncrypted: isEncrypted, errorMessage: 'Invalid backup format (no manifest.json)');
      }
      if (dataFile == null) {
        return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, isEncrypted: isEncrypted, errorMessage: 'Invalid backup format (no data.json)');
      }

      final content = utf8.decode(manifestFile.content as List<int>);
      final map = jsonDecode(content) as Map<String, dynamic>;

      return BackupVerificationResult(
        isValid: true,
        totalEntries: map['totalEntries'] ?? 0,
        photoCount: photoCount,
        isEncrypted: isEncrypted,
        schemaVersion: map['schemaVersion'] ?? 1,
        appVersion: map['appVersion'] ?? 'Unknown',
        createdAt: map['createdAt'] ?? 'Unknown',
      );
    } catch (e) {
      return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, errorMessage: e.toString());
    }
  }

  Future<BackupRestoreResult> restoreBackup(String zipPath, {String? password}) async {
    if (kIsWeb) return BackupRestoreResult(success: false);
    
    try {
      final isar = Isar.getInstance();
      if (isar == null) throw Exception('Isar instance not found.');

      Uint8List bytes = File(zipPath).readAsBytesSync();
      
      // Check for magic bytes 'TFBK'
      if (bytes.length > 4 && bytes[0] == 84 && bytes[1] == 70 && bytes[2] == 66 && bytes[3] == 75) {
        if (password == null || password.isEmpty) {
          throw Exception('Password required to restore encrypted backup');
        }
        bytes = BackupEncryptionService.decryptBytes(bytes, password);
      }

      final archive = ZipDecoder().decodeBytes(bytes);
      
      ArchiveFile? dataFile;
      ArchiveFile? manifestFile;
      
      // Locate files
      for (final file in archive) {
        if (file.name == 'manifest.json') manifestFile = file;
        if (file.name == 'data.json') dataFile = file;
      }
      
      if (dataFile == null) {
        throw Exception('data.json missing from backup');
      }
      
      final dataContent = utf8.decode(dataFile.content as List<int>);
      final rawData = jsonDecode(dataContent) as Map<String, dynamic>;

      int manifestSchema = 1;
      if (manifestFile != null) {
         final manifestContent = utf8.decode(manifestFile.content as List<int>);
         final manifestData = jsonDecode(manifestContent) as Map<String, dynamic>;
         manifestSchema = manifestData['schemaVersion'] ?? 1;
      }

      final migratedData = SchemaMigrationService.runMigrationsForRestore(rawData, manifestSchema);

      await isar.writeTxn(() async {
        await isar.clear();
        
        if (migratedData['userProfiles'] != null) isar.userProfiles.importJsonSync(migratedData['userProfiles']);
        if (migratedData['dailyLogs'] != null) isar.dailyLogs.importJsonSync(migratedData['dailyLogs']);
        if (migratedData['habits'] != null) isar.habits.importJsonSync(migratedData['habits']);
        if (migratedData['mealPlans'] != null) isar.mealPlans.importJsonSync(migratedData['mealPlans']);
        if (migratedData['badges'] != null) isar.badges.importJsonSync(migratedData['badges']);
        if (migratedData['scannedMealLogs'] != null) isar.scannedMealLogs.importJsonSync(migratedData['scannedMealLogs']);
        if (migratedData['progressPhotos'] != null) isar.progressPhotos.importJsonSync(migratedData['progressPhotos']);
        if (migratedData['exerciseLogs'] != null) isar.exerciseLogs.importJsonSync(migratedData['exerciseLogs']);
        if (migratedData['exercisePrs'] != null) isar.exercisePrs.importJsonSync(migratedData['exercisePrs']);
        if (migratedData['workoutPlans'] != null) isar.workoutPlans.importJsonSync(migratedData['workoutPlans']);
        if (migratedData['workoutSessions'] != null) isar.workoutSessions.importJsonSync(migratedData['workoutSessions']);
        if (migratedData['coachNotes'] != null) isar.coachNotes.importJsonSync(migratedData['coachNotes']);
        if (migratedData['bodyStats'] != null) isar.bodyStats.importJsonSync(migratedData['bodyStats']);
        if (migratedData['dailyMealLogs'] != null) isar.dailyMealLogs.importJsonSync(migratedData['dailyMealLogs']);
        if (migratedData['habitCompletions'] != null) isar.habitCompletions.importJsonSync(migratedData['habitCompletions']);
        if (migratedData['userFoodLogs'] != null) isar.userFoodLogs.importJsonSync(migratedData['userFoodLogs']);
      });

      // Restore photos
      final appDir = await getApplicationDocumentsDirectory();
      int failedPhotos = 0;
      for (final file in archive) {
        final name = file.name.toLowerCase();
        if (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.webp') || name.endsWith('.gif')) {
          try {
             // Extract directly into the app documents structure to preserve paths
             final safePath = file.name.replaceAll('..', ''); 
             String targetPath = '${appDir.path}/$safePath';
             
             // Legacy fallback if the backup was created with includeDirName: false
             if (!safePath.startsWith('trufit_') && !safePath.startsWith('sthira_') && !safePath.startsWith('profile_')) {
               targetPath = '${appDir.path}/trufit_media/$safePath';
             }

             final extractedFile = File(targetPath);
             extractedFile.createSync(recursive: true);
             extractedFile.writeAsBytesSync(file.content as List<int>);
          } catch (_) {
             failedPhotos++;
          }
        }
      }

      return BackupRestoreResult(success: true, failedPhotosCount: failedPhotos);
    } catch (e) {
      debugPrint('Restore failed: $e');
      return BackupRestoreResult(success: false);
    }
  }

  Future<void> autoBackup() async {
    if (kIsWeb) return;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/auto_backups');
      if (!await backupDir.exists()) await backupDir.create(recursive: true);
      
      final zipPath = await createBackup(includeMedia: false);
      if (zipPath != null) {
         final zipFile = File(zipPath);
         final destFile = File('${backupDir.path}/auto_backup_${DateTime.now().millisecondsSinceEpoch}.zip');
         await zipFile.copy(destFile.path);
         await zipFile.delete();
      }

      // Cleanup to keep only recent max logs
      final files = backupDir.listSync().whereType<File>().where((f) => f.path.endsWith('.zip')).toList();
      if (files.length > _maxAutoBackups) {
         files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
         final toDelete = files.sublist(0, files.length - _maxAutoBackups);
         for (var f in toDelete) {
           await f.delete();
         }
      }
    } catch (e) {
      debugPrint('Auto backup failed: $e');
    }
  }
}
