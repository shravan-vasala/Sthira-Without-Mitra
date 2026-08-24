import 'mitra_event.dart';
import 'mitra_memory.dart';

class MitraMemoryEvent {
  final String id;
  final MitraEventType originalType;
  final MitraMemoryCategory category;
  final DateTime timestamp;
  final String contextData;

  MitraMemoryEvent({
    required this.id,
    required this.originalType,
    required this.category,
    required this.contextData,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MitraMemoryEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
