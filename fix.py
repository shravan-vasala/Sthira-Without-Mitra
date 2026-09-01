import re

# Fix social_feed_screen.dart
path = 'lib/screens/social/social_feed_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('context.colors.success', 'context.colors.green')
content = content.replace('context.colors.error', 'context.colors.red')

# Fix EmptyStateView
empty_state_old_1 = '''EmptyStateView(
                  icon: Icons.people_outline,
                  title: 'No friends connected yet.',
                  message: 'Connect with friends to share your progress.',
                  buttonText: 'Add Friends',
                  onButtonPressed: () => context.go('/social/connect'),
                )'''

empty_state_new_1 = '''Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    EmptyStateView(
                      icon: Icons.people_outline,
                      title: 'No friends connected yet.',
                      subtitle: 'Connect with friends to share your progress.',
                    ),
                    ElevatedButton(
                      onPressed: () => context.go('/social/connect'),
                      child: const Text('Add Friends'),
                    ),
                  ],
                )'''

content = content.replace(empty_state_old_1, empty_state_new_1)

empty_state_old_2 = '''EmptyStateView(
        icon: Icons.leaderboard_outlined,
        title: 'Board is empty',
        message: 'Add friends to compete on the leaderboard!',
        buttonText: 'Add Friends',
        onButtonPressed: () => context.go('/social/connect'),
      )'''

empty_state_new_2 = '''Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EmptyStateView(
            icon: Icons.leaderboard_outlined,
            title: 'Board is empty',
            subtitle: 'Add friends to compete on the leaderboard!',
          ),
          ElevatedButton(
            onPressed: () => context.go('/social/connect'),
            child: const Text('Add Friends'),
          ),
        ],
      )'''

content = content.replace(empty_state_old_2, empty_state_new_2)

content = content.replace('getOrCreateLog(', 'getOrCreate(')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

# Fix friend_status_card.dart
path_card = 'lib/screens/social/widgets/friend_status_card.dart'
with open(path_card, 'r', encoding='utf-8') as f:
    content_card = f.read()

content_card = content_card.replace('context.colors.error', 'context.colors.red')
content_card = content_card.replace("import '../../../models/social_profile.dart';", "")

with open(path_card, 'w', encoding='utf-8') as f:
    f.write(content_card)

# Fix app_providers.dart
path_app = 'lib/providers/app_providers.dart'
with open(path_app, 'r', encoding='utf-8') as f:
    content_app = f.read()

content_app = content_app.replace('getOrCreateLog(', 'getOrCreate(')

with open(path_app, 'w', encoding='utf-8') as f:
    f.write(content_app)

print("Fixes applied successfully")
