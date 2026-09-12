import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../interfaces/i_auth_service.dart';
import '../interfaces/i_cloud_sync_service.dart';
import '../models/sync_queue_item.dart';

/// Handles all Firestore cloud sync operations.
///
/// Architecture:
///   - Hive remains the source-of-truth for reads (instant, offline).
///   - After every Hive write, repositories call [syncToCloud] which
///     fires a non-blocking Firestore write.
///   - On first sign-in, [migrateLocalToCloud] uploads all existing
///     Hive data to Firestore.
///   - On sign-in on a new device, [pullCollection] downloads cloud
///     data into Hive.
class FirestoreSyncService implements ICloudSyncService {
  final IAuthService _auth;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, Timer> _debouncers = {};
  bool _isSyncPaused = false;

  FirestoreSyncService(this._auth) {
    flushQueue();
    Connectivity().onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.none)) return;
      flushQueue();
    });
  }

  /// Whether syncing is available (user signed in).
  @override
  bool get canSync => _auth.isSignedIn;

  @override
  Stream<int> get pendingCountStream {
    final isar = Isar.getInstance();
    if (isar == null) return Stream.value(0);
    return isar.syncQueueItems
        .watchLazy(fireImmediately: true)
        .map((_) => isar.syncQueueItems.countSync());
  }

  @override
  Future<void> flushNow() => flushQueue();

  @override
  void pauseSync() => _isSyncPaused = true;

  @override
  void resumeSync() {
    _isSyncPaused = false;
    flushQueue();
  }

  /// Reference to the current user's document.
  DocumentReference? get _userDoc {
    final uid = _auth.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  /// Reference to a sub-collection under the current user.
  CollectionReference? _subcollection(String name) {
    return _userDoc?.collection(name);
  }

  // ──────────────────────────────────────────────
  //  WRITE — fire-and-forget sync after Hive write
  // ──────────────────────────────────────────────

  /// Sync a single document to Firestore. Non-blocking.
  /// [collection] is the sub-collection name (e.g. 'daily_logs').
  /// [docId] is the document key (e.g. '2026-08-04').
  /// [data] is the JSON map to store.
  @override
  void syncToCloud(String collection, String docId, Map<String, dynamic> data) {
    if (!canSync) return;
    final uid = _auth.uid;
    if (uid == null) return;

    final isar = Isar.getInstance();
    if (isar != null) {
      isar.writeTxnSync(() {
        final item = SyncQueueItem(
          collection: collection,
          docId: docId,
          payload: jsonEncode(data),
          timestamp: DateTime.now(),
          uid: uid,
        );
        isar.syncQueueItems.putSync(item);
      });
    }

    if (_debouncers.containsKey('flush')) {
      _debouncers['flush']?.cancel();
    }
    _debouncers['flush'] = Timer(const Duration(seconds: 3), () {
      flushQueue();
      _debouncers.remove('flush');
    });
  }

  /// Delete a document from Firestore. Non-blocking.
  @override
  void deleteFromCloud(String collection, String docId) {
    if (!canSync) return;
    final uid = _auth.uid;
    if (uid == null) return;

    final isar = Isar.getInstance();
    if (isar != null) {
      isar.writeTxnSync(() {
        final item = SyncQueueItem(
          collection: '_delete_/$collection',
          docId: docId,
          payload: '{}',
          timestamp: DateTime.now(),
          uid: uid,
        );
        isar.syncQueueItems.putSync(item);
      });
    }

    flushNow();
  }

  /// Sync the user profile (stored as a single doc, not a sub-collection).
  @override
  void syncProfile(Map<String, dynamic> data) {
    if (!canSync) return;
    final uid = _auth.uid;
    if (uid == null) return;

    final isar = Isar.getInstance();
    if (isar != null) {
      isar.writeTxnSync(() {
        final item = SyncQueueItem(
          collection: '_profile_',
          docId: uid,
          payload: jsonEncode(data),
          timestamp: DateTime.now(),
          uid: uid,
        );
        isar.syncQueueItems.putSync(item);
      });
    }

    if (_debouncers.containsKey('flush')) {
      _debouncers['flush']?.cancel();
    }
    _debouncers['flush'] = Timer(const Duration(seconds: 3), () {
      flushQueue();
      _debouncers.remove('flush');
    });
  }

  @override
  Future<void> pushProfileNow(Map<String, dynamic> data) async {
    if (!canSync) return;
    final doc = _userDoc;
    if (doc == null) return;
    
    await doc.set({
      'profile': data,
      'lastSyncedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> flushQueue() async {
    if (!canSync || _isSyncPaused) return;
    final isar = Isar.getInstance();
    if (isar == null) return;

    final currentUserUid = _auth.uid;
    if (currentUserUid == null) return;

    // B01: Only process items for the CURRENT user!
    final items = isar.syncQueueItems.where().sortByTimestamp().findAllSync()
        .where((item) => item.uid == currentUserUid).toList();
    
    if (items.isEmpty) return;

    final Map<String, SyncQueueItem> deduped = {};

    for (final item in items) {
      final key = '${item.collection}/${item.docId}';
      deduped[key] = item;
    }

    if (deduped.isEmpty) {
      return;
    }

    final batch = _db.batch();
    for (final item in deduped.values) {
      if (item.collection.startsWith('_delete_/')) {
        final actualCollection = item.collection.split('/')[1];
        final ref = _subcollection(actualCollection);
        if (ref != null) {
          batch.delete(ref.doc(item.docId));
        }
      } else if (item.collection == '_profile_') {
        final doc = _userDoc;
        if (doc != null) {
          try {
            final data = jsonDecode(item.payload) as Map<String, dynamic>;
            batch.set(doc, {'profile': data, 'lastSyncedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
          } catch (_) {}
        }
      } else {
        final ref = _subcollection(item.collection);
        if (ref != null) {
          try {
            final data = jsonDecode(item.payload) as Map<String, dynamic>;
            batch.set(ref.doc(item.docId), data, SetOptions(merge: true));
          } catch (_) {}
        }
      }
    }

    try {
      await batch.commit();
      
      // Collect IDs of all successfully processed items for this user
      final itemsToDelete = items.map((e) => e.id).toList();

      await isar.writeTxn(() async {
        await isar.syncQueueItems.deleteAll(itemsToDelete);
      });
      debugPrint('FirestoreSync: Flushed ${deduped.length} items from queue.');
    } catch (e) {
      debugPrint('FirestoreSync: Error flushing queue: $e');
    }
  }

  // ──────────────────────────────────────────────
  //  READ — pull cloud data on sign-in
  // ──────────────────────────────────────────────

  /// Fetches an entire sub-collection and formats it as a Hive-ready map.
  @override
  Future<Map<String, Map<String, dynamic>>> pullCollection(
    String collection,
  ) async {
    if (!canSync) return {};

    final ref = _subcollection(collection);
    if (ref == null) return {};

    try {
      final snapshot = await ref.get();
      final result = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        result[doc.id] = doc.data() as Map<String, dynamic>;
      }
      debugPrint(
        'FirestoreSync: Pulled ${result.length} docs from $collection',
      );
      return result;
    } catch (e) {
      debugPrint('FirestoreSync: Error pulling $collection: $e');
      rethrow;
    }
  }

  @override
  Stream<Map<String, Map<String, dynamic>>> streamCollection(
    String collection,
  ) {
    if (!canSync) return const Stream.empty();
    final ref = _subcollection(collection);
    if (ref == null) return const Stream.empty();

    return ref.snapshots().map((snapshot) {
      final res = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        res[doc.id] = doc.data() as Map<String, dynamic>? ?? {};
      }
      return res;
    });
  }

  /// Pull all documents from a global Firestore collection (not user-specific).
  /// Used for pulling global workout/meal plans.
  @override
  Future<Map<String, Map<String, dynamic>>> pullGlobalCollection(
    String collection,
  ) async {
    try {
      final snapshot = await _db.collection(collection).get();
      final result = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        result[doc.id] = doc.data();
      }
      debugPrint(
        'FirestoreSync: Pulled ${result.length} docs from global $collection',
      );
      return result;
    } catch (e) {
      debugPrint('FirestoreSync: Error pulling global $collection: $e');
      rethrow;
    }
  }

  /// Fetches the user profile from the cloud.
  @override
  Future<Map<String, dynamic>?> pullProfile() async {
    if (!canSync) return null;

    final doc = _userDoc;
    if (doc == null) return null;

    try {
      final snapshot = await doc.get();
      if (!snapshot.exists) return null;
      final data = snapshot.data() as Map<String, dynamic>?;
      return data?['profile'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('FirestoreSync: Error pulling profile: $e');
      rethrow;
    }
  }

  /// Checks if the user has any data backed up in the cloud.
  @override
  Future<bool> hasCloudData() async {
    if (!canSync) return false;

    final doc = _userDoc;
    if (doc == null) return false;

    try {
      final snapshot = await doc.get();
      return snapshot.exists;
    } catch (e) {
      debugPrint('FirestoreSync: Error checking cloud data: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────
  //  BULK MIGRATION — local Hive → Firestore
  // ──────────────────────────────────────────────

  /// Upload a batch of documents to a Firestore sub-collection.
  /// Used during initial migration of local data to cloud.
  @override
  Future<void> bulkSync(
    String collection,
    Map<String, Map<String, dynamic>> docs,
  ) async {
    if (!canSync || docs.isEmpty) return;

    final ref = _subcollection(collection);
    if (ref == null) return;

    try {
      // Use batched writes for efficiency (max 500 per batch)
      final entries = docs.entries.toList();
      for (int i = 0; i < entries.length; i += 500) {
        final batch = _db.batch();
        final chunk = entries.skip(i).take(500);
        for (final entry in chunk) {
          batch.set(ref.doc(entry.key), entry.value, SetOptions(merge: true));
        }
        await batch.commit();
      }
      debugPrint(
        'FirestoreSync: Bulk synced ${docs.length} docs to $collection',
      );
    } catch (e) {
      debugPrint('FirestoreSync: Error bulk syncing $collection: $e');
      rethrow;
  }
}
}
