import 'package:flutter/material.dart';
import 'dart:async';
import '../../mitra/integration/mitra_debug_providers.dart';
import '../../mitra/mitra_behaviour.dart';
import '../../mitra/mitra_behaviour_engine.dart';
import '../../mitra/mitra_event.dart';
import '../../widgets/mitra_interaction_engine.dart';
import '../../widgets/mitra_idle_engine.dart';
import '../../mitra/mitra_personality_engine.dart';
import '../../mitra/mitra_personality_decision.dart';
import '../../mitra/mitra_memory_engine.dart';
import '../../mitra/mitra_memory_snapshot.dart';
import '../../mitra/integration/mitra_debug_providers.dart';
import '../../mitra/mitra_relationship.dart';
import '../../mitra/mitra_relationship_engine.dart';
import '../../mitra/mitra_relationship_event.dart';
import '../../mitra/mitra_relationship_decision.dart';
import '../../mitra/context/mitra_context_engine.dart';
import '../../mitra/context/mitra_context_types.dart';
import '../../mitra/attention/mitra_attention.dart';
import '../../mitra/attention/mitra_opportunity.dart';
import '../../mitra/attention/mitra_opportunity_decision.dart';
import '../../mitra/attention/mitra_attention_engine.dart';
import '../../mitra/sunflower/mitra_sunflower.dart';
import '../../mitra/sunflower/mitra_sunflower_engine.dart';
import '../../mitra/sunflower/mitra_sunflower_state.dart';
import '../../mitra/sunflower/animation/mitra_sunflower_animation.dart';
import '../../mitra/sunflower/integration/mitra_sunflower_integration_provider.dart';
import '../../mitra/sunflower/integration/mitra_sunflower_interaction_tier.dart';
import '../../mitra/sunflower/integration/mitra_cinematic_integration_engine.dart';
import '../../mitra/sunflower/integration/mitra_daily_progress_snapshot.dart';
import '../../mitra/mitra_personality.dart';
import '../../mitra/sunflower/animation/mitra_sunflower_animation_transition.dart';
import '../../mitra/sunflower/animation/mitra_sunflower_animation_choreography.dart';
import '../../mitra/sunflower/mitra_sunflower_progress.dart';
import '../../mitra/sunflower/widgets/mitra_sunflower_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import '../../mitra/integration/mitra_companion_overlay.dart';

class MitraDebugScreen extends StatelessWidget {
  const MitraDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Exact Sthira background color
    const Color plumBackground = Color(0xFF2B1D2B);

    return Scaffold(
      backgroundColor: plumBackground,
      appBar: AppBar(
        title: const Text(
          'Mitra Lab: Canonical Foundation',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'MASTER ASSET VERIFICATION',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'assets/mitra/canonical/mitra_master.png',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 32),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const Text('MASTER', style: TextStyle(color: Colors.white70)),
                  const Text('IDEAL', style: TextStyle(color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 16),
              
              // Render grid
              Wrap(
                spacing: 24,
                runSpacing: 32,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  _buildComparisonTest('160px (Hero)', 160),
                  _buildComparisonTest('120px (Overlay)', 120),
                  _buildComparisonTest('100px (Default)', 100),
                  _buildComparisonTest('80px (Micro)', 80),
                ],
              ),
              const SizedBox(height: 48),

              const Text(
                'MITRA ALIVE (Idle Engine)',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildAliveTest('160px Preview', 160),
                  const SizedBox(width: 48),
                  _buildAliveTest('120px Preview', 120),
                ],
              ),
              const SizedBox(height: 64),

              const Text(
                'MITRA INTERACTION LAB (Phase 3)',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const _MitraInteractionLabSection(),
              
              const SizedBox(height: 64),

              const Text(
                'MITRA BEHAVIOUR LAB (Phase 6)',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const _MitraBehaviourLabSection(),

              const SizedBox(height: 64),

              const Text(
                'MITRA MEMORY LAB (Phase 8)',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const _MitraMemoryLabSection(),

              const SizedBox(height: 64),

              const Text(
                'MITRA RELATIONSHIP LAB (Phase 9)',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const _MitraRelationshipLabSection(),

              const SizedBox(height: 64),
              
              const Text(
                'MITRA APP ENVIRONMENT LAB (Phase 10)',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const _MitraAppEnvironmentLabSection(),

              const SizedBox(height: 64),
              
              const Text(
                'MITRA ATTENTION / OPPORTUNITY LAB (Phase 11)',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const _MitraAttentionLabSection(),

              const SizedBox(height: 64),
              
              const Text(
                'MITRA SUNFLOWER LIFE LAB (Phase 12)',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const _MitraSunflowerLabSection(),

              const SizedBox(height: 64),
              
              const Text(
                'MITRA SUNFLOWER ANIMATION LAB (Phase 13)',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const _MitraSunflowerAnimationLabSection(),

              const SizedBox(height: 64),
              
              const Text(
                'SUNFLOWER DAILY PROGRESS INTEGRATION LAB (Phase 14)',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const _MitraSunflowerIntegrationLabSection(),

              const SizedBox(height: 64),
              
              const Text(
                'MITRA CINEMATIC LAB (Phase 15)',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const _MitraCinematicLabSection(),

              const SizedBox(height: 64),
              
              const Text(
                'PHASE 24 — LIVING BEHAVIOUR',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const _MitraLivingBehaviourLabSection(),

              const SizedBox(height: 64),
              
              const Text(
                'PHASE 29 — NAVIGATION BAR DIORAMA PLAYGROUND',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const _MitraPhase29DioramaLabSection(),

              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAliveTest(String label, double size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: Colors.red.withOpacity(0.5),
                ),
              ),
              MitraIdleEngine(size: size),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonTest(String label, double size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAssetBox('assets/mitra/canonical/mitra_master.png', size),
            const SizedBox(width: 16),
            _buildAssetBox('assets/mitra/canonical/mitra_ideal.png', size),
          ],
        )
      ],
    );
  }

  Widget _buildAssetBox(String assetPath, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Baseline indicator
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              color: Colors.red.withOpacity(0.5),
            ),
          ),
          Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain, // Guarantee aspect ratio is maintained
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.broken_image, color: Colors.white, size: 32);
            },
          ),
        ],
      ),
    );
  }
}

class _MitraInteractionLabSection extends StatefulWidget {
  const _MitraInteractionLabSection();

  @override
  State<_MitraInteractionLabSection> createState() => _MitraInteractionLabSectionState();
}

class _MitraInteractionLabSectionState extends State<_MitraInteractionLabSection> {
  final GlobalKey<MitraInteractionEngineState> _engineKey = GlobalKey<MitraInteractionEngineState>();
  bool _showDebugBounds = false;

  String _formatState(MitraState? state) {
    if (state == null) return 'none';
    return state.toString().split('.').last.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left: The interactive engine
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24, width: 1),
            color: Colors.black26,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: Colors.red.withOpacity(0.5),
                ),
              ),
              // We assign the GlobalKey to communicate with the orchestrator
              MitraInteractionEngine(
                key: _engineKey,
                size: 160,
                showDebugBounds: _showDebugBounds,
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),

        // Right: Control Dashboard
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ORCHESTRATOR CONTROLS',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _showDebugBounds,
                  onChanged: (val) {
                    setState(() {
                      _showDebugBounds = val ?? false;
                    });
                  },
                  fillColor: WidgetStateProperty.all(Colors.blueGrey),
                ),
                const Text(
                  'SHOW DEBUG BOUNDS',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              direction: Axis.vertical,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _engineKey.currentState?.playPeekSequence();
                    // Just force a rebuild of this panel to show changing states eagerly
                    _simulateStateMonitoring();
                  },
                  icon: const Icon(Icons.remove_red_eye, size: 16),
                  label: const Text('PLAY PEEK'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _engineKey.currentState?.playSunflowerSequence();
                    _simulateStateMonitoring();
                  },
                  icon: const Icon(Icons.local_florist, size: 16),
                  label: const Text('FULL SUNFLOWER INTERACTION'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _engineKey.currentState?.reset();
                    setState(() {});
                  },
                  icon: const Icon(Icons.replay, size: 16),
                  label: const Text('RESET / IDLE'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.black45,
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT: ${_formatState(_engineKey.currentState?.currentMitraState)}',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        )
      ],
    );
  }

  // Poll state occasionally to update the dashboard diagnostic text during play
  void _simulateStateMonitoring() async {
    for (int i = 0; i < 20; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() {});
    }
  }
}

