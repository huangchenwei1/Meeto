/// Platform pricing configuration.
///
/// PRODUCT RULES (confirmed):
/// - The price buys the whole activity, not companionship: the platform
///   sets an activity budget per scene; posters cannot price.
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
    required this.sceneFees,
    required this.defaultFee,
  });

  factory PricingConfig.fromJson(Map<String, dynamic> json) {
    return PricingConfig(
      platformFeeRate: (json['platformFeeRate'] as num).toDouble(),
      sceneFees: (json['sceneFees'] as Map<String, dynamic>)
          .map((String key, dynamic value) => MapEntry(key, value as int)),
      defaultFee: json['defaultFee'] as int,
    );
  }

  /// Fallback used until the server config has loaded (and in tests).
  static const PricingConfig defaults = PricingConfig(
    platformFeeRate: 0.10,
    sceneFees: <String, int>{
      'Coffee': 1500,
      'Dinner': 4000,
      'Bar': 3500,
      'Movie': 2500,
      'Tea': 1800,
    },
    defaultFee: 2000,
  );

  /// Platform commission taken from the service fee on settlement (0..1).
  final double platformFeeRate;

  /// Platform-set service fee (whole pesos) per scene tag.
  final Map<String, int> sceneFees;

  /// Fee applied when a scene has no explicit entry.
  final int defaultFee;

  /// Display label derived from the rate, e.g. 0.10 -> "10%".
  String get platformFeeLabel => '${(platformFeeRate * 100).round()}%';

  int feeForScene(String scene) => sceneFees[scene] ?? defaultFee;

  /// What the host receives after the platform commission.
  int netEarnings(int fee) => (fee * (1 - platformFeeRate)).round();

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'platformFeeRate': platformFeeRate,
      'sceneFees': sceneFees,
      'defaultFee': defaultFee,
    };
  }
}
