import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import '../models/sync_queue_item.dart';
import '../models/app_config.dart';
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
import '../interfaces/i_auth_service.dart';

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
  final IAuthService _auth;
  static const int _maxAutoBackups = 3;

  BackupService(this._auth);

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
        'uid': _auth.uid,
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
        
        final rootFiles = appDir.listSync().whereType<File>();
        for (final file in rootFiles) {
          final name = file.path.split(Platform.pathSeparator).last.toLowerCase();
          if (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.webp') || name.endsWith('.gif')) {
            encoder.addFile(file);
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
      
      final format = BackupEncryptionService.detectFormat(bytes);

      if (format == BackupFormat.unknownVersion) {
        return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, isEncrypted: true, errorMessage: 'Unsupported backup format version.');
      } else if (format == BackupFormat.v2) {
        isEncrypted = true;
        if (password == null || password.isEmpty) {
          return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, isEncrypted: true, errorMessage: 'Password required');
        }
        try {
          bytes = BackupEncryptionService.decryptV2(bytes, password);
        } catch (e) {
          return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, isEncrypted: true, errorMessage: 'Incorrect password or corrupted file');
        }
      } else if (format == BackupFormat.v1legacy) {
        isEncrypted = true;
        if (password == null || password.isEmpty) {
          return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, isEncrypted: true, errorMessage: 'Password required for legacy backup');
        }
        try {
          bytes = BackupEncryptionService.decryptV1(bytes, password);
          if (bytes.length < 4 || bytes[0] != 80 || bytes[1] != 75 || bytes[2] != 3 || bytes[3] != 4) {
             throw Exception('Header check failed');
          }
        } catch (e) {
          return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, isEncrypted: true, errorMessage: 'Incorrect legacy password or corrupted file');
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
      final map = jsonDecode(content);
      if (map is! Map<String, dynamic>) {
        return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, isEncrypted: isEncrypted, errorMessage: 'Invalid manifest format (not a JSON object)');
      }

      // Check data.json parses to Map<String, dynamic>
      try {
        final dataContent = utf8.decode(dataFile.content as List<int>);
        final dataMap = jsonDecode(dataContent);
        if (dataMap is! Map<String, dynamic>) {
          return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, isEncrypted: isEncrypted, errorMessage: 'Invalid data format (not a JSON object)');
        }
        if (dataMap.isEmpty) {
          return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, isEncrypted: isEncrypted, errorMessage: 'Invalid data format (empty object string)');
        }
      } catch (_) {
        return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, isEncrypted: isEncrypted, errorMessage: 'Corrupted data.json file');
      }

      final uid = map['uid'] as String?;
      String? warningMsg;
      if (uid != null && _auth.uid != null && uid != _auth.uid) {
        warningMsg = 'Account mismatch: This backup belongs to another user.';
      }

      return BackupVerificationResult(
        isValid: true,
        totalEntries: map['totalEntries'] as int? ?? 0,
        photoCount: photoCount,
        isEncrypted: isEncrypted,
        schemaVersion: map['schemaVersion'] as int? ?? 1,
        appVersion: map['appVersion'] as String? ?? 'Unknown',
        createdAt: map['createdAt'] as String? ?? 'Unknown',
        errorMessage: warningMsg,
      );
    } catch (e) {
      return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, errorMessage: e.toString());
    }
  }

  Future<BackupRestoreResult> restoreBackup(String zipPath, {String? password}) async {
    if (kIsWeb) return BackupRestoreResult(success: false);
    
    final appDir = await getApplicationDocumentsDirectory();
    final stagingDir = Directory('${appDir.path}/restore_staging_${DateTime.now().millisecondsSinceEpoch}');
    
    try {
      await stagingDir.create();
      final isar = Isar.getInstance();
      if (isar == null) throw Exception('Isar instance not found.');

      Uint8List bytes = File(zipPath).readAsBytesSync();
      
      final format = BackupEncryptionService.detectFormat(bytes);

      if (format == BackupFormat.unknownVersion) {
        throw Exception('Unsupported backup format version.');
      } else if (format == BackupFormat.v2) {
        if (password == null || password.isEmpty) {
          throw Exception('Password required to restore encrypted backup');
        }
        bytes = BackupEncryptionService.decryptV2(bytes, password);
      } else if (format == BackupFormat.v1legacy) {
        if (password == null || password.isEmpty) {
          throw Exception('Password required to restore legacy backup');
        }
        try {
          bytes = BackupEncryptionService.decryptV1(bytes, password);
          if (bytes.length < 4 || bytes[0] != 80 || bytes[1] != 75 || bytes[2] != 3 || bytes[3] != 4) {
             throw Exception('Invalid zip structure');
          }
        } catch(e) {
          throw Exception('Incorrect legacy password or corrupted file');
        }
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

      // 1. Extract photos to staging
      final stagedPhotos = <String, String>{};
      for (final file in archive) {
        final name = file.name.toLowerCase();
        if (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.webp') || name.endsWith('.gif')) {
           final normalized = file.name.replaceAll('\\', '/');
           final segments = normalized.split('/').where((s) => s.isNotEmpty && s != '.').toList();
           if (segments.contains('..')) {
             continue; // reject path traversal
           }
           final safePath = segments.join('/');
           String targetPath = '${appDir.path}/$safePath';
           
           // Legacy fallback
           if (!safePath.startsWith('trufit_') && !safePath.startsWith('sthira_') && !safePath.startsWith('profile_') && !safePath.contains('/')) {
             targetPath = '${appDir.path}/trufit_media/$safePath';
           }

           final stagingFileName = '${DateTime.now().microsecondsSinceEpoch}_$safePath'.replaceAll('/', '_').replaceAll('\\', '_');
           final stagingPath = '${stagingDir.path}/$stagingFileName';
           
           final extractedFile = File(stagingPath);
           extractedFile.writeAsBytesSync(file.content as List<int>);
           stagedPhotos[targetPath] = stagingPath;
        }
      }

      // 2. Database transaction
      await isar.writeTxn(() async {
        // Protect queue and configuration from being wiped
        final savedQueue = isar.syncQueueItems.where().exportJsonSync();
        final savedConfig = isar.appConfigs.where().exportJsonSync();

        await isar.clear();
        
        isar.syncQueueItems.importJsonSync(savedQueue);
        isar.appConfigs.importJsonSync(savedConfig);

        
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

      // 3. Move photos from staging to target
      int failedPhotos = 0;
      for (final entry in stagedPhotos.entries) {
        try {
           final targetFile = File(entry.key);
           targetFile.parent.createSync(recursive: true);
           File(entry.value).copySync(targetFile.path);
        } catch (_) {
           failedPhotos++;
        }
      }

      return BackupRestoreResult(success: true, failedPhotosCount: failedPhotos);
    } catch (e) {
      debugPrint('Restore failed: $e');
      return BackupRestoreResult(success: false);
    } finally {
      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }
    }
  }

  Future<void> autoBackup() async {
    if (kIsWeb) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastAutoDateStr = prefs.getString('last_auto_backup_date');
      if (lastAutoDateStr != null) {
        final lastDate = DateTime.tryParse(lastAutoDateStr);
        if (lastDate != null && DateTime.now().difference(lastDate).inDays < 7) {
           return; // wait for 7 days
        }
      }

      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/auto_backups');
      if (!await backupDir.exists()) await backupDir.create(recursive: true);
      
      final zipPath = await createBackup(includeMedia: false);
      if (zipPath != null) {
         final zipFile = File(zipPath);
         final destFile = File('${backupDir.path}/auto_backup_${DateTime.now().millisecondsSinceEpoch}.zip');
         await zipFile.copy(destFile.path);
         await zipFile.delete();
         
         await prefs.setString('last_auto_backup_date', DateTime.now().toIso8601String());
         await prefs.setString('last_auto_backup_display', DateFormat('MMM dd, yyyy').format(DateTime.now()));
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
