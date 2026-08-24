import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mitra/sunflower/integration/mitra_sunflower_interaction_tier.dart';
import '../mitra/integration/mitra_position_provider.dart';
import '../mitra/peacock/mitra_grand_display_controller.dart';
import '../mitra/peacock/mitra_grand_display_widget.dart';
import 'mitra_idle_engine.dart';

enum MitraState {
  idle,
  sunflowerNotice,
  sunflowerInteraction,
}

class MitraInteractionEngine extends ConsumerStatefulWidget {
  final double size;
  final bool showDebugBounds;

  const MitraInteractionEngine({
    super.key,
    required this.size,
    this.showDebugBounds = false,
  });

  @override
  ConsumerState<MitraInteractionEngine> createState() => MitraInteractionEngineState();
}

class MitraInteractionEngineState extends ConsumerState<MitraInteractionEngine> {
  final GlobalKey<MitraIdleEngineState> _idleEngineKey = GlobalKey<MitraIdleEngineState>();
  
  MitraState get currentMitraState => MitraState.idle;
  
  void reset() {}

  Future<void> playIdleAction(int actionId) async {
    await _idleEngineKey.currentState?.playAction(actionId);
  }

  Future<void> playNoticeSequence() async {
    await _idleEngineKey.currentState?.playAction(8); // Notice Sunflower
  }

  Future<void> playPeekSequence() async {
    await _idleEngineKey.currentState?.playAction(9); // Peek
  }

  Future<void> _wanderTo(double targetX) async {
    int maxSteps = 30; // Failsafe to prevent infinite looping
    int steps = 0;
    
    while (mounted && steps < maxSteps) {
      double currentX = ref.read(mitraGlobalXProvider);
      
      // If we are close enough (within 35 pixels), stop walking
      if ((currentX - targetX).abs() < 35.0) {
        break;
      }
      
      if (currentX < targetX) {
        await _idleEngineKey.currentState?.playAction(7); // Walk Right
      } else {
        await _idleEngineKey.currentState?.playAction(6); // Walk Left
      }
      steps++;
    }
  }

  Future<void> playSunflowerSequence({
    MitraSunflowerInteractionTier tier = MitraSunflowerInteractionTier.full,
    void Function(String)? onContextualEvent,
  }) async {
    if (tier == MitraSunflowerInteractionTier.microNotice) {
      await _idleEngineKey.currentState?.playAction(8); // Notice
      return;
    }
    
    // Phase 44: Spatial Awareness (Go to Sunflower)
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sunflowerX = screenWidth - 70.0 - 32.0; 
    
    // Walk to sunflower (stop slightly before it to avoid clipping)
    await _wanderTo(sunflowerX - 30.0);
    
    if (onContextualEvent != null) onContextualEvent('mitraArrived');
    await _idleEngineKey.currentState?.playAction(12); // Play with sunflower
    if (onContextualEvent != null) onContextualEvent('mitraDeparting');
    
    // After playing, walk back to a neutral spot on the left edge
    await _wanderTo(16.0);
  }

  final MitraGrandDisplayController _grandDisplayController = MitraGrandDisplayController();

  @override
  void initState() {
    super.initState();
    _grandDisplayController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _grandDisplayController.dispose();
    super.dispose();
  }

  Future<void> playProgressReactionSequence() async {
    await _idleEngineKey.currentState?.playAction(4); // Proud
  }

  Future<void> playMischiefSequence(int mischiefId) async {
    await _idleEngineKey.currentState?.playAction(13); // Mischief
  }

  // Triggered by Debug Mode or Milestones
  void playPeacockGrandDisplay() {
    _grandDisplayController.play();
  }

  @override
  Widget build(BuildContext context) {
    // ALWAYS render the Peacock Grand Display Engine for Phase 1 Testing.
    // The Elephant is now completely hidden.
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: MitraGrandDisplayWidget(
        controller: _grandDisplayController,
        showDebugOverlay: widget.showDebugBounds,
        scale: widget.size / 500.0, // Assuming 500 is the expected base size
      ),
    );
  }
}
