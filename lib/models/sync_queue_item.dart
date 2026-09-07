import 'package:isar/isar.dart';

part 'sync_queue_item.g.dart';

@collection
class SyncQueueItem {
  Id id = Isar.autoIncrement;

  @Index()
  final String collection;

  @Index()
  final String docId;

  final String payload;

  final DateTime timestamp;

  final String uid;

  SyncQueueItem({
    required this.collection,
    required this.docId,
    required this.payload,
    required this.timestamp,
    required this.uid,
  });
}
