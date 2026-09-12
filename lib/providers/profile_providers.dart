import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_providers.dart';
import '../models/user_profile.dart';
import '../models/body_stats.dart';

final latestBodyStatsProvider = Provider<BodyStats?>((ref) {
  return ref.watch(bodyStatsRepoProvider).getLatestStats();
});

// Keep this standard Provider as it acts as a dependency injection hook
final initialGeminiKeyProvider = Provider<String>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

class ProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    final repo = ref.watch(profileRepoProvider);
    final initialKey = ref.watch(initialGeminiKeyProvider);

    final sub = repo.watchProfile().listen((profile) {
      if (profile != null) {
        state = profile.copyWith(
          geminiApiKey:
              state.geminiApiKey ?? (initialKey.isNotEmpty ? initialKey : null),
        );
      }
    });

    ref.onDispose(() => sub.cancel());

    return repo.getProfile().copyWith(
      geminiApiKey: initialKey.isNotEmpty ? initialKey : null,
    );
  }

  Future<void> updateProfile(UserProfile profile) async {
    state = profile.copyWith(geminiApiKey: state.geminiApiKey);
    final repo = ref.read(profileRepoProvider);
    await repo.saveProfile(profile);
  }

  Future<void> updateGeminiKey(String key) async {
    try {
      final repo = ref.read(profileRepoProvider);
      await repo.saveSecureGeminiKey(key);
      state = state.copyWith(geminiApiKey: key, clearGeminiApiKey: key.isEmpty);
    } catch (e) {
      throw Exception('Failed to securely save API key.');
    }
  }

  Future<void> toggleUnit() async {
    state = state.copyWith(useKg: !state.useKg);
    final repo = ref.read(profileRepoProvider);
    await repo.toggleUnit();
    state = repo.getProfile();
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, UserProfile>(
  ProfileNotifier.new,
);
