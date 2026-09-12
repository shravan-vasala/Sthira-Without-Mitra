import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/empty_state_view.dart';

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
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Sign In',
              onPressed: () => context.push('/auth'),
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.colors.primary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Semantics(
            button: true,
            label: 'Copy ID to clipboard',
            child: GestureDetector(
              onTap: () async {
                 HapticFeedback.lightImpact();
                 try {
                   await Clipboard.setData(ClipboardData(text: uid));
                   if (!mounted) return;
                   setState(() => _copied = true);
                   Future.delayed(const Duration(seconds: 2), () {
                     if (mounted) setState(() => _copied = false);
                   });
                 } catch (e) {
                   if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(
                         content: const Text('Failed to copy ID to clipboard.'),
                         backgroundColor: context.colors.red,
                       ),
                     );
                   }
                 }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                   color: _copied ? context.colors.primary.withValues(alpha: 0.1) : context.colors.card,
                   borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Text(
                        uid,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                          color: _copied ? context.colors.primary : context.colors.textDark,
                        ),
                     ),
                     const SizedBox(height: 24),
                     Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Icon(
                            _copied ? Icons.check_circle_rounded : Icons.copy_rounded, 
                            color: _copied ? context.colors.primary : context.colors.textMedium, 
                            size: 18,
                         ),
                         const SizedBox(width: 8),
                         Text(
                           _copied ? 'Copied to Clipboard!' : 'Tap to Copy',
                           style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _copied ? context.colors.primary : context.colors.textMedium,
                           ),
                         ),
                       ],
                     ),
                  ],
                ),
              ).animate(target: _copied ? 1 : 0)
               .scaleXY(end: 0.95, duration: 150.ms, curve: Curves.easeOut)
               .then().scaleXY(end: 1.0, duration: 250.ms, curve: Curves.easeOutBack)
               .tint(color: context.colors.primary.withValues(alpha: 0.1), duration: 200.ms),
            ),
          ),
          const SizedBox(height: 32),
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
              content: const Text('That code doesn\'t look quite right. Give it another try.'),
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
          const SnackBar(
            content: Text(
              'Friend request sent successfully!',
            ),
          ),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            'ENTER FRIEND ID',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.colors.primary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
             controller: _controller,
             labelText: 'User ID',
             hintText: 'Paste ID here...',
             prefixIcon: Icons.badge_rounded,
          ),
          const SizedBox(height: 32),
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
