enum MitraSunflowerAnimationState {
  idle,
  waking,
  growing,
  flourishing,
  blooming,
  exceptionalBlooming,
  settling,
  resting,
  resetting
}

extension MitraSunflowerAnimationStateAsset on MitraSunflowerAnimationState {
  String get canonicalAssetPath {
    switch (this) {
      case MitraSunflowerAnimationState.idle:
      case MitraSunflowerAnimationState.resting:
      case MitraSunflowerAnimationState.resetting:
        return 'assets/sunflower/SUNFLOWER_EARLY_CANONICAL.png';
      case MitraSunflowerAnimationState.waking:
        return 'assets/sunflower/SUNFLOWER_FRESH_CANONICAL.png';
      case MitraSunflowerAnimationState.growing:
        return 'assets/sunflower/SUNFLOWER_GROWING_CANONICAL.png';
      case MitraSunflowerAnimationState.flourishing:
        return 'assets/sunflower/SUNFLOWER_FLOURISHING_CANONICAL.png';
      case MitraSunflowerAnimationState.blooming:
        return 'assets/sunflower/SUNFLOWER_BLOOM_CANONICAL.png';
      case MitraSunflowerAnimationState.exceptionalBlooming:
        return 'assets/sunflower/SUNFLOWER_EXCEPTIONAL_BLOOM_CANONICAL.png';
      case MitraSunflowerAnimationState.settling:
        return 'assets/sunflower/SUNFLOWER_EARLY_CANONICAL.png';
    }
  }
}
