import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mitra_debug_providers.dart';
import 'mitra_position_provider.dart';
import 'mitra_lighting_provider.dart';

import '../../providers/rest_timer_provider.dart';
import '../../theme/layout_insets.dart';

import '../sunflower/widgets/mitra_sunflower_widget.dart';
import '../mitra_behaviour_engine.dart';
import '../mitra_behaviour.dart';
import '../mitra_event.dart';
import '../sunflower/integration/mitra_cinematic_integration_engine.dart';
import '../sunflower/integration/mitra_sunflower_integration_provider.dart';
import '../sunflower/animation/mitra_sunflower_animation_controller.dart';
import '../sunflower/animation/mitra_sunflower_animation_transition.dart';

class MitraCompanionOverlay extends ConsumerStatefulWidget {
  final bool isHomeScreen;
  
  const MitraCompanionOverlay({
    super.key,
    this.isHomeScreen = true,
  });

  @override
  ConsumerState<MitraCompanionOverlay> createState() => _MitraCompanionOverlayState();
}

class _MitraCompanionOverlayState extends ConsumerState<MitraCompanionOverlay> with SingleTickerProviderStateMixin {
  final GlobalKey<MitraBehaviourEngineState> _behaviourKey = GlobalKey<MitraBehaviourEngineState>();
  late final MitraSunflowerAnimationController _sunflowerController;
  MitraCinematicIntegrationEngine? _integrationEngine;
  
  late final AnimationController _gravityController;
  late Animation<double> _gravityAnimation;

