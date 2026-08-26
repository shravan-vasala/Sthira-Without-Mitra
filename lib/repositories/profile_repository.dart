import 'package:isar/isar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_profile.dart';
import '../interfaces/i_cloud_sync_service.dart';

class ProfileRepository {
  late Isar _isar;
  final _secureStorage = const FlutterSecureStorage();
  ICloudSyncService? _sync;

  void attachSync(ICloudSyncService sync) => _sync = sync;

  Future<void> init(Isar isar) async {
    _isar = isar;
    if (_isar.userProfiles.where().countSync() == 0) {
      await saveProfile(UserProfile());
    }
  }

  Future<String?> getSecureGeminiKey() async {
    return await _secureStorage.read(key: 'gemini_api_key');
  }

  Future<void> saveSecureGeminiKey(String key) async {
    await _secureStorage.write(key: 'gemini_api_key', value: key);
  }

  UserProfile getProfile() {
    return _isar.userProfiles.where().findFirstSync() ?? UserProfile();
  }

  Stream<UserProfile?> watchProfile() {
    return _isar.userProfiles.where().watch(fireImmediately: true).map((profiles) {
      return profiles.isNotEmpty ? profiles.first : null;
    });
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _isar.writeTxn(() async {
      await _isar.userProfiles.put(profile);
    });
    _sync?.syncProfile(profile.toJson());
  }

  Future<void> updateName(String name) async {
    final profile = getProfile();
    await saveProfile(profile.copyWith(name: name));
  }

  Future<void> updateHeight(double height) async {
    final profile = getProfile();
    await saveProfile(profile.copyWith(height: height));
  }

  Future<void> updateTargetWeight(double weight) async {
    final profile = getProfile();
    await saveProfile(profile.copyWith(targetWeight: weight));
  }

  Future<void> toggleUnit() async {
    final profile = getProfile();
    await saveProfile(profile.copyWith(useKg: !profile.useKg));
  }

  // ── Cloud sync helpers ──

  Future<void> importProfileFromCloud(Map<String, dynamic>? cloudData) async {
    if (cloudData != null) {
      final profile = UserProfile.fromJson(cloudData);
      // We must preserve the existing Isar id if it exists, or clear it to let Isar assign one
      final existing = getProfile();
      profile.id = existing.id;
      await saveProfile(profile);
    }
  }

  Map<String, dynamic> exportProfileForCloud() {
    return getProfile().toJson();
  }
}

