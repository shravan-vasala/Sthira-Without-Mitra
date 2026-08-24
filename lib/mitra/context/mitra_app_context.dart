import 'mitra_context_types.dart';

class MitraAppContext {
  MitraAppScreen currentScreen = MitraAppScreen.unknown;
  MitraAppScreen previousScreen = MitraAppScreen.unknown;
  MitraUserActivity currentActivity = MitraUserActivity.idle;
  MitraAppLifecycle lifecycleState = MitraAppLifecycle.foreground;
  DateTime sessionStartTime = DateTime.now();
  DateTime lastUserInteractionTime = DateTime.now();
}
