enum MitraAttentionLevel {
  none,
  background,
  available,
  focused,
  interrupted,
}

enum MitraOpportunityType {
  none,
  ambient,
  contextual,
  celebratory,
  social,
  returnToApp,
  milestone,
}

enum MitraInterruptionRisk {
  none,
  low,
  medium,
  high,
  critical,
}

enum MitraAttentionReason {
  userIsIdle,
  userIsBusy,
  activeWorkout,
  activeInput,
  navigationTransition,
  appBackgrounded,
  recentMitraReaction,
  highInterruptionRisk,
  meaningfulPause,
  naturalOpportunity,
  milestoneOpportunity,
  userReturned,
  suppressedByQuietPeriod,
  unknown,
}
