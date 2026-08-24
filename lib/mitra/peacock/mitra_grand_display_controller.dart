import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'mitra_peacock_manifest.dart';

class MitraGrandDisplayController extends ChangeNotifier {
  PeacockGrandDisplayState _currentState = PeacockGrandDisplayState.ready;
  int _frameIndex = 0;
  Timer? _timer;
  bool _isPlaying = false;
  
  final List<MitraPeacockFrame> _currentIdleSequence = [];
  
  PeacockGrandDisplayState get currentState => _currentState;
  bool get isPlaying => _isPlaying;

  MitraPeacockFrame get currentFrame {
    switch (_currentState) {
      case PeacockGrandDisplayState.ready:
        return MitraPeacockManifest.openingSequence.first;
      case PeacockGrandDisplayState.opening:
        return MitraPeacockManifest.openingSequence[_frameIndex];
      case PeacockGrandDisplayState.settle:
        return MitraPeacockManifest.settleSequence[_frameIndex];
      case PeacockGrandDisplayState.idle:
        return _currentIdleSequence[_frameIndex];
      case PeacockGrandDisplayState.closing:
        return MitraPeacockManifest.closingSequence[_frameIndex];
    }
  }

  void play() {
    if (_isPlaying) return; // Ignore duplicate triggers
    _isPlaying = true;
    _startOpening();
  }

  void interrupt() {
    _timer?.cancel();
    _currentState = PeacockGrandDisplayState.ready;
    _frameIndex = 0;
    _isPlaying = false;
    notifyListeners();
  }

  void _startOpening() {
    _currentState = PeacockGrandDisplayState.opening;
    _frameIndex = 0;
    _playNextFrame();
  }

  void _playNextFrame() {
    notifyListeners();
    
    final frame = currentFrame;
    _timer?.cancel();
    _timer = Timer(frame.duration, _onFrameComplete);
  }

  void _generateIdleSequence() {
    _currentIdleSequence.clear();
    
    // Always start with HERO
    _currentIdleSequence.add(MitraPeacockManifest.heroFrame);
    
    // Deterministic subtle scheduler
    final random = math.Random();
    
    // Number of behaviors: mostly 1, sometimes 2, rarely 0.
    final numBehaviorsRoll = random.nextDouble();
    int numBehaviors = 1;
    if (numBehaviorsRoll < 0.1) {
      numBehaviors = 0;
    } else if (numBehaviorsRoll < 0.4) {
      numBehaviors = 2;
    }

    for (int i = 0; i < numBehaviors; i++) {
      final r = random.nextDouble();
      MitraPeacockFrame actionFrame;
      
      // Common: BLINK (60%)
      // Occasional: LOOK_LEFT, LOOK_RIGHT (15% each)
      // Rare: WINK, LOOK_UP, LOOK_DOWN (total 10%)
      if (r < 0.60) {
        actionFrame = MitraPeacockManifest.blinkFrame;
      } else if (r < 0.75) {
        actionFrame = MitraPeacockManifest.lookLeftFrame;
      } else if (r < 0.90) {
        actionFrame = MitraPeacockManifest.lookRightFrame;
      } else if (r < 0.94) {
        actionFrame = MitraPeacockManifest.winkFrame;
      } else if (r < 0.97) {
        actionFrame = MitraPeacockManifest.lookUpFrame;
      } else {
        actionFrame = MitraPeacockManifest.lookDownFrame;
      }
      
      _currentIdleSequence.add(actionFrame);
      _currentIdleSequence.add(MitraPeacockManifest.heroFrame);
    }
  }

  void _onFrameComplete() {
    switch (_currentState) {
      case PeacockGrandDisplayState.opening:
        if (_frameIndex < MitraPeacockManifest.openingSequence.length - 1) {
          _frameIndex++;
          _playNextFrame();
        } else {
          _currentState = PeacockGrandDisplayState.settle;
          _frameIndex = 0;
          _playNextFrame();
        }
        break;
      case PeacockGrandDisplayState.settle:
        if (_frameIndex < MitraPeacockManifest.settleSequence.length - 1) {
          _frameIndex++;
          _playNextFrame();
        } else {
          _generateIdleSequence();
          _currentState = PeacockGrandDisplayState.idle;
          _frameIndex = 0;
          _playNextFrame();
        }
        break;
      case PeacockGrandDisplayState.idle:
        if (_frameIndex < _currentIdleSequence.length - 1) {
          _frameIndex++;
          _playNextFrame();
        } else {
          _currentState = PeacockGrandDisplayState.closing;
          _frameIndex = 0;
          _playNextFrame();
        }
        break;
      case PeacockGrandDisplayState.closing:
        if (_frameIndex < MitraPeacockManifest.closingSequence.length - 1) {
          _frameIndex++;
          _playNextFrame();
        } else {
          // Finished!
          _currentState = PeacockGrandDisplayState.ready;
          _frameIndex = 0;
          _isPlaying = false;
          notifyListeners();
        }
        break;
      case PeacockGrandDisplayState.ready:
        // Do nothing
        break;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
