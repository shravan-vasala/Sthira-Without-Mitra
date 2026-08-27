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

  Future<void> pushProfile(SocialProfile profile) async {
    if (!canSync) return;

    _debouncer?.cancel();
    _debouncer = Timer(const Duration(seconds: 3), () {
      _db.collection('social_profiles').doc(_auth.uid!).set(
        profile.toJson(),
        SetOptions(merge: true),
      ).catchError((e) {
        debugPrint('SocialSyncService: Error pushing profile: $e');
      });
    });
  }

  Stream<SocialProfile?> streamFriendProfile(String friendUid) {
    if (!canSync) return const Stream.empty();
    return _db.collection('social_profiles').doc(friendUid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return SocialProfile.fromJson(snap.data()!);
    });
  }
}
