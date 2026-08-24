import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mitra/integration/mitra_position_provider.dart';

class MitraIdleEngine extends ConsumerStatefulWidget {
  final double size;

  const MitraIdleEngine({super.key, required this.size});

  @override
  ConsumerState<MitraIdleEngine> createState() => MitraIdleEngineState();
}

class MitraIdleEngineState extends ConsumerState<MitraIdleEngine> with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breatheAnimation;
  
  late AnimationController _actionController;

  Timer? _blinkTimer;
  bool _isBlinking = false;
  final Random _random = Random();
  bool _blinkAssetExists = true;

  int _currentAction = -1; // -1 means no action
  int _actionRunId = 0;
  bool _preloaded = false;

  // Anti-Jitter Anchor Map: (x, y) pixel offsets for every sprite frame
  static const Map<String, Offset> spriteAnchors = {
    'MITRA-Mit/WALK_CONTACT_LEFT.png': Offset(0, 0),
    'MITRA-Mit/WALK_DOWN_LEFT.png': Offset(0, 0),
    'MITRA-Mit/WALK_PASS_LEFT.png': Offset(0, 0),
    'MITRA-Mit/WALK_UP_LEFT.png': Offset(0, 0),
    'MITRA-Mit/WALK_CONTACT_RIGHT.png': Offset(0, 0),
    'MITRA-Mit/WALK_DOWN_RIGHT.png': Offset(0, 0),
    'MITRA-Mit/WALK_PASS_RIGHT.png': Offset(0, 0),
    'MITRA-Mit/WALK_UP_RIGHT.png': Offset(0, 0),
    'MITRA-Mit/action_notice.png': Offset(0, 0),
    'MITRA-Mit/action_proud.png': Offset(0, 0),
    'MITRA-Mit/action_touch.png': Offset(0, 0),
    'MITRA-Mit/action_bloom.png': Offset(0, 0),
    'MITRA-Mit/action_peek_anticipation.png': Offset(0, 0),
    'MITRA-Mit/action_peek.png': Offset(0, 0),
    'MITRA-Mit/action_peek_02.png': Offset(0, 0),
    'MITRA-Mit/action_peek_03.png': Offset(0, 0),
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_preloaded) {
      _preloaded = true;
      final assets = [
        'MITRA-Mit/WALK_CONTACT_LEFT.png',
        'MITRA-Mit/WALK_DOWN_LEFT.png',
        'MITRA-Mit/WALK_PASS_LEFT.png',
        'MITRA-Mit/WALK_UP_LEFT.png',
        'MITRA-Mit/WALK_CONTACT_RIGHT.png',
        'MITRA-Mit/WALK_DOWN_RIGHT.png',
        'MITRA-Mit/WALK_PASS_RIGHT.png',
        'MITRA-Mit/WALK_UP_RIGHT.png',
        'MITRA-Mit/action_notice.png',
        'MITRA-Mit/action_proud.png',
        'MITRA-Mit/action_touch.png',
        'MITRA-Mit/action_bloom.png',
        'MITRA-Mit/action_peek_anticipation.png',
        'MITRA-Mit/action_peek.png',
        'MITRA-Mit/action_peek_02.png',
        'MITRA-Mit/action_peek_03.png',
      ];
      for (final asset in assets) {
        precacheImage(AssetImage(asset), context);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _checkBlinkAsset();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Slow 4-second cycle
    );

    _breatheAnimation = CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOutSine,
    );

    _actionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    double lastT = 0.0;
    _actionController.addListener(() {
      final double t = _actionController.value;
      final double dt = t - lastT;
      
      if (_currentAction == 6 || _currentAction == 7) { // Walk Left / Right
        final bool isLeft = _currentAction == 6;
        
        // Anti-Moonwalk: We only move X while the foot is planted and pushing backwards 
        // in the sprite sequence (DOWN and PASS frames, t=0.35 to 0.65)
        bool isMoving = (t >= 0.35 && t <= 0.65);
        
        // Haptic footstep when foot hits the ground (CONTACT frame)
        if (lastT < 0.35 && t >= 0.35) HapticFeedback.lightImpact();
        
        if (isMoving && dt > 0) {
          // Move exactly 30 pixels per step, synced perfectly to the frames
          double deltaX = (30.0 / 0.30) * dt;
          if (isLeft) deltaX = -deltaX;
          
          ref.read(mitraGlobalXProvider.notifier).update((state) => state + deltaX);
        }
      } else if (_currentAction == 9) { // Peek / Say Hi
        final double peekT = _actionController.value;
        final double pDt = peekT - lastT;
        // 0.0 - 0.25: Walk left (-15px)
        // 0.80 - 1.0: Walk right (+15px)
        if (peekT <= 0.25 && pDt > 0) {
           ref.read(mitraGlobalXProvider.notifier).update((state) => state - (15.0 / 0.25) * pDt);
        } else if (peekT >= 0.80 && pDt > 0) {
           ref.read(mitraGlobalXProvider.notifier).update((state) => state + (15.0 / 0.20) * pDt);
        }
      } else if (_currentAction == 10 || _currentAction == 11) { // Pop-in Left or Right
        final bool isLeft = _currentAction == 10;
        
        bool isMoving = (t >= 0.1 && t <= 0.4) || (t >= 0.5 && t <= 0.8);
        if (isMoving && dt > 0) {
          double deltaX = (30.0 / 0.6) * dt;
          if (isLeft) deltaX = deltaX; // Walk right (inward from left)
          else deltaX = -deltaX; // Walk left (inward from right)
          
          ref.read(mitraGlobalXProvider.notifier).update((state) => state + deltaX);
        }
      }
      
      lastT = t;
    });

    _actionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        lastT = 0.0;
      }
    });

    // Continuous pendulum breathing
    _breathingController.repeat(reverse: true);

    _scheduleNextBlink();
  }
  
  Future<void> _checkBlinkAsset() async {
    try {
      await rootBundle.load('assets/mitra/canonical/mitra_blink.png');
      if (mounted) setState(() => _blinkAssetExists = true);
    } catch (_) {
      if (mounted) setState(() => _blinkAssetExists = false);
    }
  }

  void _scheduleNextBlink() {
    if (!mounted) return;
    
    // Decreased blink frequency (less dominant). Random between 8s and 15s.
    final int delayMs = 8000 + _random.nextInt(7000);
    _blinkTimer = Timer(Duration(milliseconds: delayMs), _executeBlink);
  }

  void _executeBlink() async {
    if (!mounted) return;

    final bool isActive = _breathingController.isAnimating;

    if (isActive && _blinkAssetExists && _currentAction == -1) {
      setState(() {
        _isBlinking = true;
      });

      final int blinkDuration = 120 + _random.nextInt(60);
      await Future.delayed(Duration(milliseconds: blinkDuration));
      
      if (mounted) {
        setState(() {
          _isBlinking = false;
        });
      }
    }

    _scheduleNextBlink();
  }

  Future<void> playAction(int actionId) async {
    if (!mounted) return;
    
    final int runId = ++_actionRunId;
    setState(() {
      _currentAction = actionId;
    });

    switch (actionId) {
      case 0: // dance
        _actionController.duration = const Duration(milliseconds: 1500);
        break;
      case 1: // shuffle
        _actionController.duration = const Duration(milliseconds: 900);
        break;
      case 2: // bounce
        _actionController.duration = const Duration(milliseconds: 700);
        break;
      case 3: // lean
        _actionController.duration = const Duration(milliseconds: 1100);
        break;
      case 4: // proud
        _actionController.duration = const Duration(milliseconds: 1200);
        break;
      case 5: // bloomCelebration
        _actionController.duration = const Duration(milliseconds: 1800);
        break;
      case 6: // walkLeft
      case 7: // walkRight
        _actionController.duration = const Duration(milliseconds: 500); // 4-frame fast step
        break;
      case 8: // noticeSunflower
        _actionController.duration = const Duration(milliseconds: 1200);
        break;
      case 9: // peekHi
        _actionController.duration = const Duration(milliseconds: 4000);
        break;
      default:
        _actionController.duration = const Duration(milliseconds: 1000);
    }

    await _actionController.forward(from: 0.0);
    
    if (!mounted || _actionRunId != runId) return;

    setState(() {
      _currentAction = -1;
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _breathingController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breathingController, _actionController]),
        builder: (context, child) {
          double dx = 0.0;
          double dy = 0.0;
          double rotate = 0.0;
          double scaleX = 1.0;
          double scaleY = 1.0;
          double skewX = 0.0; // New shear value for 2.5D momentum

          // Base Breathing: Constant subtle life
          final double breatheCycle = _breatheAnimation.value; 
          // Scale down vertically, scale up horizontally to keep volume constant
          // Anchor is bottomCenter, so this makes his head gently bob down
          final double breatheScaleY = 1.0 - (breatheCycle * 0.015);
          final double breatheScaleX = 1.0 + (breatheCycle * 0.005);
          
          scaleY *= breatheScaleY;
          scaleX *= breatheScaleX;

          // Action Choreography
          if (_currentAction != -1) {
            final double t = _actionController.value;

            switch (_currentAction) {
              case 0: // Dance: anticipation -> left weight -> right weight -> bounce & recovery
                if (t < 0.1) {
                   double squash = 0.02 * sin(t / 0.1 * pi);
                   scaleY *= (1.0 - squash);
                   scaleX *= (1.0 + squash);
                } else if (t < 0.4) {
                   double phase = (t - 0.1) / 0.3;
                   rotate = -0.06 * Curves.easeOutBack.transform(phase);
                   dy -= widget.size * 0.02 * sin(phase * pi);
                } else if (t < 0.7) {
                   double phase = (t - 0.4) / 0.3;
                   rotate = 0.06 * Curves.easeOutBack.transform(phase);
                   dy -= widget.size * 0.02 * sin(phase * pi);
                } else {
                   double phase = (t - 0.7) / 0.3;
                   dy -= widget.size * 0.08 * sin(phase * pi);
                   double squash = 0.03 * sin(phase * pi);
                   scaleY *= (1.0 - squash);
                   scaleX *= (1.0 + squash * 0.5);
                   rotate = 0.06 * (1.0 - phase);
                }
                break;
                
              case 1: // Shuffle
                // Removed dx
                break;

              case 2: // Bounce: squat -> hop -> land compression
                if (t < 0.3) {
                  double squash = 0.05 * sin(t / 0.3 * pi);
                  scaleY *= (1.0 - squash);
                  scaleX *= (1.0 + squash);
                } else if (t < 0.7) {
                  dy -= widget.size * 0.1 * sin((t - 0.3) / 0.4 * pi);
                  scaleY *= 1.02; // stretch up
                  scaleX *= 0.98;
                } else {
                  double squash = 0.06 * sin((t - 0.7) / 0.3 * pi);
                  scaleY *= (1.0 - squash);
                  scaleX *= (1.0 + squash * 0.8);
                }
                break;

              case 3: // Goofy Lean: shift weight and rotate
                final leanCurve = Curves.elasticOut.transform(t);
                rotate = 0.12 * leanCurve * (t < 0.8 ? 1.0 : (1.0 - (t - 0.8) / 0.2));
                // Removed dx
                if (t < 0.8) {
                   double squash = 0.01 * leanCurve;
                   scaleY *= (1.0 - squash);
                   scaleX *= (1.0 + squash);
                }
                break;

              case 4: // Proud: slow lift chest -> hold -> settle
                if (t < 0.4) {
                  double phase = t / 0.4;
                  rotate = -0.04 * Curves.easeOutCubic.transform(phase);
                  dy -= widget.size * 0.02 * Curves.easeOutCubic.transform(phase);
                } else if (t < 0.8) {
                  rotate = -0.04;
                  dy -= widget.size * 0.02;
                } else {
                  double phase = (t - 0.8) / 0.2;
                  rotate = -0.04 * (1.0 - phase);
                  dy -= widget.size * 0.02 * (1.0 - phase);
                }
                break;

              case 5: // Bloom Celebration
                if (t < 0.2) {
                  dy -= widget.size * 0.1 * sin(t / 0.2 * pi);
                } else if (t < 0.5) {
                  rotate = 0.08 * sin((t - 0.2) / 0.3 * pi);
                } else if (t < 0.8) {
                  rotate = -0.08 * sin((t - 0.5) / 0.3 * pi);
                } else {
                  dy -= widget.size * 0.05 * sin((t - 0.8) / 0.2 * pi);
                }
                break;
                
              case 6: // Walk Left
              case 7: // Walk Right
                // The new Sprite Engine handles its own limb movement and weight transfer!
                // We only need a tiny bit of momentum settling at the very end of the animation loop.
                if (t >= 0.8) {
                  // Settle with elastic follow-through
                  double phase = (t - 0.8) / 0.2;
                  double settleProgress = Curves.easeOutBack.transform(phase);
                  double squash = 0.02 * (1.0 - settleProgress);
                  scaleY *= (1.0 - squash);
                  scaleX *= (1.0 + squash * 0.5);
                }
                break;
                
              case 9: // Peek / Say Hi (4000ms total)
                if (t < 0.25) {
                  // 0-1000ms: Walking left (offscreen)
                  double walkT = t / 0.25;
                  int steps = 2;
                  dy -= widget.size * 0.05 * sin(walkT * steps * pi);
                  rotate = -0.04 * sin(walkT * steps * 2 * pi);
                  dx -= widget.size * walkT; 
                } else if (t < 0.40) {
                  // 1000-1600ms: Settle offscreen
                  dx -= widget.size;
                } else if (t < 0.525) {
                  // 1600-2100ms: Pause offscreen
                  dx -= widget.size;
                } else if (t < 0.675) {
                  // 2100-2700ms: Peek back (pop in from the edge)
                  double peekT = (t - 0.525) / 0.15;
                  double easeIn = Curves.easeOutBack.transform(peekT);
                  dx -= widget.size * (1.0 - 0.6 * easeIn);
                  rotate = 0.08 * easeIn;
                } else if (t < 0.80) {
                  // 2700-3200ms: Wave / goofy greeting while peeking
                  dx -= widget.size * 0.4;
                  rotate = 0.08;
                  double waveT = (t - 0.675) / 0.125;
                  dy -= widget.size * 0.08 * sin(waveT * 2 * pi); // Tiny bounces
                  scaleY *= (1.0 + (0.04 * sin(waveT * 2 * pi)));
                } else {
                  // 3200-4000ms: Walk back right (to original pos)
                  double walkT = (t - 0.80) / 0.20;
                  int steps = 2;
                  dy -= widget.size * 0.05 * sin(walkT * steps * pi);
                  rotate = 0.04 * sin(walkT * steps * 2 * pi);
                  dx -= widget.size * 0.4 * (1.0 - walkT);
                }
                break;

              case 10: // Pop-in Left
              case 11: // Pop-in Right
                // Same visual leg movement as Walk, but mapped to 10 (walk right) and 11 (walk left)
                final bool isWalkLeft = _currentAction == 11;
                if (t < 0.1) {
                  double squash = 0.02 * sin(t / 0.1 * pi);
                  scaleY *= (1.0 - squash);
                  scaleX *= (1.0 + squash);
                  rotate = (isWalkLeft ? 0.02 : -0.02) * sin(t / 0.1 * pi);
                } else if (t < 0.4) {
                  double stepT = (t - 0.1) / 0.3;
                  dy -= widget.size * 0.06 * sin(stepT * pi);
                  rotate = (isWalkLeft ? -0.04 : 0.04) * sin(stepT * pi);
                } else if (t < 0.5) {
                  double compressT = (t - 0.4) / 0.1;
                  double squash = 0.03 * sin(compressT * pi);
                  scaleY *= (1.0 - squash);
                  scaleX *= (1.0 + squash * 0.8);
                } else if (t < 0.8) {
                  double stepT = (t - 0.5) / 0.3;
                  dy -= widget.size * 0.06 * sin(stepT * pi);
                  rotate = (isWalkLeft ? -0.04 : 0.04) * sin(stepT * pi);
                } else {
                  double settleT = (t - 0.8) / 0.2;
                  double squash = 0.02 * sin(settleT * pi);
                  scaleY *= (1.0 - squash);
                  scaleX *= (1.0 + squash * 0.5);
                }
                break;
                
              case 8: // Notice Sunflower (Lean right and look)
                if (t < 0.3) {
                  rotate = 0.05 * Curves.easeOut.transform(t / 0.3);
                  // Removed dx
                } else if (t < 0.7) {
                  rotate = 0.05;
                  // Removed dx
                  scaleY *= (1.0 + (0.02 * sin((t - 0.3) / 0.4 * pi))); // slight interest
                } else {
                  rotate = 0.05 * (1.0 - Curves.easeIn.transform((t - 0.7) / 0.3));
                  // Removed dx
                }
                break;
                
              case 12: // Play With Sunflower
                if (t < 0.2) {
                  // Anticipation squash
                  double phase = t / 0.2;
                  scaleY *= (1.0 - (0.05 * phase));
                  scaleX *= (1.0 + (0.05 * phase));
                  dy += widget.size * 0.02 * phase;
                } else if (t < 0.4) {
                  // Stretch up to look
                  double phase = (t - 0.2) / 0.2;
                  scaleY *= (0.95 + (0.10 * phase)); // from 0.95 to 1.05
                  scaleX *= (1.05 - (0.10 * phase)); // from 1.05 to 0.95
                  dy -= widget.size * 0.04 * phase;
                  rotate = 0.06 * phase;
                } else if (t < 0.7) {
                  // Happy wiggles (bounce)
                  double phase = (t - 0.4) / 0.3;
                  scaleY *= 1.05;
                  scaleX *= 0.95;
                  dy -= widget.size * 0.04;
                  rotate = 0.06 + (0.04 * sin(phase * 4 * pi));
                } else {
                  // Settle
                  double phase = (t - 0.7) / 0.3;
                  scaleY *= (1.05 - (0.05 * phase));
                  scaleX *= (0.95 + (0.05 * phase));
                  dy -= widget.size * 0.04 * (1.0 - phase);
                  rotate = 0.06 * (1.0 - phase);
                }
                break;
                
              case 13: // Mischief (Somersault / spin)
                if (t < 0.2) {
                  // Wind up
                  double phase = t / 0.2;
                  rotate = -0.15 * phase;
                  scaleY *= (1.0 - (0.05 * phase));
                  scaleX *= (1.0 + (0.05 * phase));
                } else if (t < 0.6) {
                  // Spin!
                  double phase = (t - 0.2) / 0.4;
                  // Full rotation + initial windup
                  rotate = -0.15 + (2 * pi * phase);
                  dy -= widget.size * 0.15 * sin(phase * pi); // jump up
                } else if (t < 0.8) {
                  // Land and squash
                  double phase = (t - 0.6) / 0.2;
                  rotate = 0.0;
                  scaleY *= (1.0 - (0.1 * sin(phase * pi)));
                  scaleX *= (1.0 + (0.1 * sin(phase * pi)));
                } else {
                  // Settle
                  rotate = 0.0;
                }
                break;
            }
          }

          String currentAsset = 'assets/mitra/canonical/mitra_ideal.png';
          
          if (_currentAction != -1) {
            final double t = _actionController.value;
            
            if (_currentAction == 6) { // Walk Left (8 frames mapped to 4)
               if (t < 0.35) currentAsset = 'MITRA-Mit/WALK_CONTACT_LEFT.png';
               else if (t < 0.50) currentAsset = 'MITRA-Mit/WALK_DOWN_LEFT.png';
               else if (t < 0.65) currentAsset = 'MITRA-Mit/WALK_PASS_LEFT.png';
               else currentAsset = 'MITRA-Mit/WALK_UP_LEFT.png';
            } else if (_currentAction == 7) { // Walk Right (8 frames mapped to 4)
               if (t < 0.35) currentAsset = 'MITRA-Mit/WALK_CONTACT_RIGHT.png';
               else if (t < 0.50) currentAsset = 'MITRA-Mit/WALK_DOWN_RIGHT.png';
               else if (t < 0.65) currentAsset = 'MITRA-Mit/WALK_PASS_RIGHT.png';
               else currentAsset = 'MITRA-Mit/WALK_UP_RIGHT.png';
            } else if (_currentAction == 9) { // Peek
               if (t > 0.0 && t <= 0.25) {
                 if (t < 0.125) currentAsset = 'MITRA-Mit/WALK_CONTACT_LEFT.png';
                 else currentAsset = 'MITRA-Mit/WALK_PASS_LEFT.png';
               } else if (t > 0.525 && t <= 0.60) {
                 currentAsset = 'MITRA-Mit/action_peek_anticipation.png';
               } else if (t > 0.60 && t <= 0.675) {
                 currentAsset = 'MITRA-Mit/action_peek.png';
               } else if (t > 0.675 && t <= 0.80) {
                 if ((t - 0.675) % 0.0625 < 0.03125) currentAsset = 'MITRA-Mit/action_peek_02.png';
                 else currentAsset = 'MITRA-Mit/action_peek_03.png';
               } else if (t > 0.80) {
                 if (t < 0.90) currentAsset = 'MITRA-Mit/WALK_CONTACT_RIGHT.png';
                 else currentAsset = 'MITRA-Mit/WALK_PASS_RIGHT.png';
               }
            } else if (_currentAction == 8) { // Notice
               currentAsset = 'MITRA-Mit/action_notice.png';
            } else if (_currentAction == 4) { // Proud
               currentAsset = 'MITRA-Mit/action_proud.png';
            } else if (_currentAction == 12) { // Play/Touch
               currentAsset = 'MITRA-Mit/action_touch.png';
            } else if (_currentAction == 5) { // Bloom
               currentAsset = 'MITRA-Mit/action_bloom.png';
            } else if (_currentAction == 0) { // Dance
               if (t > 0.1 && t <= 0.4) currentAsset = 'MITRA-Mit/WALK_CONTACT_LEFT.png';
               else if (t > 0.5 && t <= 0.8) currentAsset = 'MITRA-Mit/WALK_CONTACT_RIGHT.png';
            }
          }

          Offset anchorOffset = spriteAnchors[currentAsset] ?? Offset.zero;

          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..translate(dx + anchorOffset.dx, dy + anchorOffset.dy)
              ..multiply(Matrix4.skewX(skewX))
              ..rotateZ(rotate)
              ..scale(scaleX, scaleY),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  currentAsset,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                ),
                
                // BLINK overlay (conditionally rendered)
                if (_isBlinking && _blinkAssetExists && _currentAction == -1)
                  Image.asset(
                    'assets/mitra/canonical/mitra_blink.png',
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
