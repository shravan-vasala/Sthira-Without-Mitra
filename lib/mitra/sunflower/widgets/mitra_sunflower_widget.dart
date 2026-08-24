import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mitra_sunflower_state.dart';
import '../animation/mitra_sunflower_animation_controller.dart';
import '../integration/mitra_sunflower_integration_provider.dart';

class MitraSunflowerWidget extends ConsumerStatefulWidget {
  final MitraSunflowerAnimationController? debugController;
  final double size;

  const MitraSunflowerWidget({
    Key? key,
    this.debugController,
    this.size = 200,
  }) : super(key: key);

  @override
  ConsumerState<MitraSunflowerWidget> createState() => _MitraSunflowerWidgetState();
}

class _MitraSunflowerWidgetState extends ConsumerState<MitraSunflowerWidget> {
  late final MitraSunflowerAnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.debugController ?? MitraSunflowerAnimationController();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.debugController == null) {
      final state = ref.watch(canonicalSunflowerStateProvider);
      // Process the Phase 17 raw state to apply Phase 20 Daily Latch protection
      _controller.processPhase12Snapshot(state, DateTime.now());
    }

    final latchedState = _controller.debugDailyHighWaterMark ?? MitraSunflowerState.seed;
    final activeTransition = _controller.currentSnapshot.activeTransition;

    // Use a duration of 1500ms only if there is an active forward transition.
    // App restarts and genuine new-day resets will have activeTransition == null,
    // resulting in an instant (0ms) update.
    final duration = activeTransition != null 
        ? const Duration(milliseconds: 1500) 
        : Duration.zero;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeOut,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.0, 0.15), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: Image.asset(
          latchedState.canonicalAssetPath,
          // Using a ValueKey based on the canonical asset path ensures Flutter
          // correctly recognizes a genuine stage change. This prevents unrelated
          // rebuilds from restarting the animation.
          key: ValueKey<String>(latchedState.canonicalAssetPath),
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
        ),
      ),
    );
  }
}
