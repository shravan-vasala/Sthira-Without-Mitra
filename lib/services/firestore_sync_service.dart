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
  String? get currentUid => _auth.uid;

  @override
  Stream<int> get pendingCountStream {
    final isar = Isar.instanceNames.isNotEmpty ? Isar.getInstance(Isar.instanceNames.first) : null;
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
  Future<void> pauseAndDrainSync() async {
    _isSyncPaused = true;
    while (_isFlushing) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

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

  @override
  void queueSyncInTxn(Isar isar, String collection, String docId, Map<String, dynamic> data) {
    if (!canSync) return;
    final uid = _auth.uid;
    if (uid == null) return;
    
    final item = SyncQueueItem(
      collection: collection,
      docId: docId,
      payload: jsonEncode(data),
      timestamp: DateTime.now(),
      uid: uid,
    );
    isar.syncQueueItems.put(item); // inside an active transaction
  }

  @override
  void queueDeleteInTxn(Isar isar, String collection, String docId) {
    if (!canSync) return;
    final uid = _auth.uid;
    if (uid == null) return;
    
    final item = SyncQueueItem(
      collection: '_delete_/$collection',
      docId: docId,
      payload: '{}',
      timestamp: DateTime.now(),
      uid: uid,
    );
    isar.syncQueueItems.put(item);
  }

  @override
  void queueProfileInTxn(Isar isar, Map<String, dynamic> data) {
    if (!canSync) return;
    final uid = _auth.uid;
    if (uid == null) return;

    final item = SyncQueueItem(
      collection: '_profile_',
      docId: uid,
      payload: jsonEncode(data),
      timestamp: DateTime.now(),
      uid: uid,
    );
    isar.syncQueueItems.put(item);
  }

  @override
  void triggerFlush() {
    if (_debouncers.containsKey('flush')) {
      _debouncers['flush']?.cancel();
    }
    _debouncers['flush'] = Timer(const Duration(seconds: 3), () {
      flushQueue();
      _debouncers.remove('flush');
    });
  }

  @override
  void syncToCloud(String collection, String docId, Map<String, dynamic> data) {
    final isar = Isar.instanceNames.isNotEmpty ? Isar.getInstance(Isar.instanceNames.first) : null;
    if (isar != null && _auth.uid != null) {
      isar.writeTxnSync(() {
        queueSyncInTxn(isar, collection, docId, data);
      });
      triggerFlush();
    }
  }

  @override
  void deleteFromCloud(String collection, String docId) {
    final isar = Isar.instanceNames.isNotEmpty ? Isar.getInstance(Isar.instanceNames.first) : null;
    if (isar != null && _auth.uid != null) {
      isar.writeTxnSync(() {
        queueDeleteInTxn(isar, collection, docId);
      });
      flushNow();
    }
  }

  @override
  void syncProfile(Map<String, dynamic> data) {
    final isar = Isar.instanceNames.isNotEmpty ? Isar.getInstance(Isar.instanceNames.first) : null;
    if (isar != null && _auth.uid != null) {
      isar.writeTxnSync(() {
        queueProfileInTxn(isar, data);
      });
      triggerFlush();
    }
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

  bool _isFlushing = false;

  Future<void> flushQueue() async {
    if (!canSync || _isSyncPaused || _isFlushing) return;
    _isFlushing = true;
    try {
      while (true) {
        final isar = Isar.instanceNames.isNotEmpty ? Isar.getInstance(Isar.instanceNames.first) : null;
        if (isar == null) break;

        final currentUserUid = _auth.uid;
        if (currentUserUid == null) break;

        final items = isar.syncQueueItems.where().sortByTimestamp().findAllSync()
            .where((item) => item.uid == currentUserUid).toList();
        
        if (items.isEmpty) break;

        // Fold identity by canonical target, tracking all superseded item IDs
        final Map<String, SyncQueueItem> deduped = {};
        final Map<String, List<Id>> supersededIdsMap = {};
        
        for (final item in items) {
          final collectionSegment = item.collection.startsWith('_delete_/') 
              ? item.collection.substring(9) 
              : item.collection;
          final key = '${item.uid}/$collectionSegment/${item.docId}';
          deduped[key] = item;
          supersededIdsMap.putIfAbsent(key, () => []).add(item.id);
        }

        final successfulIds = <Id>[]; // These are the exact IDs representing the canonical ops
        final supersededIdsToDelete = <Id>[];
        final ops = deduped.values.toList();
        
        // Bounded batch limits (Firestore allows 500)
        for (int i = 0; i < ops.length; i += 450) {
          final batch = _db.batch();
          final chunk = ops.skip(i).take(450);
          final chunkIds = <Id>[];
          final chunkSupersededIds = <Id>[];

          for (final item in chunk) {
            final isDelete = item.collection.startsWith('_delete_/');
            final actualCollection = isDelete ? item.collection.substring(9) : item.collection;
            final key = '${item.uid}/$actualCollection/${item.docId}';
            final allIdsForKey = supersededIdsMap[key] ?? [];
            
            if (isDelete) {
              final ref = _subcollection(actualCollection);
              if (ref != null) {
                batch.delete(ref.doc(item.docId));
                chunkIds.add(item.id);
                chunkSupersededIds.addAll(allIdsForKey);
              }
            } else if (actualCollection == '_profile_') {
              final doc = _userDoc;
              if (doc != null) {
                try {
                  final data = jsonDecode(item.payload) as Map<String, dynamic>;
                  batch.set(doc, {'profile': data, 'lastSyncedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                  chunkIds.add(item.id);
                  chunkSupersededIds.addAll(allIdsForKey);
                } catch (_) {
                  debugPrint('FirestoreSync: Quarantined malformed profile payload ID ${item.id}');
                }
              }
            } else {
              final ref = _subcollection(actualCollection);
              if (ref != null) {
                try {
                  final data = jsonDecode(item.payload) as Map<String, dynamic>;
                  batch.set(ref.doc(item.docId), data, SetOptions(merge: true));
                  chunkIds.add(item.id);
                  chunkSupersededIds.addAll(allIdsForKey);
                } catch (_) {
                  debugPrint('FirestoreSync: Quarantined malformed payload ID ${item.id} in collection ${item.collection}');
                }
              }
            }
          }

          // Final async bounds check before pushing to network
          if (_auth.uid != currentUserUid) return;

          bool success = false;
          try {
            await batch.commit();
            success = true;
          } catch (e) {
            debugPrint('FirestoreSync: Batch commit failed: $e');
          }

          if (success) {
            successfulIds.addAll(chunkIds);
            supersededIdsToDelete.addAll(chunkSupersededIds);
          }
        }

        if (supersededIdsToDelete.isNotEmpty) {
          await isar.writeTxn(() async {
            await isar.syncQueueItems.deleteAll(supersededIdsToDelete); // Clears canonical AND older intents
          });
        }
      }
    } catch (e) {
      debugPrint('FirestoreSync: Error flushing queue: $e');
    } finally {
      _isFlushing = false;
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
