import 'package:isar/isar.dart';
import '../models/app_config.dart';

class SchemaMigrationService {
  static const int currentSchemaVersion = 4; // Bumping for Isar
  static const String _versionKey = 'schema_version';

  /// Run migrations for the active data on application startup.
  static Future<void> runStartupMigrations(Isar isar) async {
    final config = isar.appConfigs
        .where()
        .keyEqualTo(_versionKey)
        .findFirstSync();
    final int storedVersion = config != null
        ? int.tryParse(config.value) ?? 1
        : 1;

    if (storedVersion >= currentSchemaVersion) {
      return; // Already up to date
    }

    // Since we've fully migrated to Isar + Firebase Sync as the source of truth,
    // we bypass legacy local Hive migrations. Data is pulled from Firestore on sign-in.

    await isar.writeTxn(() async {

      await isar.appConfigs.put(
        AppConfig(key: _versionKey, value: currentSchemaVersion.toString()),
      );
    });

    // AiCache pruning has been extracted explicitly to AiCache.prune() running independently
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
