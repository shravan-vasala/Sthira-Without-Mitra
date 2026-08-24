enum MitraSunflowerState {
  seed,
  sprout,
  youngPlant,
  growing,
  blooming,
  fullBloom,
  resting,
}

extension MitraSunflowerStateAsset on MitraSunflowerState {
  String get canonicalAssetPath {
    switch (this) {
      case MitraSunflowerState.seed:
        return 'assets/sunflower/SUNFLOWER_EARLY_CANONICAL.png';
      case MitraSunflowerState.sprout:
        return 'assets/sunflower/SUNFLOWER_FRESH_CANONICAL.png';
      case MitraSunflowerState.youngPlant:
        return 'assets/sunflower/SUNFLOWER_GROWING_CANONICAL.png';
      case MitraSunflowerState.growing:
        return 'assets/sunflower/SUNFLOWER_FLOURISHING_CANONICAL.png';
      case MitraSunflowerState.blooming:
        return 'assets/sunflower/SUNFLOWER_BLOOM_CANONICAL.png';
      case MitraSunflowerState.fullBloom:
        return 'assets/sunflower/SUNFLOWER_EXCEPTIONAL_BLOOM_CANONICAL.png';
      case MitraSunflowerState.resting:
        // Fallback for resting state as it's not explicitly in the 6-stage canonical progression
        return 'assets/sunflower/SUNFLOWER_EARLY_CANONICAL.png';
    }
  }
}