class _MitraBehaviourLabSection extends StatefulWidget {
  const _MitraBehaviourLabSection();

  @override
  State<_MitraBehaviourLabSection> createState() => _MitraBehaviourLabSectionState();
}

class _MitraBehaviourLabSectionState extends State<_MitraBehaviourLabSection> {
  final GlobalKey<MitraBehaviourEngineState> _engineKey = GlobalKey<MitraBehaviourEngineState>();
  final MitraPersonalityEngine _personalityEngine = MitraPersonalityEngine();
  MitraPersonalityDecision? _lastDecision;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.inMilliseconds <= 0) return 'READY';
    return '${d.inSeconds}s';
  }

  void _triggerEvent(MitraEventType type) {
    final event = MitraEvent(type);
    final decision = _personalityEngine.evaluate(event);
    setState(() {
      _lastDecision = decision;
    });
    if (decision.shouldReact) {
      _engineKey.currentState?.dispatch(event);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _engineKey.currentState;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left: The behaviour engine
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24, width: 1),
            color: Colors.black26,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: Colors.red.withOpacity(0.5),
                ),
              ),
              MitraBehaviourEngine(
                key: _engineKey,
                size: 160,
                showDebugBounds: false, // We leave it to the interaction lab above if needed
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),

        // Right: Control Dashboard
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SHOW BEHAVIOUR DEBUG',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              direction: Axis.vertical,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _triggerEvent(MitraEventType.manualInteraction),
                  icon: const Icon(Icons.local_florist, size: 16),
                  label: const Text('TRIGGER MANUAL INTERACTION'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
                ),
                ElevatedButton.icon(
                  onPressed: () => _triggerEvent(MitraEventType.achievement),
                  icon: const Icon(Icons.star, size: 16),
                  label: const Text('TRIGGER ACHIEVEMENT'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800),
                ),
                ElevatedButton.icon(
                  onPressed: () => _triggerEvent(MitraEventType.workoutCompleted),
                  icon: const Icon(Icons.fitness_center, size: 16),
                  label: const Text('TRIGGER WORKOUT COMPLETED'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800),
                ),
                ElevatedButton.icon(
                  onPressed: () => _triggerEvent(MitraEventType.navigationIdle),
                  icon: const Icon(Icons.touch_app, size: 16),
                  label: const Text('TRIGGER NAVIGATION IDLE'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade800),
                ),
                ElevatedButton.icon(
                  onPressed: () => _triggerEvent(MitraEventType.userReturn),
                  icon: const Icon(Icons.person, size: 16),
                  label: const Text('TRIGGER USER RETURN'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _engineKey.currentState?.resetEngine();
                    setState(() {
                      _lastDecision = null;
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('RESET BEHAVIOUR STATE'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'PHASE 27 — MITRA PLAYGROUND',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: () => _engineKey.currentState?.interactionKey.currentState?.playIdleAction(0),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pink.shade800),
                  child: const Text('DANCE'),
                ),
                ElevatedButton(
                  onPressed: () => _engineKey.currentState?.interactionKey.currentState?.playIdleAction(1),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pink.shade800),
                  child: const Text('SHUFFLE'),
                ),
                ElevatedButton(
                  onPressed: () => _engineKey.currentState?.interactionKey.currentState?.playIdleAction(2),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pink.shade800),
                  child: const Text('BOUNCE'),
                ),
                ElevatedButton(
                  onPressed: () => _engineKey.currentState?.interactionKey.currentState?.playIdleAction(3),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pink.shade800),
                  child: const Text('GOOFY LEAN'),
                ),
                ElevatedButton(
                  onPressed: () => _engineKey.currentState?.interactionKey.currentState?.playNoticeSequence(),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800),
                  child: const Text('NOTICE SUNFLOWER'),
                ),
                ElevatedButton(
                  onPressed: () => _engineKey.currentState?.interactionKey.currentState?.playIdleAction(4),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800),
                  child: const Text('PROUD MOMENT'),
                ),
                ElevatedButton(
                  onPressed: () => _engineKey.currentState?.interactionKey.currentState?.playIdleAction(5),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
                  child: const Text('BLOOM CELEBRATION'),
                ),
                ElevatedButton(
                  onPressed: () => _triggerEvent(MitraEventType.navigationIdle),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade800),
                  child: const Text('TRIGGER RANDOM IDLE'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'PERSONALITY DEBUG LAB (Phase 7)',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.black45,
              width: 300,
              child: _lastDecision == null
                  ? const Text('AWAITING EVENT...', style: TextStyle(color: Colors.white54, fontSize: 10))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EVENT: ${_lastDecision!.event.type.name.toUpperCase()}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                        const SizedBox(height: 4),
                        Text('SIGNIFICANCE: ${_lastDecision!.significance.name.toUpperCase()}',
                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontFamily: 'monospace')),
                        const SizedBox(height: 4),
                        Text('EMOTIONAL STATE: ${_lastDecision!.emotionalState.name.toUpperCase()}',
                            style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontFamily: 'monospace')),
                        const SizedBox(height: 4),
                        Text('INTENSITY: ${_lastDecision!.intensity.name.toUpperCase()} (${_lastDecision!.intensity.index})',
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontFamily: 'monospace')),
                        const SizedBox(height: 4),
                        Text('SHOULD REACT: ${_lastDecision!.shouldReact ? 'YES' : 'NO'}',
                            style: TextStyle(color: _lastDecision!.shouldReact ? Colors.greenAccent : Colors.redAccent, fontSize: 11, fontFamily: 'monospace')),
                        const SizedBox(height: 8),
                        Text('REASON:\n${_lastDecision!.reason}',
                            style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
                        const SizedBox(height: 8),
                        Text('RESULT: ${_lastDecision!.shouldReact ? '→ DISPATCHED TO PHASE 6' : '→ SUPPRESSED BY PERSONALITY'}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.black45,
              width: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BEHAVIOUR STATE: ${state?.behaviourState.name.toUpperCase() ?? 'IDLE'}',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'CURRENT BEHAVIOUR: ${state?.currentBehaviour.name.toUpperCase() ?? 'NONE'}',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PRIORITY: ${state?.currentPriority.name.toUpperCase() ?? 'IDLE'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ANIM STATE: ${state?.currentInteractionState?.name ?? 'idle'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'LAST EVENT: ${state?.lastEvent?.type.name ?? 'None'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'COOLDOWNS',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ACHIEVEMENT: ${_formatDuration(state?.getRemainingCooldown(MitraBehaviourCategory.achievement) ?? Duration.zero)}',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  Text(
                    'SUNFLOWER: ${_formatDuration(state?.getRemainingCooldown(MitraBehaviourCategory.sunflower) ?? Duration.zero)}',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  Text(
                    'PEEK: ${_formatDuration(state?.getRemainingCooldown(MitraBehaviourCategory.peek) ?? Duration.zero)}',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'RECENT HISTORY',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state?.mitraContext.recentBehaviours.map((e) => e.name).join(' -> ') ?? 'Empty',
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        )
      ],
    );
  }
}

