import 'mitra_relationship.dart';

class MitraRelationshipEvent {
  final MitraRelationshipEventType type;
  final DateTime timestamp;
  final String? source;

  MitraRelationshipEvent({
    required this.type,
    DateTime? timestamp,
    this.source,
  }) : timestamp = timestamp ?? DateTime.now();
}
