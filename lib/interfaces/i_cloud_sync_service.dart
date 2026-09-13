abstract class ICloudSyncService {
  bool get canSync;
  String? get currentUid;

  Stream<int> get pendingCountStream;
  Future<void> flushNow();

  void pauseSync();
  void resumeSync();

  void syncToCloud(String collection, String docId, Map<String, dynamic> data);

  void deleteFromCloud(String collection, String docId);

  void syncProfile(Map<String, dynamic> data);
  Future<void> pushProfileNow(Map<String, dynamic> data);

  Future<Map<String, Map<String, dynamic>>> pullCollection(String collection);

  Stream<Map<String, Map<String, dynamic>>> streamCollection(String collection);

  Future<Map<String, Map<String, dynamic>>> pullGlobalCollection(
    String collection,
  );

  Future<Map<String, dynamic>?> pullProfile();

  Future<bool> hasCloudData();

  Future<void> bulkSync(
    String collection,
    Map<String, Map<String, dynamic>> docs,
  );
}
