import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../providers/badge_engine_provider.dart';
import '../models/badge.dart';
import '../theme/app_colors.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';
import '../theme/app_motion.dart';


class BadgeOverlayHost extends ConsumerStatefulWidget {
  const BadgeOverlayHost({super.key});

  @override
  ConsumerState<BadgeOverlayHost> createState() => _BadgeOverlayHostState();
}

class _BadgeOverlayHostState extends ConsumerState<BadgeOverlayHost>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  Badge? _currentBadge;
  Timer? _hideTimer;
  bool _isShowing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Motion.deliberate,
      reverseDuration: const Motion.standard,
    );
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: Motion.enter,
      reverseCurve: Motion.exit,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _processQueue() {
    final queue = ref.read(badgeUnlockEventProvider);
    if (queue.isEmpty) return;

    setState(() {
      _isShowing = true;
      _currentBadge = queue.first;
    });

    HapticFeedback.heavyImpact();
    _controller.forward(from: 0.0);

    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), _dismissBadge);
  }

  void _dismissBadge() {
    _hideTimer?.cancel();
    if (!mounted) return;

    _controller.reverse().then((_) {
      if (!mounted) return;
      setState(() => _currentBadge = null);

      // Pop the queue
      ref.read(badgeUnlockEventProvider.notifier).dequeue();
      _isShowing = false;

      // Wait 400ms before showing the next one
      Future.delayed(const Motion.deliberate, () {
        if (mounted && ref.read(badgeUnlockEventProvider).isNotEmpty) {
          _processQueue();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<Badge>>(badgeUnlockEventProvider, (prev, next) {
      if (next.isNotEmpty && !_isShowing) {
        _processQueue();
      }
    });

    if (_currentBadge == null) return const SizedBox.shrink();

    final unlockedCount = ref
        .watch(badgesProvider)
        .where((b) => b.isUnlocked)
        .length;
    final totalCount = ref.watch(badgesProvider).length;

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 16,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -150 * (1 - _slideAnimation.value)),
            child: Opacity(
              opacity: _slideAnimation.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.delta.dy < -2) _dismissBadge();
          },
          onTap: () {
            _dismissBadge();
            context.go('/profile');
          },
          child: Semantics(
            label: "Achievement unlocked: ${_currentBadge!.title}",
            child: Material(
              type: MaterialType.transparency,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child:
                    BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.surface.withValues(
                                alpha: 0.85,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.gold.withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              colors: [
                                                context.colors.goldMuted,
                                                context.colors.gold,
                                              ],
                                              radius: 0.8,
                                            ),
                                            border: Border.all(
                                              color: context.colors.gold,
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: context.colors.gold
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            _currentBadge!.iconEmoji,
                                            style: context.text.screenTitle,
                                          ),
                                        )
                                        .animate(
                                          key: ValueKey(_currentBadge!.id),
                                        )
                                        .scale(
                                          begin: const Offset(0.4, 0.4),
                                          curve: Motion.enter,
                                          duration: Motion.deliberate,
                                        ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'ACHIEVEMENT UNLOCKED',
                                        style: context.text.micro.copyWith(
                                          color: context.colors.gold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _currentBadge!.title,
                                        style: context.text.cardTitle.copyWith(
                                          color: context.colors.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _currentBadge!.description,
                                        style: context.text.micro.copyWith(
                                          color: context.colors.textMedium,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$unlockedCount of $totalCount unlocked',
                                        style: context.text.micro.copyWith(
                                          color: context.colors.textLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .animate(
                          key: ValueKey('${_currentBadge!.id}_shimmer'),
                          onPlay: MediaQuery.disableAnimationsOf(context)
                              ? (c) => c.stop()
                              : null,
                        )
                        .shimmer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Motion.instant
                              : Motion.deliberate,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
