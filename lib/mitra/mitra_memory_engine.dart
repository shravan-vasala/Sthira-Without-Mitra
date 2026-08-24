import 'mitra_event.dart';
import 'mitra_memory.dart';
import 'mitra_memory_context.dart';
import 'mitra_memory_event.dart';
import 'mitra_memory_snapshot.dart';

class MitraMemoryEngine {
  final MitraMemoryContext _context = MitraMemoryContext();
  int _eventCounter = 0;

  MitraMemoryContext get debugContext => _context; // For debug lab

  MitraMemorySnapshot recordEvent(MitraEvent event, {String? contextData, bool isMilestone = false}) {
    // 1. Clean expired memory
    _context.cleanExpiredMemory();

    // 2. Decide category
    final category = _determineCategory(event, isMilestone);

    // 3. Create memory event
    final memoryEvent = MitraMemoryEvent(
      id: 'mem_${DateTime.now().millisecondsSinceEpoch}_${++_eventCounter}',
      originalType: event.type,
      category: category,
      contextData: contextData ?? '',
    );

    // 4. Store event
    _context.addEvent(memoryEvent);

    // 5. Produce snapshot
    return createSnapshot();
  }

  MitraMemoryCategory _determineCategory(MitraEvent event, bool isMilestone) {
    if (isMilestone) return MitraMemoryCategory.milestone;

    switch (event.type) {
      case MitraEventType.notice:
      case MitraEventType.navigationIdle:
      case MitraEventType.manualInteraction:
        return MitraMemoryCategory.momentary;
      case MitraEventType.workoutCompleted:
      case MitraEventType.achievement:
        return MitraMemoryCategory.meaningful;
      case MitraEventType.userReturn:
        return MitraMemoryCategory.recent;
    }
  }

  MitraMemorySnapshot createSnapshot() {
    _context.cleanExpiredMemory();
    final now = DateTime.now();

    final hasRecentWorkout = _context.lastWorkoutTime != null && 
        now.difference(_context.lastWorkoutTime!).inHours < 48;
    
    final hasRecentMeaningfulEvent = _context.lastMeaningfulEventTime != null && 
        now.difference(_context.lastMeaningfulEventTime!).inDays < 7;
        
    final hasRecentUserReturn = _context.lastUserReturnTime != null && 
        now.difference(_context.lastUserReturnTime!).inHours < 24;

    Duration? timeSinceInteraction;
    if (_context.lastInteractionTime != null) {
      timeSinceInteraction = now.difference(_context.lastInteractionTime!);
    }

    Duration? timeSinceWorkout;
    if (_context.lastWorkoutTime != null) {
      timeSinceWorkout = now.difference(_context.lastWorkoutTime!);
    }

    Duration? timeSinceMeaningful;
    if (_context.lastMeaningfulEventTime != null) {
      timeSinceMeaningful = now.difference(_context.lastMeaningfulEventTime!);
    }

    int achievementCount = _context.recentEvents.where((e) => e.originalType == MitraEventType.achievement).length + 
                           _context.meaningfulEvents.where((e) => e.originalType == MitraEventType.achievement).length;
                           
    int interactionCount = _context.momentaryEvents.where((e) => e.originalType == MitraEventType.manualInteraction).length;

    MitraMemoryEvent? latestMeaningful;
    if (_context.meaningfulEvents.isNotEmpty) {
      latestMeaningful = _context.meaningfulEvents.last;
    }

    MitraMemoryEvent? latestMilestone;
    if (_context.milestoneEvents.isNotEmpty) {
      latestMilestone = _context.milestoneEvents.last;
    }

    return MitraMemorySnapshot(
      hasRecentWorkout: hasRecentWorkout,
      hasRecentMeaningfulEvent: hasRecentMeaningfulEvent,
      hasRecentUserReturn: hasRecentUserReturn,
      timeSinceLastInteraction: timeSinceInteraction,
      timeSinceLastWorkout: timeSinceWorkout,
      timeSinceLastMeaningfulEvent: timeSinceMeaningful,
      recentAchievementCount: achievementCount,
      recentInteractionCount: interactionCount,
      hasMilestone: _context.milestoneEvents.isNotEmpty,
      latestMeaningfulMemory: latestMeaningful,
      latestMilestone: latestMilestone,
    );
  }

  void resetMemory() {
    _context.reset();
  }
}
