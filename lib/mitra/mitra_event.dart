enum MitraEventType {
  navigationIdle,
  userReturn,
  achievement,
  workoutCompleted,
  manualInteraction,
  notice
}

class MitraEvent {
  final MitraEventType type;
  final DateTime timestamp;
  
  MitraEvent(this.type) : timestamp = DateTime.now();
}
