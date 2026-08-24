import 'mitra_sunflower_state.dart';
import 'mitra_sunflower_progress.dart';
import 'mitra_sunflower.dart';

class MitraSunflowerSnapshot {
  final MitraSunflowerState state;
  final MitraSunflowerProgress progress;
  final MitraSunflowerTimeOfDay timeOfDay;

  const MitraSunflowerSnapshot({
    required this.state,
    required this.progress,
    required this.timeOfDay,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MitraSunflowerSnapshot &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          progress == other.progress &&
          timeOfDay == other.timeOfDay;

  @override
  int get hashCode => state.hashCode ^ progress.hashCode ^ timeOfDay.hashCode;
}
