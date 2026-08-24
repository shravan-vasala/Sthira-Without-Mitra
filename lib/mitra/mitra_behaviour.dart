enum MitraBehaviourCategory {
  idle,
  peek,
  mischief,
  sunflower,
  achievement,
  notice,
  dance,
  shuffle,
  bounce,
  lean,
  proud,
  bloomCelebration,
  walkLeft,
  walkRight,
  noticeSunflower,
  peekHi,
  popInLeft,
  popInRight,
}

enum MitraBehaviourState {
  idle,
  evaluating,
  playing,
  cooldown
}

enum MitraBehaviourPriority {
  idle(0),
  opportunistic(1),
  contextual(2),
  achievement(3),
  critical(4);

  final int value;
  const MitraBehaviourPriority(this.value);
}