  @override
  void initState() {
    super.initState();
    _sunflowerController = MitraSunflowerAnimationController(
      onTransitionRequested: (transition) {
        _integrationEngine?.onSunflowerTransition(transition);
      },
    );
    
    _gravityController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _gravityAnimation = CurvedAnimation(parent: _gravityController, curve: Curves.bounceOut);
    
    _gravityController.addListener(() {
       ref.read(mitraGlobalYProvider.notifier).state = _gravityAnimation.value;
    });
    
    _gravityController.addStatusListener((status) {
       if (status == AnimationStatus.completed) {
         // Optionally trigger squash action here
         _behaviourKey.currentState?.interactionKey.currentState?.playIdleAction(1); // shuffle/squash
       }
    });

    // Initialize initial position based on route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mitraGlobalXProvider.notifier).state = widget.isHomeScreen ? 16.0 : -100.0;
    });
  }

  @override
  Timer? _offScreenTimer;

  @override
  void dispose() {
    _offScreenTimer?.cancel();
    _gravityController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MitraCompanionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isHomeScreen != widget.isHomeScreen) {
      _offScreenTimer?.cancel();
      
      if (!widget.isHomeScreen) {
        // Immediately move off-screen when leaving home
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(mitraGlobalXProvider.notifier).state = -100.0;
        });
        
        // Wait 10 seconds, then if still off-screen, trigger a pop-in
        _offScreenTimer = Timer(const Duration(seconds: 10), () {
          if (!widget.isHomeScreen) {
            _behaviourKey.currentState?.dispatch(MitraEvent(MitraEventType.navigationIdle));
          }
        });
      } else {
        // Returned to home
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(mitraGlobalXProvider.notifier).state = 16.0;
          _behaviourKey.currentState?.dispatch(MitraEvent(MitraEventType.userReturn));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Consume the canonical sunflower state.
    final state = ref.watch(canonicalSunflowerStateProvider);
    
    // 2. Consume progress signals for Mitra.
    final snapshot = ref.watch(sunflowerIntegrationProvider);

    // 3. Consume timer state for clearance.
    final timerState = ref.watch(restTimerProvider);

    // Initialize integration engine after behaviour engine is mounted
    if (_integrationEngine == null && _behaviourKey.currentState != null) {
      _integrationEngine = MitraCinematicIntegrationEngine(
        interactionKey: _behaviourKey.currentState!.interactionKey,
        behaviourKey: _behaviourKey,
        onContextualEvent: (MitraSunflowerAnimationTransition transition) {
          if (mounted) {
            setState(() {
              _sunflowerController.requestTransition(transition, DateTime.now());
            });
          }
        },
      );
    }

    // Provide signals to integration engine.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_integrationEngine == null && _behaviourKey.currentState != null) {
           _integrationEngine = MitraCinematicIntegrationEngine(
             interactionKey: _behaviourKey.currentState!.interactionKey,
             behaviourKey: _behaviourKey,
             onContextualEvent: (MitraSunflowerAnimationTransition transition) {
               if (mounted) {
                 setState(() {
                   _sunflowerController.requestTransition(transition, DateTime.now());
                 });
               }
             },
           );
        }
        
        _integrationEngine?.onProgressSignal(
          MitraSunflowerInteractionSignal(snapshot: snapshot),
        );
        
        // Process the Phase 17 raw state to apply Phase 20 Daily Latch protection
        setState(() {
          _sunflowerController.processPhase12Snapshot(state, DateTime.now());
          _sunflowerController.tick(DateTime.now());
        });
      }
    });

    final showGround = ref.watch(showMitraGroundProvider);
    final showMitraPoint = ref.watch(showMitraGroundPointProvider);
    final showSunflowerPoint = ref.watch(showSunflowerGroundPointProvider);
    final showWorldBounds = ref.watch(showMitraWorldBoundsProvider);

    return RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate the physical ground plane
            final bottomPadding = MediaQuery.paddingOf(context).bottom;
            // Nav bar is bottom: 12, height: 64
            final navBarTopOffset = bottomPadding + 12.0 + 64.0;
            final groundY = navBarTopOffset;

            // X-coordinates
            final double sunflowerWidth = 70.0;
            final double mitraWidth = 90.0;
            
            final double sunflowerX = constraints.maxWidth - sunflowerWidth - 32.0;
            
            // Read the dynamic global X and Y positions
            final double mitraX = ref.watch(mitraGlobalXProvider); 
            final double mitraY = ref.watch(mitraGlobalYProvider);
            final ColorFilter? lightingFilter = ref.watch(mitraLightingProvider);

            Widget content = Stack(
              alignment: Alignment.bottomLeft,
              clipBehavior: Clip.none,
              children: [
                // Debug World Bounds
                if (showWorldBounds)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    top: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 2),
                      ),
                    ),
                  ),

                // Debug Ground Line
                if (showGround)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: groundY,
                    child: Container(
                      height: 2,
                      color: Colors.cyanAccent,
                    ),
                  ),

                // 1. Sunflower (Static rooted on right)
                Positioned(
                  left: sunflowerX,
                  bottom: groundY,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // Sunflower Shadow
                      Positioned(
                        bottom: -4,
                        child: Container(
                          width: sunflowerWidth * 1.2,
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.12),
                                Colors.transparent,
                              ],
                              stops: const [0.3, 1.0],
                            ),
                          ),
                        ),
                      ),
                      widget.isHomeScreen ? MitraSunflowerWidget(
                        size: sunflowerWidth,
                        debugController: _sunflowerController,
                      ) : const SizedBox.shrink(),
                      // Debug Sunflower Ground Point
                      if (showSunflowerPoint)
                        Positioned(
                          bottom: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. Mitra
                Positioned(
                  left: mitraX - (mitraWidth / 2),
                  bottom: groundY + mitraY, // Lifted by gravity physics
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // Mitra Shadow (fades when lifted)
                      Positioned(
                        bottom: -2 - mitraY, // Shadow stays on ground
                        child: Opacity(
                          opacity: (1.0 - (mitraY / 200.0)).clamp(0.0, 1.0),
                          child: Container(
                            width: mitraWidth * 1.2,
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  Colors.black.withValues(alpha: 0.12),
                                  Colors.transparent,
                                ],
                                stops: const [0.3, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                           HapticFeedback.selectionClick();
                           _behaviourKey.currentState?.dispatch(MitraEvent(MitraEventType.manualInteraction));
                        },
                        onPanUpdate: (details) {
                           ref.read(mitraGlobalXProvider.notifier).state += details.delta.dx;
                           final currentY = ref.read(mitraGlobalYProvider);
                           double newY = currentY - details.delta.dy;
                           if (newY < 0) newY = 0;
                           ref.read(mitraGlobalYProvider.notifier).state = newY;
                           
                           if (_gravityController.isAnimating) {
                             _gravityController.stop();
                           }
                        },
                        onPanEnd: (details) {
                           final currentY = ref.read(mitraGlobalYProvider);
                           if (currentY > 0) {
                              _gravityAnimation = CurvedAnimation(parent: _gravityController, curve: Curves.bounceOut);
                              _gravityController.forward(from: 1.0 - (currentY / 300.0).clamp(0.0, 1.0)); 
                              final Tween<double> fallTween = Tween(begin: currentY, end: 0.0);
                              
                              _gravityController.duration = const Duration(milliseconds: 800);
                              _gravityController.reset();
                              
                              void fallListener() {
                                ref.read(mitraGlobalYProvider.notifier).state = fallTween.evaluate(_gravityAnimation);
                              }
                              _gravityController.addListener(fallListener);
                              _gravityController.addStatusListener((status) {
                                if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
                                  _gravityController.removeListener(fallListener);
                                  HapticFeedback.mediumImpact();
                                }
                              });
                              
                              _gravityController.forward();
                           }
                        },
                        child: MitraBehaviourEngine(
                          key: _behaviourKey,
                          size: mitraWidth,
                          isHomeScreen: widget.isHomeScreen,
                          onAction: _handleMitraAction,
                        ),
                      ),
                      // Debug Mitra Ground Point
                      if (showMitraPoint)
                        Positioned(
                          bottom: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
            
            if (lightingFilter != null) {
              content = ColorFiltered(
                colorFilter: lightingFilter,
                child: content,
              );
            }
            
            return content;
          },
        ),
    );
  }

  void _handleMitraAction(MitraBehaviourCategory category) {
    if (!mounted) return;
    
    if (category == MitraBehaviourCategory.popInLeft) {
       // Snap to off-screen left before action plays
       WidgetsBinding.instance.addPostFrameCallback((_) {
         ref.read(mitraGlobalXProvider.notifier).state = -40.0;
       });
    } else if (category == MitraBehaviourCategory.popInRight) {
       // Snap to off-screen right before action plays
       WidgetsBinding.instance.addPostFrameCallback((_) {
         ref.read(mitraGlobalXProvider.notifier).state = MediaQuery.sizeOf(context).width + 20.0;
       });
    }
    
    setState(() {});
  }
}
