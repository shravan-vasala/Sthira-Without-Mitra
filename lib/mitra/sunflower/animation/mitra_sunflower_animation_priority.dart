enum MitraSunflowerAnimationPriority {
  stillness(0),
  idle(1),
  smallProgress(2),
  growthTransition(3),
  bloom(4);

  final int value;
  const MitraSunflowerAnimationPriority(this.value);

  bool canInterrupt(MitraSunflowerAnimationPriority current) {
    return value > current.value;
  }
}
