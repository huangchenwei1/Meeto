/// Platform pricing configuration.
///
/// PRODUCT RULES (confirmed):
/// - The price buys the whole activity, not companionship: the platform
///   defines budget tiers per scene and the poster picks one; free
///   pricing is never allowed.
/// - The host covers the activity costs (food, drinks, tickets) out of the
///   budget and keeps the remainder as hosting income.
/// - The poster always pays the budget; signing up as a host is free.
/// - Payment is held in escrow by the platform and settled to the host
///   after the activity completes, minus [platformFeeRate].
/// - Cancellation refunds the full amount.
///
/// Both the commission rate and the per-scene fees are server-driven so the
/// platform can tune them without shipping a new app build.
class PricingConfig {
  const PricingConfig({
    required this.platformFeeRate,
    required this.sceneBudgetTiers,
    required this.defaultFee,
  });

  factory PricingConfig.fromJson(Map<String, dynamic> json) {
    return PricingConfig(
      platformFeeRate: (json['platformFeeRate'] as num).toDouble(),
      sceneBudgetTiers: (json['sceneBudgetTiers'] as Map<String, dynamic>)
          .map(
        (String key, dynamic value) => MapEntry(
          key,
          (value as List<dynamic>).cast<int>(),
        ),
      ),
      defaultFee: json['defaultFee'] as int,
    );
  }

  /// Fallback used until the server config has loaded (and in tests).
  static const PricingConfig defaults = PricingConfig(
    platformFeeRate: 0.10,
    sceneBudgetTiers: <String, List<int>>{
      'Coffee': <int>[100, 150, 250],
      'Tea': <int>[120, 180, 280],
      'Movie': <int>[180, 250, 350],
      'Bar': <int>[250, 350, 500],
      'Dinner': <int>[300, 400, 600],
    },
    defaultFee: 200,
  );

  /// Platform commission taken from the service fee on settlement (0..1).
  final double platformFeeRate;

  /// Platform-defined activity budget tiers (whole pesos, ascending) per
  /// scene tag; the poster picks one.
  final Map<String, List<int>> sceneBudgetTiers;

  /// Single-tier fallback when a scene has no explicit tier list.
  final int defaultFee;

  /// Display label derived from the rate, e.g. 0.10 -> "10%".
  String get platformFeeLabel => '${(platformFeeRate * 100).round()}%';

  List<int> tiersForScene(String scene) =>
      sceneBudgetTiers[scene] ?? <int>[defaultFee];

  /// The default pick: the middle tier.
  int defaultBudgetForScene(String scene) {
    final List<int> tiers = tiersForScene(scene);
    return tiers[(tiers.length - 1) ~/ 2];
  }

  /// What the host receives after the platform commission.
  int netEarnings(int fee) => (fee * (1 - platformFeeRate)).round();

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'platformFeeRate': platformFeeRate,
      'sceneBudgetTiers': sceneBudgetTiers,
      'defaultFee': defaultFee,
    };
  }
}
