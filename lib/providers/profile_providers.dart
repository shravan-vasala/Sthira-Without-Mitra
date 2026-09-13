import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_providers.dart';
import '../models/user_profile.dart';
import '../models/body_stats.dart';

final latestBodyStatsProvider = Provider<BodyStats?>((ref) {
  return ref.watch(bodyStatsRepoProvider).getLatestStats();
});


class ProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    final repo = ref.watch(profileRepoProvider);

    final sub = repo.watchProfile().listen((profile) {
      if (profile != null) {
        state = profile;
      }
    });

    ref.onDispose(() => sub.cancel());

    return repo.getProfile();
  }

  Future<void> updateProfile(UserProfile profile) async {
    state = profile;
    final repo = ref.read(profileRepoProvider);
    await repo.saveProfile(profile);
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