class _MitraMemoryLabSection extends StatefulWidget {
  const _MitraMemoryLabSection();

  @override
  State<_MitraMemoryLabSection> createState() => _MitraMemoryLabSectionState();
}

class _MitraMemoryLabSectionState extends State<_MitraMemoryLabSection> {
  final MitraMemoryEngine _memoryEngine = MitraMemoryEngine();
  MitraMemorySnapshot? _lastSnapshot;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _lastSnapshot = _memoryEngine.createSnapshot();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _lastSnapshot = _memoryEngine.createSnapshot();
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _recordEvent(MitraEventType type, {bool isMilestone = false}) {
    setState(() {
      _lastSnapshot = _memoryEngine.recordEvent(MitraEvent(type), isMilestone: isMilestone);
    });
  }

  String _formatDuration(Duration? d) {
    if (d == null) return 'Never';
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final contextData = _memoryEngine.debugContext;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left: Control Dashboard
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MEMORY CONTROLS',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              direction: Axis.vertical,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _recordEvent(MitraEventType.workoutCompleted),
                  icon: const Icon(Icons.fitness_center, size: 16),
                  label: const Text('RECORD WORKOUT'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800),
                ),
                ElevatedButton.icon(
                  onPressed: () => _recordEvent(MitraEventType.achievement),
                  icon: const Icon(Icons.star, size: 16),
                  label: const Text('RECORD HABIT'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800),
                ),
                ElevatedButton.icon(
                  onPressed: () => _recordEvent(MitraEventType.userReturn),
                  icon: const Icon(Icons.person, size: 16),
                  label: const Text('RECORD USER RETURN'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                ),
                ElevatedButton.icon(
                  onPressed: () => _recordEvent(MitraEventType.achievement, isMilestone: true),
                  icon: const Icon(Icons.emoji_events, size: 16),
                  label: const Text('RECORD MILESTONE'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _memoryEngine.resetMemory();
                    setState(() {
                      _lastSnapshot = _memoryEngine.createSnapshot();
                    });
                  },
                  icon: const Icon(Icons.delete_forever, size: 16),
                  label: const Text('RESET MEMORY'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(width: 48),

        // Right: Memory State
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.black45,
          width: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MEMORY STATE',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('Last Event: ${contextData.lastEventTime?.toString().split('.').first ?? 'Never'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
              Text('Last Workout: ${contextData.lastWorkoutTime?.toString().split('.').first ?? 'Never'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
              Text('Last Meaningful Event: ${contextData.lastMeaningfulEventTime?.toString().split('.').first ?? 'Never'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
              Text('Last User Return: ${contextData.lastUserReturnTime?.toString().split('.').first ?? 'Never'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              Text('Time Since Last Interaction: ${_formatDuration(_lastSnapshot?.timeSinceLastInteraction)}',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontFamily: 'monospace')),
              Text('Time Since Last Workout: ${_formatDuration(_lastSnapshot?.timeSinceLastWorkout)}',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              Text('Recent Memory Count: ${_lastSnapshot?.recentInteractionCount ?? 0}',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontFamily: 'monospace')),
              Text('Meaningful Memory Count: ${_lastSnapshot?.recentAchievementCount ?? 0}',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontFamily: 'monospace')),
              Text('Milestone Count: ${contextData.milestoneEvents.length}',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              Text('Latest Milestone: ${_lastSnapshot?.latestMilestone?.originalType.name ?? 'None'}',
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 12),
              const Text(
                'CURRENT SNAPSHOT',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('hasRecentWorkout: ${_lastSnapshot?.hasRecentWorkout ?? false}',
                  style: TextStyle(color: (_lastSnapshot?.hasRecentWorkout ?? false) ? Colors.greenAccent : Colors.white54, fontSize: 10, fontFamily: 'monospace')),
              Text('hasRecentMeaningfulEvent: ${_lastSnapshot?.hasRecentMeaningfulEvent ?? false}',
                  style: TextStyle(color: (_lastSnapshot?.hasRecentMeaningfulEvent ?? false) ? Colors.greenAccent : Colors.white54, fontSize: 10, fontFamily: 'monospace')),
              Text('hasRecentUserReturn: ${_lastSnapshot?.hasRecentUserReturn ?? false}',
                  style: TextStyle(color: (_lastSnapshot?.hasRecentUserReturn ?? false) ? Colors.greenAccent : Colors.white54, fontSize: 10, fontFamily: 'monospace')),
              Text('hasMilestone: ${_lastSnapshot?.hasMilestone ?? false}',
                  style: TextStyle(color: (_lastSnapshot?.hasMilestone ?? false) ? Colors.greenAccent : Colors.white54, fontSize: 10, fontFamily: 'monospace')),
            ],
          ),
        ),
      ],
    );
  }
}

class _MitraRelationshipLabSection extends StatefulWidget {
  const _MitraRelationshipLabSection();

  @override
  State<_MitraRelationshipLabSection> createState() => _MitraRelationshipLabSectionState();
}

class _MitraRelationshipLabSectionState extends State<_MitraRelationshipLabSection> {
  final MitraRelationshipEngine _relationshipEngine = MitraRelationshipEngine();
  MitraRelationshipDecision? _lastDecision;
  
  void _recordEvent(MitraRelationshipEventType type) {
    setState(() {
      _lastDecision = _relationshipEngine.evaluate(MitraRelationshipEvent(type: type));
    });
  }

  @override
  Widget build(BuildContext context) {
    final contextData = _relationshipEngine.debugContext;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left: Control Dashboard
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RELATIONSHIP CONTROLS',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              direction: Axis.vertical,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _recordEvent(MitraRelationshipEventType.firstInteraction),
                  icon: const Icon(Icons.waving_hand, size: 16),
                  label: const Text('FIRST INTERACTION'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                ),
                ElevatedButton.icon(
                  onPressed: () => _recordEvent(MitraRelationshipEventType.workoutCompleted),
                  icon: const Icon(Icons.fitness_center, size: 16),
                  label: const Text('WORKOUT COMPLETED'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800),
                ),
                ElevatedButton.icon(
                  onPressed: () => _recordEvent(MitraRelationshipEventType.habitCompleted),
                  icon: const Icon(Icons.star, size: 16),
                  label: const Text('HABIT COMPLETED'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800),
                ),
                ElevatedButton.icon(
                  onPressed: () => _recordEvent(MitraRelationshipEventType.userReturned),
                  icon: const Icon(Icons.person, size: 16),
                  label: const Text('USER RETURN'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                ),
                ElevatedButton.icon(
                  onPressed: () => _recordEvent(MitraRelationshipEventType.returnedAfterGap),
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('RETURN AFTER GAP'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown.shade800),
                ),
                ElevatedButton.icon(
                  onPressed: () => _recordEvent(MitraRelationshipEventType.milestoneReached),
                  icon: const Icon(Icons.emoji_events, size: 16),
                  label: const Text('MILESTONE'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
                ),
                ElevatedButton.icon(
                  onPressed: () => _recordEvent(MitraRelationshipEventType.meaningfulProgress),
                  icon: const Icon(Icons.autorenew, size: 16),
                  label: const Text('REPEATED INTERACTION'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pink.shade800),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _relationshipEngine.resetRelationship();
                    setState(() {
                      _lastDecision = null;
                    });
                  },
                  icon: const Icon(Icons.delete_forever, size: 16),
                  label: const Text('RESET RELATIONSHIP'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(width: 48),

        // Right: Relationship State
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.black45,
          width: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PERSONALITY / RELATIONSHIP DEBUG LAB',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('RELATIONSHIP EVENT: ${_lastDecision?.event.type.name ?? 'None'}',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              Text('FAMILIARITY: ${_lastDecision?.familiarity.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontFamily: 'monospace')),
              Text('RELATIONSHIP TONE: ${_lastDecision?.tone.name ?? 'reserved'}',
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontFamily: 'monospace')),
              Text('MILESTONE: ${_lastDecision?.milestone.name ?? 'none'}',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace')),
              Text('IS FAMILIAR: ${_lastDecision?.isFamiliar ?? false}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              Text('RELATIONSHIP REASON:\n${_lastDecision?.reason ?? 'None'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 16),
              const Text(
                'CONTEXT STATE',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('TOTAL INTERACTIONS: ${contextData.totalInteractionCount}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
              Text('MEANINGFUL INTERACTIONS: ${contextData.meaningfulInteractionCount}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
              Text('WORKOUTS: ${contextData.completedWorkoutCount}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              const Text(
                'RECENT RELATIONSHIP EVENTS',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                contextData.recentRelationshipEvents.map((e) => e.name).join(' ->\n') + (contextData.recentRelationshipEvents.isEmpty ? 'Empty' : ''),
                style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MitraAppEnvironmentLabSection extends StatefulWidget {
  const _MitraAppEnvironmentLabSection();

  @override
  State<_MitraAppEnvironmentLabSection> createState() => _MitraAppEnvironmentLabSectionState();
}

class _MitraAppEnvironmentLabSectionState extends State<_MitraAppEnvironmentLabSection> {
  final MitraContextEngine _contextEngine = MitraContextEngine();
  
  void _updateScreen(MitraAppScreen screen) {
    setState(() {
      _contextEngine.updateScreen(screen);
    });
  }
  
  void _updateLifecycle(MitraAppLifecycle lifecycle) {
    setState(() {
      _contextEngine.updateLifecycle(lifecycle);
    });
  }
  
  void _updateActivity(MitraUserActivity activity) {
    setState(() {
      _contextEngine.updateActivity(activity);
    });
  }
  
  void _pingInteraction() {
    setState(() {
      _contextEngine.pingInteraction();
    });
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _contextEngine.currentSnapshot;
    final recentTransitions = _contextEngine.recentTransitions;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left: Control Dashboard
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ENVIRONMENT CONTROLS',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              direction: Axis.horizontal,
              children: [
                ElevatedButton(
                  onPressed: () => _updateScreen(MitraAppScreen.home),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  child: const Text('SCREEN: HOME', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _updateScreen(MitraAppScreen.workout),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  child: const Text('SCREEN: WORKOUT', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _updateScreen(MitraAppScreen.habits),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  child: const Text('SCREEN: HABITS', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _updateScreen(MitraAppScreen.nutrition),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  child: const Text('SCREEN: NUTRITION', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _updateScreen(MitraAppScreen.progress),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  child: const Text('SCREEN: PROGRESS', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _updateScreen(MitraAppScreen.settings),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  child: const Text('SCREEN: SETTINGS', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _updateLifecycle(MitraAppLifecycle.foreground),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800),
                  child: const Text('FOREGROUND', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _updateLifecycle(MitraAppLifecycle.background),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800),
                  child: const Text('BACKGROUND', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _updateLifecycle(MitraAppLifecycle.inactive),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800),
                  child: const Text('INACTIVE', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _updateActivity(MitraUserActivity.idle),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800),
                  child: const Text('ACT: IDLE', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _updateActivity(MitraUserActivity.browsing),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800),
                  child: const Text('ACT: BROWSING', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _updateActivity(MitraUserActivity.engaged),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800),
                  child: const Text('ACT: ENGAGED', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _updateActivity(MitraUserActivity.transitioning),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800),
                  child: const Text('ACT: TRANSITIONING', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _pingInteraction,
              icon: const Icon(Icons.touch_app, size: 16),
              label: const Text('PING INTERACTION', style: TextStyle(fontSize: 10)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
            ),
          ],
        ),
        const SizedBox(width: 48),

        // Right: Context State
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.black45,
          width: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CURRENT APP ENVIRONMENT (SNAPSHOT)',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('SCREEN: ${snapshot.currentScreen.name.toUpperCase()}',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontFamily: 'monospace')),
              Text('PREVIOUS SCREEN: ${snapshot.previousScreen.name.toUpperCase()}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              Text('ACTIVITY: ${snapshot.currentActivity.name.toUpperCase()}',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontFamily: 'monospace')),
              Text('LIFECYCLE: ${snapshot.lifecycleState.name.toUpperCase()}',
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              Text('TIME OF DAY: ${snapshot.timeOfDay.name.toUpperCase()}',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              Text('SESSION START: ${snapshot.sessionStartTime.toString().split('.').first}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
              Text('LAST INTERACTION: ${snapshot.lastUserInteractionTime.toString().split('.').first}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
              Text('TIME SINCE INTERACTION: ${_formatDuration(snapshot.timeSinceLastInteraction)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 16),
              const Text(
                'RECENT TRANSITIONS (DUPLICATE PROTECTION LOG)',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              if (recentTransitions.isEmpty)
                const Text('No transitions yet.', style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace'))
              else
                ...recentTransitions.reversed.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    '[${t.lifecycleState.name.substring(0,3).toUpperCase()}] ${t.previousScreen.name} -> ${t.currentScreen.name} (${t.currentActivity.name})',
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                  ),
                )),
            ],
          ),
        ),
      ],
    );
  }
}

class _MitraAttentionLabSection extends StatefulWidget {
  const _MitraAttentionLabSection();

  @override
  State<_MitraAttentionLabSection> createState() => _MitraAttentionLabSectionState();
}

class _MitraAttentionLabSectionState extends State<_MitraAttentionLabSection> {
  final MitraContextEngine _contextEngine = MitraContextEngine();
  final MitraPersonalityEngine _personalityEngine = MitraPersonalityEngine();
  final MitraAttentionEngine _attentionEngine = MitraAttentionEngine();
  
  MitraOpportunityDecision? _lastDecision;
  MitraPersonalityDecision? _lastPersonalityDecision;

  void _runScenario({
    required MitraEventType eventType,
    required MitraAppScreen screen,
    required MitraUserActivity activity,
    required MitraAppLifecycle lifecycle,
  }) {
    // 1. Update Context
    _contextEngine.updateScreen(screen);
    _contextEngine.updateActivity(activity);
    _contextEngine.updateLifecycle(lifecycle);
    
    // Ping interaction arbitrarily if not idle, or just use what it is. 
    // We will just let it use current time for now.
    
    final contextSnapshot = _contextEngine.currentSnapshot;
    final event = MitraEvent(eventType);
    
    // 2. Personality
    final personality = _personalityEngine.evaluate(event);
    
    // 3. Opportunity
    final opportunity = MitraOpportunity(
      event: event,
      contextSnapshot: contextSnapshot,
      personalityDecision: personality,
    );
    
    final decision = _attentionEngine.evaluate(opportunity, DateTime.now());
    
    setState(() {
      _lastPersonalityDecision = personality;
      _lastDecision = decision;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left: Controls
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SCENARIO CONTROLS',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              direction: Axis.vertical,
              children: [
                ElevatedButton(
                  onPressed: () => _runScenario(
                    eventType: MitraEventType.navigationIdle,
                    screen: MitraAppScreen.home,
                    activity: MitraUserActivity.idle,
                    lifecycle: MitraAppLifecycle.foreground,
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  child: const Text('1. IDLE + NATURAL PAUSE'),
                ),
                ElevatedButton(
                  onPressed: () => _runScenario(
                    eventType: MitraEventType.achievement,
                    screen: MitraAppScreen.home,
                    activity: MitraUserActivity.idle,
                    lifecycle: MitraAppLifecycle.foreground,
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800),
                  child: const Text('2. IDLE + MEANINGFUL EVENT'),
                ),
                ElevatedButton(
                  onPressed: () => _runScenario(
                    eventType: MitraEventType.achievement,
                    screen: MitraAppScreen.workout,
                    activity: MitraUserActivity.engaged,
                    lifecycle: MitraAppLifecycle.foreground,
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800),
                  child: const Text('3. ACTIVE WORKOUT + MEANINGFUL'),
                ),
                ElevatedButton(
                  onPressed: () => _runScenario(
                    eventType: MitraEventType.navigationIdle,
                    screen: MitraAppScreen.workout,
                    activity: MitraUserActivity.engaged,
                    lifecycle: MitraAppLifecycle.foreground,
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800),
                  child: const Text('4. ACTIVE WORKOUT + TRIVIAL'),
                ),
                ElevatedButton(
                  onPressed: () => _runScenario(
                    eventType: MitraEventType.navigationIdle,
                    screen: MitraAppScreen.home,
                    activity: MitraUserActivity.transitioning,
                    lifecycle: MitraAppLifecycle.foreground,
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
                  child: const Text('5. NAVIGATION TRANSITION'),
                ),
                ElevatedButton(
                  onPressed: () => _runScenario(
                    eventType: MitraEventType.navigationIdle,
                    screen: MitraAppScreen.home,
                    activity: MitraUserActivity.idle,
                    lifecycle: MitraAppLifecycle.background,
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown.shade800),
                  child: const Text('6. BACKGROUND'),
                ),
                ElevatedButton(
                  onPressed: () => _runScenario(
                    eventType: MitraEventType.userReturn,
                    screen: MitraAppScreen.home,
                    activity: MitraUserActivity.idle,
                    lifecycle: MitraAppLifecycle.foreground,
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade800),
                  child: const Text('7. USER RETURN'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _attentionEngine.resetContext();
                    setState(() {
                      _lastDecision = null;
                      _lastPersonalityDecision = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                  child: const Text('RESET ATTENTION MEMORY'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(width: 48),

        // Right: Result Display
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.black45,
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ATTENTION / OPPORTUNITY DECISION',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              const Text('CONTEXT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('SCREEN: ${_contextEngine.currentSnapshot.currentScreen.name}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
              Text('ACTIVITY: ${_contextEngine.currentSnapshot.currentActivity.name}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
              Text('LIFECYCLE: ${_contextEngine.currentSnapshot.lifecycleState.name}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
              Text('TIME OF DAY: ${_contextEngine.currentSnapshot.timeOfDay.name}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 12),
              
              const Text('PERSONALITY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('EVENT: ${_lastPersonalityDecision?.event.type.name ?? 'None'}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontFamily: 'monospace')),
              Text('SIGNIFICANCE: ${_lastPersonalityDecision?.significance.name ?? 'None'}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontFamily: 'monospace')),
              Text('INTENSITY: ${_lastPersonalityDecision?.intensity.name ?? 'None'}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 12),
              
              const Text('ATTENTION', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('ATTENTION LEVEL: ${_lastDecision?.attentionLevel.name ?? 'None'}', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontFamily: 'monospace')),
              Text('OPPORTUNITY: ${_lastDecision?.type.name ?? 'None'}', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontFamily: 'monospace')),
              Text('INTERRUPTION RISK: ${_lastDecision?.interruptionRisk.name ?? 'None'}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontFamily: 'monospace')),
              Text('SCORE: ${_lastDecision?.score.toStringAsFixed(1) ?? '0.0'}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 12),
              
              const Text('DECISION', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('SHOULD PROCEED: ${_lastDecision?.shouldProceed ?? false}', style: TextStyle(color: (_lastDecision?.shouldProceed ?? false) ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              Text('DELAY: ${_lastDecision?.recommendedDelay?.inMilliseconds ?? 0}ms', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              Text('REASON:\n${_lastDecision?.reason ?? 'None'}', style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
            ],
          ),
        ),
      ],
    );
  }
}

class _MitraSunflowerLabSection extends StatefulWidget {
  const _MitraSunflowerLabSection();

  @override
  State<_MitraSunflowerLabSection> createState() => _MitraSunflowerLabSectionState();
}

class _MitraSunflowerLabSectionState extends State<_MitraSunflowerLabSection> {
  final MitraSunflowerEngine _sunflowerEngine = MitraSunflowerEngine();

  @override
  void initState() {
    super.initState();
    _sunflowerEngine.resetDay(); // initial eval
  }

  void _addContribution(int steps, int water, int habit, int workout) {
    setState(() {
      _sunflowerEngine.addContribution(
        steps: steps,
        water: water,
        habit: habit,
        workout: workout,
      );
    });
  }

  void _setTimeOfDay(MitraSunflowerTimeOfDay time) {
    setState(() {
      _sunflowerEngine.forceTimeOfDay(time);
    });
  }

  void _simulateNewDay() {
    setState(() {
      _sunflowerEngine.simulateNewDay();
    });
  }
  
  void _resetDay() {
    setState(() {
      _sunflowerEngine.resetDay();
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _sunflowerEngine.currentSnapshot;
    final contextData = _sunflowerEngine.debugContext;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left: Controls
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SUNFLOWER CONTROLS',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _setTimeOfDay(MitraSunflowerTimeOfDay.morning),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  child: const Text('SET MORNING', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _setTimeOfDay(MitraSunflowerTimeOfDay.afternoon),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  child: const Text('SET AFTERNOON', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _setTimeOfDay(MitraSunflowerTimeOfDay.evening),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  child: const Text('SET EVENING', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _setTimeOfDay(MitraSunflowerTimeOfDay.night),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  child: const Text('SET NIGHT', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _addContribution(5, 0, 0, 0),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800),
                  child: const Text('ADD SMALL PROGRESS', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _addContribution(15, 0, 0, 0),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800),
                  child: const Text('ADD MEANINGFUL PROGRESS', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _addContribution(0, 0, 0, 30),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800),
                  child: const Text('ADD WORKOUT', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _addContribution(0, 10, 0, 0),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade800),
                  child: const Text('ADD WATER', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _addContribution(0, 0, 10, 0),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
                  child: const Text('ADD HABIT', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _resetDay,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                  child: const Text('RESET DAY', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: _simulateNewDay,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown.shade800),
                  child: const Text('SIMULATE NEW DAY', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(width: 48),

        // Right: Result Display
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.black45,
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SUNFLOWER STATE',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              Text('CURRENT STATE: ${snapshot?.state.name.toUpperCase() ?? 'None'}', 
                style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              Text('DAILY PROGRESS CATEGORY: ${snapshot?.progress.category.name.toUpperCase() ?? 'None'}', 
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontFamily: 'monospace')),
              Text('TIME OF DAY: ${snapshot?.timeOfDay.name.toUpperCase() ?? 'None'}', 
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 12),
              
              const Text('CONTRIBUTIONS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('STEPS: ${snapshot?.progress.stepsContribution ?? 0}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
              Text('WATER: ${snapshot?.progress.waterContribution ?? 0}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
              Text('SLEEP: ${snapshot?.progress.sleepContribution ?? 0}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
              Text('WORKOUT: ${snapshot?.progress.workoutContribution ?? 0}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
              Text('HABIT: ${snapshot?.progress.habitContribution ?? 0}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 12),
              
              const Text('LAST TRANSITION', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('TIME: ${contextData.lastTransitionTime?.toString().split('.').first ?? 'Never'}', style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 4),
              Text('REASON: ${contextData.lastTransitionReason ?? 'None'}', style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace')),
            ],
          ),
        ),
      ],
    );
  }
}

class _MitraSunflowerAnimationLabSection extends StatefulWidget {
  const _MitraSunflowerAnimationLabSection();

  @override
  State<_MitraSunflowerAnimationLabSection> createState() => _MitraSunflowerAnimationLabSectionState();
}

class _MitraSunflowerAnimationLabSectionState extends State<_MitraSunflowerAnimationLabSection> {
  late final MitraSunflowerAnimationController _animationController;
  
  MitraSunflowerAnimationTransition? _lastDispatchedTransition;
  bool _transitionSuppressed = false;
  MitraSunflowerState? _lastResolvedState;

  @override
  void initState() {
    super.initState();
    _animationController = MitraSunflowerAnimationController(
      onTransitionRequested: (transition) {
        setState(() {
          _lastDispatchedTransition = transition;
          _transitionSuppressed = false;
        });
      }
    );
  }
  
  void _forceState(MitraSunflowerAnimationState state) {
    setState(() {
      _animationController.forceState(state);
    });
  }

  void _triggerAnimation(MitraSunflowerAnimationTransition transition) {
    setState(() {
      _animationController.requestTransition(transition, DateTime.now());
    });
  }

  void _toggleReducedMotion(bool val) {
    setState(() {
      _animationController.setReducedMotion(val);
    });
  }

  void _tick() {
    setState(() {
      _animationController.tick(DateTime.now());
    });
  }

  void _simulatePhase20(MitraSunflowerState state, {bool isNewDay = false, bool resetLatch = false}) {
    setState(() {
      if (resetLatch) {
        _animationController.debugResetLatch();
      }
      
      _lastResolvedState = state;
      _lastDispatchedTransition = null;
      
      final now = DateTime.now();
      final dateToUse = isNewDay ? now.add(const Duration(days: 1)) : now;
      
      final beforeMark = _animationController.debugDailyHighWaterMark;
      final beforeTrans = _animationController.currentSnapshot.activeTransition;
      
      _animationController.processPhase12Snapshot(state, dateToUse);
      
      // If we didn't dispatch a new transition and the mark didn't change (or it's suppressed)
      if (_lastDispatchedTransition == null) {
        _transitionSuppressed = true;
      } else {
        _transitionSuppressed = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _animationController.currentSnapshot;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left: Controls
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ANIMATION LAB CONTROLS',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(onPressed: () => _forceState(MitraSunflowerAnimationState.idle), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey), child: const Text('[SEED/SPROUT]', style: TextStyle(fontSize: 10))),
                ElevatedButton(onPressed: () => _forceState(MitraSunflowerAnimationState.waking), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey), child: const Text('[YOUNG]', style: TextStyle(fontSize: 10))),
                ElevatedButton(onPressed: () => _forceState(MitraSunflowerAnimationState.growing), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey), child: const Text('[BUD]', style: TextStyle(fontSize: 10))),
                ElevatedButton(onPressed: () => _forceState(MitraSunflowerAnimationState.blooming), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey), child: const Text('[BLOOM]', style: TextStyle(fontSize: 10))),
                ElevatedButton(onPressed: () => _forceState(MitraSunflowerAnimationState.resting), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey), child: const Text('[REST]', style: TextStyle(fontSize: 10))),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(onPressed: () => _triggerAnimation(MitraSunflowerAnimationChoreography.wake), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800), child: const Text('[WAKE]', style: TextStyle(fontSize: 10))),
                ElevatedButton(onPressed: () => _triggerAnimation(MitraSunflowerAnimationChoreography.grow), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800), child: const Text('[GROW]', style: TextStyle(fontSize: 10))),
                ElevatedButton(onPressed: () => _triggerAnimation(MitraSunflowerAnimationChoreography.smallProgress), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800), child: const Text('[SMALL PROGRESS]', style: TextStyle(fontSize: 10))),
                ElevatedButton(onPressed: () => _triggerAnimation(MitraSunflowerAnimationChoreography.flourish), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800), child: const Text('[FLOURISH]', style: TextStyle(fontSize: 10))),
                ElevatedButton(onPressed: () => _triggerAnimation(MitraSunflowerAnimationChoreography.bloom), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800), child: const Text('[BLOOM]', style: TextStyle(fontSize: 10))),
                ElevatedButton(onPressed: () => _triggerAnimation(MitraSunflowerAnimationChoreography.settle), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade800), child: const Text('[SETTLE]', style: TextStyle(fontSize: 10))),
                ElevatedButton(onPressed: () => _triggerAnimation(MitraSunflowerAnimationChoreography.rest), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade800), child: const Text('[REST]', style: TextStyle(fontSize: 10))),
                ElevatedButton(onPressed: () => _triggerAnimation(MitraSunflowerAnimationChoreography.reset), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800), child: const Text('[RESET]', style: TextStyle(fontSize: 10))),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _tick,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown.shade800),
                  child: const Text('MANUAL TICK', style: TextStyle(fontSize: 10)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('REDUCED MOTION', style: TextStyle(color: Colors.white, fontSize: 10)),
                    Switch(
                      value: snapshot.isReducedMotion,
                      onChanged: _toggleReducedMotion,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'PHASE 20: SUNFLOWER STABILITY LAB',
              style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(onPressed: () => _simulatePhase20(MitraSunflowerState.fullBloom, resetLatch: true), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey), child: const Text('[SIMULATE RESTART]', style: TextStyle(fontSize: 10))),
                ElevatedButton(onPressed: () => _simulatePhase20(MitraSunflowerState.fullBloom), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800), child: const Text('[FORWARD TRANSITION]', style: TextStyle(fontSize: 10))),
                ElevatedButton(onPressed: () => _simulatePhase20(MitraSunflowerState.growing), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800), child: const Text('[BACKWARD TRANSITION]', style: TextStyle(fontSize: 10))),
                ElevatedButton(onPressed: () => _simulatePhase20(MitraSunflowerState.sprout, isNewDay: true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800), child: const Text('[SIMULATE NEW DAY]', style: TextStyle(fontSize: 10))),
                ElevatedButton(onPressed: () => _simulatePhase20(MitraSunflowerState.seed, resetLatch: true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800), child: const Text('[RESET DAILY LATCH]', style: TextStyle(fontSize: 10))),
              ],
            ),
          ],
        ),
        const SizedBox(width: 48),

        // Right: Result Display
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.black45,
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VISUAL PRESENTATION (PHASE 21)',
                style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: const Center(
                    child: Text(
                      'SUNFLOWER MOVED TO PRODUCTION',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'ANIMATION STATE',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              Text('CURRENT VISUAL STATE: ${snapshot.currentState.name.toUpperCase()}', 
                style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              Text('ACTIVE TRANSITION: ${snapshot.activeTransition?.name.toUpperCase() ?? 'NONE'}', 
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontFamily: 'monospace')),
              Text('CURRENT PRIORITY: ${snapshot.activeTransition?.priority.name.toUpperCase() ?? 'NONE'}', 
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 16),
              
              const Text('PHASE 20 LATCH STATUS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('IS INITIALIZED: ${_animationController.debugIsInitialized}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
              Text('LATCH DATE: ${_animationController.debugLatchDate?.toString().split('.').first ?? 'None'}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
              Text('LATCHED STATE: ${_animationController.debugDailyHighWaterMark?.name.toUpperCase() ?? 'None'}', style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              const SizedBox(height: 16),

              const Text('PHASE 20 LAST TEST', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('RESOLVED STATE: ${_lastResolvedState?.name.toUpperCase() ?? 'None'}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
              Text('TRANSITION FIRED: ${_lastDispatchedTransition?.name.toUpperCase() ?? 'NONE'}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
              Text('SUPPRESSED BY LATCH: $_transitionSuppressed', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 12),
              
              const Text('STATUS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('REDUCED MOTION: ${snapshot.isReducedMotion ? "ON" : "OFF"}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
            ],
          ),
        ),
      ],
    );
  }
}

class _MitraSunflowerIntegrationLabSection extends ConsumerWidget {
  const _MitraSunflowerIntegrationLabSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(sunflowerIntegrationProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black45,
      width: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CURRENT DATE: ${snapshot.date.toIso8601String().split('T').first}', style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
          const SizedBox(height: 16),

          const Text('CORE STHIRA SCORE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('DailyScore: ${(snapshot.coreDailyProgress * 100).round()} / 100', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
          Text('Core Progress: ${snapshot.coreDailyProgress.toStringAsFixed(2)}', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontFamily: 'monospace')),
          
          const SizedBox(height: 16),
          const Text('SUPPORTING SIGNALS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Steps: ${(snapshot.normalizedSteps * 100).round()}%', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
          Text('Water: ${(snapshot.normalizedWater * 100).round()}%', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
          Text('Sleep: ${(snapshot.normalizedSleep * 100).round()}%', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
          
          const SizedBox(height: 16),
          const Text('NORMALIZED OUTPUT', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Supporting Context: ${snapshot.supportingContext.name.toUpperCase()}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontFamily: 'monospace')),
          
          const SizedBox(height: 16),
          const Text('DATA QUALITY', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(snapshot.availability.name.toUpperCase(), style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

class _MitraCinematicLabSection extends StatefulWidget {
  const _MitraCinematicLabSection();

  @override
  State<_MitraCinematicLabSection> createState() => _MitraCinematicLabSectionState();
}

class _MitraCinematicLabSectionState extends State<_MitraCinematicLabSection> {
  final GlobalKey<MitraInteractionEngineState> _interactionKey = GlobalKey<MitraInteractionEngineState>();
  late final MitraCinematicIntegrationEngine _integrationEngine;
  
  MitraSunflowerInteractionTier _selectedTier = MitraSunflowerInteractionTier.none;
  String _activeTransition = 'none';
  bool _isSimulating = false;

  @override
  void initState() {
    super.initState();
    _integrationEngine = MitraCinematicIntegrationEngine(
      interactionKey: _interactionKey,
      onContextualEvent: (MitraSunflowerAnimationTransition transition) {
        if (mounted) {
          setState(() {
            _activeTransition = transition.name;
          });
        }
      },
    );
  }

  void _simulateEvent(MitraEventSignificance sig) async {
    setState(() {
      _isSimulating = true;
      _activeTransition = 'none';
    });

    // Create a fake snapshot to simulate progress
    final snapshot = MitraDailyProgressSnapshot(
      coreDailyProgress: 0.8,
      normalizedSteps: 0.5,
      normalizedWater: 0.5,
      normalizedSleep: 0.5,
      supportingContext: SupportingWellnessContext.supportive,
      availability: DataAvailability.complete,
      date: DateTime.now(),
    );

    // Bypass real integration and directly set tier based on test button for visual test
    MitraSunflowerInteractionTier forcedTier = MitraSunflowerInteractionTier.none;
    switch (sig) {
      case MitraEventSignificance.trivial:
        forcedTier = MitraSunflowerInteractionTier.microNotice;
        break;
      case MitraEventSignificance.meaningful:
        forcedTier = MitraSunflowerInteractionTier.observe;
        break;
      case MitraEventSignificance.important:
        forcedTier = MitraSunflowerInteractionTier.full;
        break;
      case MitraEventSignificance.special:
        forcedTier = MitraSunflowerInteractionTier.special;
        break;
    }

    setState(() {
      _selectedTier = forcedTier;
    });

    if (forcedTier != MitraSunflowerInteractionTier.none) {
      await _interactionKey.currentState?.playSunflowerSequence(
        tier: forcedTier,
        onContextualEvent: (transitionName) {
          if (mounted) {
            setState(() {
              _activeTransition = transitionName;
            });
          }
        }
      );
    }
    
    if (mounted) {
      setState(() {
        _isSimulating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left: The interaction engine preview
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24, width: 1),
            color: Colors.black26,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: Colors.red.withOpacity(0.5),
                ),
              ),
              MitraInteractionEngine(
                key: _interactionKey,
                size: 160,
                showDebugBounds: false,
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),

        // Right: Control Dashboard
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CINEMATIC LAB CONTROLS',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              direction: Axis.vertical,
              children: [
                ElevatedButton.icon(
                  onPressed: _isSimulating ? null : () => _simulateEvent(MitraEventSignificance.trivial),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('MICRO NOTICE'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                ),
                ElevatedButton.icon(
                  onPressed: _isSimulating ? null : () => _simulateEvent(MitraEventSignificance.meaningful),
                  icon: const Icon(Icons.remove_red_eye, size: 16),
                  label: const Text('OBSERVE'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                ),
                ElevatedButton.icon(
                  onPressed: _isSimulating ? null : () => _simulateEvent(MitraEventSignificance.important),
                  icon: const Icon(Icons.local_florist, size: 16),
                  label: const Text('FULL INTERACTION'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
                ),
                ElevatedButton.icon(
                  onPressed: _isSimulating ? null : () => _simulateEvent(MitraEventSignificance.special),
                  icon: const Icon(Icons.star, size: 16),
                  label: const Text('SPECIAL BLOOM'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _interactionKey.currentState?.reset();
                    setState(() {
                      _isSimulating = false;
                      _activeTransition = 'none';
                      _selectedTier = MitraSunflowerInteractionTier.none;
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('RESET'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.black45,
              width: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CINEMATIC STATE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Mitra State: ${_interactionKey.currentState?.currentMitraState?.name.toUpperCase() ?? "IDLE"}', style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  Text('Tier: ${_selectedTier.name.toUpperCase()}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  Text('Transition: $_activeTransition', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        )
      ],
    );
  }
}


class _MitraLivingBehaviourLabSection extends StatefulWidget {
  const _MitraLivingBehaviourLabSection();

  @override
  State<_MitraLivingBehaviourLabSection> createState() => _MitraLivingBehaviourLabSectionState();
}

class _MitraLivingBehaviourLabSectionState extends State<_MitraLivingBehaviourLabSection> {
  final GlobalKey<MitraBehaviourEngineState> _behaviourKey = GlobalKey<MitraBehaviourEngineState>();
  late MitraCinematicIntegrationEngine _integrationEngine;
  bool _attentionSuppressed = false;
  bool _restTimerActive = false;

  @override
  void initState() {
    super.initState();
    _integrationEngine = MitraCinematicIntegrationEngine(
      interactionKey: GlobalKey<MitraInteractionEngineState>(),
      behaviourKey: _behaviourKey,
      onContextualEvent: (transition) {},
    );
  }

  void _triggerIdleNotice() {
    _behaviourKey.currentState?.dispatch(MitraEvent(MitraEventType.notice));
  }

  void _triggerChoreographedGrow() {
    final snapshot = MitraDailyProgressSnapshot(
      date: DateTime.now(),
      coreDailyProgress: 0.5,
      supportingContext: SupportingWellnessContext.neutral,
      normalizedSteps: 0.5,
      normalizedWater: 0.5,
      normalizedSleep: 0.5,
      availability: DataAvailability.complete,
    );
    final signal = MitraSunflowerInteractionSignal(
      snapshot: snapshot,
      progressChange: 0.1,
    );
    _integrationEngine.onProgressSignal(signal);
  }

  void _resetCooldowns() {
    _behaviourKey.currentState?.mitraContext.resetAllCooldowns();
    setState(() {});
  }

  void _toggleAttentionSuppression() {
    setState(() {
      _attentionSuppressed = !_attentionSuppressed;
      // In a real lab, this would mock the attention engine. For now, it's UI state.
    });
  }
  
  void _toggleRestTimer() {
    setState(() {
      _restTimerActive = !_restTimerActive;
      _integrationEngine.updateTimerState(_restTimerActive);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: MitraBehaviourEngine(
                  key: _behaviourKey,
                  size: 160,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _triggerIdleNotice,
                child: const Text('TRIGGER IDLE NOTICE'),
              ),
              ElevatedButton(
                onPressed: _triggerChoreographedGrow,
                child: const Text('TRIGGER CHOREOGRAPHED GROW'),
              ),
              ElevatedButton(
                onPressed: _resetCooldowns,
                child: const Text('RESET COOLDOWNS'),
              ),
              ElevatedButton(
                onPressed: _toggleAttentionSuppression,
                child: Text(_attentionSuppressed ? 'RESUME ATTENTION' : 'SUPPRESS ATTENTION'),
              ),
              ElevatedButton(
                onPressed: _toggleRestTimer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _restTimerActive ? Colors.red.withOpacity(0.2) : null,
                ),
                child: Text(_restTimerActive ? 'REST TIMER ACTIVE' : 'SIMULATE REST TIMER ACTIVE'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MitraPhase28ChoreographyLabSection extends StatefulWidget {
  const _MitraPhase28ChoreographyLabSection();

  @override
  State<_MitraPhase28ChoreographyLabSection> createState() => _MitraPhase28ChoreographyLabSectionState();
}

class _MitraPhase28ChoreographyLabSectionState extends State<_MitraPhase28ChoreographyLabSection> {
  final GlobalKey<MitraBehaviourEngineState> _behaviourKey = GlobalKey<MitraBehaviourEngineState>();

  @override
  void initState() {
    super.initState();
  }

  void _triggerTransition(String transitionName) {
    if (_behaviourKey.currentState == null) return;
    
    final integrationEngine = MitraCinematicIntegrationEngine(
      interactionKey: _behaviourKey.currentState!.interactionKey,
      behaviourKey: _behaviourKey,
      onContextualEvent: (transition) {},
    );

    // Manually push a transition directly into the cinematic integration engine
    integrationEngine.onSunflowerTransition(MitraSunflowerAnimationTransition(
      name: transitionName,
      fromState: MitraSunflowerAnimationState.idle,
      toState: MitraSunflowerAnimationState.growing, // dummy states for test
      priority: MitraSunflowerAnimationPriority.growthTransition,
      duration: const Duration(milliseconds: 1500),
    ));
  }

  void _resetCooldowns() {
    _behaviourKey.currentState?.mitraContext.resetAllCooldowns();
    _behaviourKey.currentState?.interactionKey.currentState?.reset();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: MitraBehaviourEngine(
                  key: _behaviourKey,
                  size: 160,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => _triggerTransition('WAKE'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                child: const Text('WAKE REACTION'),
              ),
              ElevatedButton(
                onPressed: () => _triggerTransition('GROW'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800),
                child: const Text('GROW REACTION'),
              ),
              ElevatedButton(
                onPressed: () => _triggerTransition('FLOURISH'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
                child: const Text('FLOURISH REACTION'),
              ),
              ElevatedButton(
                onPressed: () => _triggerTransition('BLOOM'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800),
                child: const Text('BLOOM REACTION'),
              ),
              ElevatedButton(
                onPressed: () => _triggerTransition('EXCEPTIONAL_BLOOM'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pink.shade800),
                child: const Text('EXCEPTIONAL REACTION'),
              ),
              ElevatedButton(
                onPressed: _resetCooldowns,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                child: const Text('RESET STATE'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MitraPhase29DioramaLabSection extends ConsumerStatefulWidget {
  const _MitraPhase29DioramaLabSection();

  @override
  ConsumerState<_MitraPhase29DioramaLabSection> createState() => _MitraPhase29DioramaLabSectionState();
}

class _MitraPhase29DioramaLabSectionState extends ConsumerState<_MitraPhase29DioramaLabSection> {
  final GlobalKey<MitraBehaviourEngineState> _behaviourKey = GlobalKey<MitraBehaviourEngineState>();
  late final MitraSunflowerAnimationController _sunflowerController;
  double _normalizedMitraPosition = 0.5;
  
  @override
  void initState() {
    super.initState();
    _sunflowerController = MitraSunflowerAnimationController(
      onTransitionRequested: (transition) {
        setState(() {});
      }
    );
  }

  void _handleMitraAction(MitraBehaviourCategory category) {
    // Phase 42C: Intentionally blank, stationary
  }

  void _playAction(int actionId) {
    _behaviourKey.currentState?.interactionKey.currentState?.playIdleAction(actionId);
  }

  void _randomIdle() {
    _behaviourKey.currentState?.dispatch(MitraEvent(MitraEventType.navigationIdle));
  }

  void _forceSunflower(MitraSunflowerAnimationState state) {
    setState(() {
      _sunflowerController.forceState(state);
    });
  }
  
  void _triggerChoreography() {
    _sunflowerController.requestTransition(MitraSunflowerAnimationChoreography.wake, DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 300,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white24),
          ),
          child: const ClipRect(
            child: MitraCompanionOverlay(),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                ref.read(showMitraGroundProvider.notifier).state = !ref.read(showMitraGroundProvider);
              },
              style: ElevatedButton.styleFrom(backgroundColor: ref.watch(showMitraGroundProvider) ? Colors.blue : Colors.grey),
              child: const Text('SHOW GROUND'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(showMitraGroundPointProvider.notifier).state = !ref.read(showMitraGroundPointProvider);
              },
              style: ElevatedButton.styleFrom(backgroundColor: ref.watch(showMitraGroundPointProvider) ? Colors.blue : Colors.grey),
              child: const Text('SHOW MITRA GROUND POINT'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(showSunflowerGroundPointProvider.notifier).state = !ref.read(showSunflowerGroundPointProvider);
              },
              style: ElevatedButton.styleFrom(backgroundColor: ref.watch(showSunflowerGroundPointProvider) ? Colors.blue : Colors.grey),
              child: const Text('SHOW SUNFLOWER GROUND POINT'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(showMitraWorldBoundsProvider.notifier).state = !ref.read(showMitraWorldBoundsProvider);
              },
              style: ElevatedButton.styleFrom(backgroundColor: ref.watch(showMitraWorldBoundsProvider) ? Colors.blue : Colors.grey),
              child: const Text('SHOW WORLD BOUNDS'),
            ),
            ElevatedButton(
              onPressed: () {
                 _playAction(0); // arbitrary reset action or just force rebuild
              },
              child: const Text('RESET MITRA'),
            ),
            ElevatedButton(
              onPressed: () {
                 _sunflowerController.forceState(MitraSunflowerAnimationState.idle);
              },
              child: const Text('RESET SUNFLOWER'),
            ),
            ElevatedButton(
              onPressed: _randomIdle,
              child: const Text('SINGLE IDLE'),
            ),
          ],
        ),
      ],
    );
  }
}

