import 'package:isar/isar.dart';
import '../models/friend.dart';

class FriendRepository {
  final Isar isar;

  FriendRepository(this.isar);

  List<Friend> getAllFriends() {
    return isar.friends.where().sortByAddedAtDesc().findAllSync();
  }

  Friend? getFriend(String uid) {
    return isar.friends.where().uidEqualTo(uid).findFirstSync();
  }

  Future<void> addFriend(String uid, String name, {String? avatarUrl}) async {
    final existing = getFriend(uid);
    if (existing != null) return;

    final friend = Friend()
      ..uid = uid
      ..name = name
      ..avatarUrl = avatarUrl
      ..addedAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.friends.put(friend);
    });
  }

  Future<void> removeFriend(String uid) async {
    final friend = getFriend(uid);
    if (friend != null) {
      await isar.writeTxn(() async {
        await isar.friends.delete(friend.id);
      });
    }
  }
}
