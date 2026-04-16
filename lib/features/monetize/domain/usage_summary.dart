class UsageSummary {
  const UsageSummary({
    required this.totalCount,
    required this.unsortedCount,
    required this.isPremium,
  });

  final int totalCount;
  final int unsortedCount;
  final bool isPremium;

  bool get reachedFreeLimit => !isPremium && totalCount >= 50;
  bool get shouldSuggestPc => !isPremium && unsortedCount >= 20;
}
