import 'dart:collection';
import 'mitra_relationship.dart';
import 'mitra_relationship_event.dart';

class MitraRelationshipContext {
  DateTime? firstInteractionTime;
  DateTime? lastInteractionTime;
  DateTime? lastMeaningfulInteractionTime;
  DateTime? lastReturnTime;

  int meaningfulInteractionCount = 0;
  int totalInteractionCount = 0;
  int completedWorkoutCount = 0;
  int milestoneCount = 0;
  int consecutivePositiveInteractions = 0;

  MitraRelationshipTone currentTone = MitraRelationshipTone.reserved;
  MitraRelationshipMilestone lastMilestone = MitraRelationshipMilestone.none;

  final List<MitraRelationshipEventType> _recentRelationshipEvents = [];
  static const int _maxRecentEvents = 10;

  UnmodifiableListView<MitraRelationshipEventType> get recentRelationshipEvents => 
      UnmodifiableListView(_recentRelationshipEvents);

  void addEvent(MitraRelationshipEvent event) {
    _recentRelationshipEvents.add(event.type);
    if (_recentRelationshipEvents.length > _maxRecentEvents) {
      _recentRelationshipEvents.removeAt(0);
    }

    final now = event.timestamp;
    
    if (firstInteractionTime == null) {
      firstInteractionTime = now;
    }
    
    lastInteractionTime = now;
    totalInteractionCount++;

    if (event.type == MitraRelationshipEventType.workoutCompleted) {
      completedWorkoutCount++;
      meaningfulInteractionCount++;
      lastMeaningfulInteractionTime = now;
      consecutivePositiveInteractions++;
    } else if (event.type == MitraRelationshipEventType.habitCompleted || 
               event.type == MitraRelationshipEventType.meaningfulProgress) {
      meaningfulInteractionCount++;
      lastMeaningfulInteractionTime = now;
      consecutivePositiveInteractions++;
    } else if (event.type == MitraRelationshipEventType.milestoneReached) {
      milestoneCount++;
      meaningfulInteractionCount++;
      lastMeaningfulInteractionTime = now;
      consecutivePositiveInteractions++;
    } else if (event.type == MitraRelationshipEventType.userReturned || 
               event.type == MitraRelationshipEventType.returnedAfterGap) {
      lastReturnTime = now;
      consecutivePositiveInteractions = 0; // Reset consecutive on return, but don't penalize otherwise
    }
  }

  void reset() {
    firstInteractionTime = null;
    lastInteractionTime = null;
    lastMeaningfulInteractionTime = null;
    lastReturnTime = null;
    meaningfulInteractionCount = 0;
    totalInteractionCount = 0;
    completedWorkoutCount = 0;
    milestoneCount = 0;
    consecutivePositiveInteractions = 0;
    currentTone = MitraRelationshipTone.reserved;
    lastMilestone = MitraRelationshipMilestone.none;
    _recentRelationshipEvents.clear();
  }
}
