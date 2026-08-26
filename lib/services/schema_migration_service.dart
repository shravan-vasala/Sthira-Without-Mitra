import 'package:shared_preferences/shared_preferences.dart';

class SchemaMigrationService {
  static const int currentSchemaVersion = 4; // Bumping for Isar
  static const String _versionKey = 'schema_version';

  /// Run migrations for the active data on application startup.
  static Future<void> runStartupMigrations(SharedPreferences prefs) async {
    final int storedVersion = prefs.getInt(_versionKey) ?? 1;

    if (storedVersion >= currentSchemaVersion) {
      return; // Already up to date
    }

    // Since we've fully migrated to Isar + Firebase Sync as the source of truth,
    // we bypass legacy local Hive migrations. Data is pulled from Firestore on sign-in.

    await prefs.setInt(_versionKey, currentSchemaVersion);
  }

  /// Run migrations for in-memory backup data before writing to storage during a restore.
  static Map<String, dynamic> runMigrationsForRestore(
    Map<String, dynamic> boxes,
    int manifestVersion,
  ) {
    // Restore logic relies on JSON parsing which repositories now handle directly.
    return boxes;
  }
}

