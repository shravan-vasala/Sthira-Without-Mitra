import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../interfaces/i_auth_service.dart';
import '../models/social_profile.dart';

class SocialSyncService {
  final IAuthService _auth;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Timer? _debouncer;

  SocialSyncService(this._auth);

  bool get canSync => _auth.isSignedIn && _auth.uid != null;
  String? get currentUid => _auth.uid;

  Future<void> pushProfile(SocialProfile profile) async {
    if (!canSync) return;

    final capturedUid = _auth.uid;
    _debouncer?.cancel();
    _debouncer = Timer(const Duration(seconds: 3), () {
      if (!_auth.isSignedIn || _auth.uid != capturedUid) return;

      _db
          .collection('social_profiles')
          .doc(capturedUid)
          .set(profile.toJson(), SetOptions(merge: true))
          .catchError((e) {
            debugPrint('SocialSyncService: Error pushing profile: $e');
          });
    });
  }

  Stream<SocialProfile?> streamFriendProfile(String friendUid) {
    if (!canSync) return const Stream.empty();
    return _db.collection('social_profiles').doc(friendUid).snapshots().map((
      snap,
    ) {
      if (!snap.exists || snap.data() == null) return null;
      return SocialProfile.fromJson(snap.data()!);
    });
  }

  Future<SocialProfile?> fetchProfileOnce(String uid) async {
    if (!canSync) return null;
    try {
      final snap = await _db.collection('social_profiles').doc(uid).get();
      if (!snap.exists || snap.data() == null) return null;
      return SocialProfile.fromJson(snap.data()!);
    } catch (e) {
      debugPrint('SocialSyncService: Error fetching profile: $e');
      return null;
    }
  }

  Future<void> sendFriendRequest(
    String targetUid,
    String myName,
    String? myAvatar,
  ) async {
    if (!canSync) return;
    try {
      await _db
          .collection('friend_requests')
          .doc(targetUid)
          .collection('requests')
          .doc(currentUid)
          .set({
            'fromUid': currentUid,
            'fromName': myName,
            'fromAvatar': myAvatar,
            'sentAt': FieldValue.serverTimestamp(),
            'accepted': false,
          });
    } catch (e) {
      debugPrint('SocialSyncService: Error sending friend request: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> streamFriendRequests() {
    if (!canSync) return const Stream.empty();
    return _db
        .collection('friend_requests')
        .doc(currentUid)
        .collection('requests')
        .where('accepted', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['fromUid'] = doc.id; // Force doc id to prevent payload forgery
              return data;
            }).toList());
  }

  Future<List<Map<String, dynamic>>> getPendingAcceptances() async {
    if (!canSync) return [];
    try {
      final snap = await _db
          .collection('friend_requests')
          .doc(currentUid)
          .collection('requests')
          .where('accepted', isEqualTo: true)
          .get();
      return snap.docs.map((doc) {
        final data = doc.data();
        data['fromUid'] = doc.id; // Force doc id to prevent payload forgery
        return data;
      }).toList();
    } catch (e) {
      debugPrint('SocialSyncService: Error getting pending acceptances: $e');
      return [];
    }
  }

  Future<void> acceptFriendRequest(String requesterUid) async {
    if (!canSync) return;
    try {
      final batch = _db.batch();

      // Add requester to my allowedReaders
      final myProfileRef = _db.collection('social_profiles').doc(currentUid);
      batch.update(myProfileRef, {
        'allowedReaders': FieldValue.arrayUnion([requesterUid]),
      });

      // Update the request from my requests (DO NOT DELETE to satisfy transaction GET)
      final myRequestRef = _db
          .collection('friend_requests')
          .doc(currentUid)
          .collection('requests')
          .doc(requesterUid);
      batch.update(myRequestRef, {'accepted': true});

      // Write an acceptance marker for the requester
      final theirRequestRef = _db
          .collection('friend_requests')
          .doc(requesterUid)
          .collection('requests')
          .doc(currentUid);
      batch.set(theirRequestRef, {
        'fromUid': currentUid, 
        'accepted': true,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('SocialSyncService: Error accepting friend request: $e');
      rethrow;
    }
  }

  Future<void> declineFriendRequest(String requesterUid) async {
    if (!canSync) return;
    try {
      await _db
          .collection('friend_requests')
          .doc(currentUid)
          .collection('requests')
          .doc(requesterUid)
          .delete();
    } catch (e) {
      debugPrint('SocialSyncService: Error declining friend request: $e');
    }
  }

  Future<void> removeFriendAccess(String friendUid) async {
    if (!canSync) return;
    try {
      await _db.collection('social_profiles').doc(currentUid).update({
        'allowedReaders': FieldValue.arrayRemove([friendUid]),
      });
    } catch (e) {
      debugPrint('SocialSyncService: Error removing friend access: $e');
      rethrow;
    }
  }

  Future<void> clearAcceptanceMarker(String friendUid) async {
    if (!canSync) return;
    try {
      await _db
          .collection('friend_requests')
          .doc(currentUid)
          .collection('requests')
          .doc(friendUid)
          .delete();
    } catch (e) {
      debugPrint('SocialSyncService: Error clearing acceptance marker: $e');
    }
  }

  Future<void> processPendingAcceptance(String friendUid) async {
    if (!canSync) return;
    try {
      final batch = _db.batch();

      final myProfileRef = _db.collection('social_profiles').doc(currentUid);
      batch.update(myProfileRef, {
        'allowedReaders': FieldValue.arrayUnion([friendUid]),
      });

      final markerRef = _db
          .collection('friend_requests')
          .doc(currentUid)
          .collection('requests')
          .doc(friendUid);
      batch.delete(markerRef);

      await batch.commit();
    } catch (e) {
      debugPrint('SocialSyncService: Error processing pending acceptance: $e');
      rethrow;
    }
  }
}
