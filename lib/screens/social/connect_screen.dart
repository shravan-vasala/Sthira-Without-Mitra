import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/setup_sheets.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';
import '../../theme/layout_insets.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect with Friends'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My ID'),
            Tab(text: 'Enter ID'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_MyIdTab(), _EnterIdTab()],
      ),
    );
  }
}

class _MyIdTab extends ConsumerStatefulWidget {
  const _MyIdTab();

  @override
  ConsumerState<_MyIdTab> createState() => _MyIdTabState();
}

class _MyIdTabState extends ConsumerState<_MyIdTab> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final isAnonymous = authService.currentUser?.isAnonymous ?? true;
    final uid = authService.uid;

    if (isAnonymous || uid == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EmptyStateView(
              icon: Icons.person_off_rounded,
              title: 'Sign in Required',
              subtitle: 'You need an account to have a unique ID.',
            ),
            const SizedBox(height: Spacing.section),
            PrimaryButton(
              label: 'Sign In',
              onPressed: () {
                showAppBottomSheet(
                  context: context,
                  builder: (ctx) => const CloudSyncSheet(),
                );
              },
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'YOUR UNIQUE ID',
            style: context.text.eyebrow,
          ),
          const SizedBox(height: Spacing.stack),
          Semantics(
            button: true,
            label: 'Copy ID to clipboard',
            child: GestureDetector(
              onTap: () async {
                await HapticFeedback.lightImpact();
                try {
                  await Clipboard.setData(ClipboardData(text: uid));
                  if (!mounted) return;
                  setState(() => _copied = true);
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) setState(() => _copied = false);
                  });
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Failed to copy ID to clipboard.'),
                      backgroundColor: context.colors.red,
                    ),
                  );
                }
              },
              child:
                  Container(
                        margin: const EdgeInsets.symmetric(horizontal: Spacing.screen),
                        padding: const EdgeInsets.all(Spacing.cardPad),
                        decoration: BoxDecoration(
                          color: _copied
                              ? context.colors.primary.withValues(alpha: 0.1)
                              : context.colors.card,
                          borderRadius: BorderRadius.circular(Radii.card),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              uid,
                              textAlign: TextAlign.center,
                              style: context.text.cardTitle.copyWith(
                                color: _copied
                                    ? context.colors.primary
                                    : context.colors.textDark,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: Spacing.section),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _copied
                                      ? Icons.check_circle_rounded
                                      : Icons.copy_rounded,
                                  color: _copied
                                      ? context.colors.primary
                                      : context.colors.textMedium,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _copied
                                      ? 'Copied to Clipboard!'
                                      : 'Tap to Copy',
                                  style: context.text.caption.copyWith(
                                    color: _copied
                                        ? context.colors.primary
                                        : context.colors.textMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                      .animate(target: _copied ? 1 : 0)
                      .scaleXY(
                        end: 0.95,
                        duration: 150.ms,
                        curve: Curves.easeOut,
                      )
                      .then()
                      .scaleXY(
                        end: 1.0,
                        duration: 250.ms,
                        curve: Curves.easeOutBack,
                      )
                      .tint(
                        color: context.colors.primary.withValues(alpha: 0.1),
                        duration: 200.ms,
                      ),
            ),
          ),
          const SizedBox(height: Spacing.major),
          PrimaryButton(
            label: 'Share Invitation',
            icon: Icons.share_rounded,
            onPressed: () {
              Share.share('Connect with me on Sthira! My friend ID is: $uid');
            },
          ),
        ],
      ),
    );
  }
}

class _EnterIdTab extends ConsumerStatefulWidget {
  const _EnterIdTab();

  @override
  ConsumerState<_EnterIdTab> createState() => _EnterIdTabState();
}

class _EnterIdTabState extends ConsumerState<_EnterIdTab> {
  final TextEditingController _controller = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_isProcessing) return;

    final code = _controller.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    FocusScope.of(context).unfocus();

    try {
      final syncService = ref.read(socialSyncServiceProvider);
      final myUid = syncService.currentUid;
      final friendRepo = ref.read(friendRepoProvider);
      final profile = ref.read(profileProvider);

      if (!RegExp(r'^[A-Za-z0-9_-]{20,128}$').hasMatch(code)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'That code doesn\'t look quite right. Give it another try.',
              ),
              backgroundColor: context.colors.red,
            ),
          );
        }
        return;
      }

      if (code == myUid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That\'s your own code!')),
          );
        }
        return;
      }

      final existingFriend = friendRepo.getFriend(code);
      if (existingFriend != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are already friends with this person!'),
            ),
          );
        }
        return;
      }

      final String? safeAvatar =
          (profile.photoPath?.startsWith('assets/') ?? false)
          ? profile.photoPath
          : null;

      await syncService.sendFriendRequest(code, profile.name, safeAvatar);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Something went wrong. Let\'s try that again.'),
            backgroundColor: context.colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.screen,
        Spacing.screen,
        Spacing.screen,
        kShellScrollBottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ENTER FRIEND ID',
            style: context.text.eyebrow,
          ),
          const SizedBox(height: Spacing.stack),
          AppTextField(
            controller: _controller,
            labelText: 'User ID',
            hintText: 'Paste ID here...',
            prefixIcon: Icons.badge_rounded,
          ),
          const SizedBox(height: Spacing.major),
          PrimaryButton(
            label: _isProcessing ? 'Sending...' : 'Send Request',
            icon: Icons.send_rounded,
            isLoading: _isProcessing,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
