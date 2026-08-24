import 'dart:collection';
import 'mitra_memory_event.dart';
import 'mitra_memory.dart';

class MitraMemoryContext {
  DateTime? lastEventTime;
  DateTime? lastWorkoutTime;
  DateTime? lastMeaningfulEventTime;
  DateTime? lastUserReturnTime;
  DateTime? lastInteractionTime;

  final List<MitraMemoryEvent> _momentaryEvents = [];
  final List<MitraMemoryEvent> _recentEvents = [];
  final List<MitraMemoryEvent> _meaningfulEvents = [];
  final List<MitraMemoryEvent> _milestoneEvents = [];

  // Memory bounds
  static const int _maxMomentary = 10;
  static const int _maxRecent = 10;
  static const int _maxMeaningful = 20;
  static const int _maxMilestones = 20;

  UnmodifiableListView<MitraMemoryEvent> get momentaryEvents => UnmodifiableListView(_momentaryEvents);
  UnmodifiableListView<MitraMemoryEvent> get recentEvents => UnmodifiableListView(_recentEvents);
  UnmodifiableListView<MitraMemoryEvent> get meaningfulEvents => UnmodifiableListView(_meaningfulEvents);
  UnmodifiableListView<MitraMemoryEvent> get milestoneEvents => UnmodifiableListView(_milestoneEvents);

  void addEvent(MitraMemoryEvent event) {
    // Basic deduplication for immediate repeated events
    if (_isDuplicate(event)) {
      return;
    }

    _addToBoundedList(event, _getListForCategory(event.category), _getLimitForCategory(event.category));
    _updateTimestamps(event);
  }

  bool _isDuplicate(MitraMemoryEvent event) {
    final list = _getListForCategory(event.category);
    if (list.isEmpty) return false;
    final last = list.last;
    if (last.originalType == event.originalType && 
        DateTime.now().difference(last.timestamp).inSeconds < 2) {
      return true; // Simple debounce to prevent immediate spam
    }
    return false;
  }

  void cleanExpiredMemory() {
    final now = DateTime.now();
    // Momentary: expires after 10 minutes
    _momentaryEvents.removeWhere((e) => now.difference(e.timestamp).inMinutes > 10);
    // Recent: expires after 48 hours
    _recentEvents.removeWhere((e) => now.difference(e.timestamp).inHours > 48);
    // Meaningful: expires after 14 days
    _meaningfulEvents.removeWhere((e) => now.difference(e.timestamp).inDays > 14);
    // Milestones do not expire
  }

  void _addToBoundedList(MitraMemoryEvent event, List<MitraMemoryEvent> list, int limit) {
    list.add(event);
    if (list.length > limit) {
      list.removeAt(0); // Evict oldest
    }
  }

  List<MitraMemoryEvent> _getListForCategory(MitraMemoryCategory category) {
    switch (category) {
      case MitraMemoryCategory.momentary: return _momentaryEvents;
      case MitraMemoryCategory.recent: return _recentEvents;
      case MitraMemoryCategory.meaningful: return _meaningfulEvents;
      case MitraMemoryCategory.milestone: return _milestoneEvents;
    }
  }

  int _getLimitForCategory(MitraMemoryCategory category) {
    switch (category) {
      case MitraMemoryCategory.momentary: return _maxMomentary;
      case MitraMemoryCategory.recent: return _maxRecent;
      case MitraMemoryCategory.meaningful: return _maxMeaningful;
      case MitraMemoryCategory.milestone: return _maxMilestones;
    }
  }

  void _updateTimestamps(MitraMemoryEvent event) {
    lastEventTime = event.timestamp;
    
    // Update specific timestamps based on originalType (using simple heuristics as we can't depend on phase 7)
    final typeName = event.originalType.name;
    if (typeName.toLowerCase().contains('workout')) {
      lastWorkoutTime = event.timestamp;
    }
    if (typeName.toLowerCase().contains('return')) {
      lastUserReturnTime = event.timestamp;
    }
    if (typeName.toLowerCase().contains('interaction')) {
      lastInteractionTime = event.timestamp;
    }
    if (event.category == MitraMemoryCategory.meaningful || event.category == MitraMemoryCategory.milestone) {
      lastMeaningfulEventTime = event.timestamp;
    }
  }
  
  void reset() {
    lastEventTime = null;
    lastWorkoutTime = null;
    lastMeaningfulEventTime = null;
    lastUserReturnTime = null;
    lastInteractionTime = null;
    _momentaryEvents.clear();
    _recentEvents.clear();
    _meaningfulEvents.clear();
    _milestoneEvents.clear();
  }
}
