import 'package:flutter/foundation.dart';

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
  /// Temporarily disabled. Firebase Cloud Sync is the primary backup.
  Future<String?> createBackup({String? password}) async {
    debugPrint(
      'BackupService: Local zip backups are disabled in this version (migrated to Isar). Use Cloud Sync.',
    );
    return null;
  }

  Future<BackupVerificationResult> verifyBackup(
    String zipPath, {
    String? password,
  }) async {
    return BackupVerificationResult(
      isValid: false,
      totalEntries: 0,
      photoCount: 0,
      errorMessage: 'Local zip backups are disabled.',
    );
  }

  Future<BackupRestoreResult> restoreBackup(
    String zipPath, {
    String? password,
  }) async {
    return BackupRestoreResult(success: false);
  }

  Future<void> autoBackup() async {
    // Isar databases can be safely copied using isar.copyToFile, but since
    // Firebase Cloud Sync is implemented, we can skip local auto-backup to zip.
    debugPrint('BackupService: autoBackup skipped.');
  }
}
