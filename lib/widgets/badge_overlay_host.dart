import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../providers/badge_engine_provider.dart';
import '../models/badge.dart';
import '../theme/app_colors.dart';

class BadgeOverlayHost extends ConsumerStatefulWidget {
  const BadgeOverlayHost({super.key});

  @override
  ConsumerState<BadgeOverlayHost> createState() => _BadgeOverlayHostState();
}

class _BadgeOverlayHostState extends ConsumerState<BadgeOverlayHost> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  Badge? _currentBadge;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _showBadge(Badge badge) {
    setState(() => _currentBadge = badge);
    _controller.forward(from: 0.0);
    
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) setState(() => _currentBadge = null);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Badge?>(badgeUnlockEventProvider, (prev, next) {
      if (next != null && (prev == null || prev.id != next.id)) {
        _showBadge(next);
      }
    });

    if (_currentBadge == null) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 16,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -100 * (1 - _slideAnimation.value)),
            child: Opacity(
              opacity: _slideAnimation.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.colors.lavenderCard,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _currentBadge!.iconEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Achievement Unlocked!',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentBadge!.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
