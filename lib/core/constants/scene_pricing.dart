import '../config/pricing_config.dart';

/// Static access point to the active [PricingConfig].
///
/// Call sites read through these helpers so pricing stays adjustable at
/// runtime: `main()` loads the config at startup (server-driven in
/// production) and assigns it to [config].
abstract final class ScenePricing {
  /// Active config. Defaults apply until the loaded config is assigned.
  static PricingConfig config = PricingConfig.defaults;

  static double get platformFeeRate => config.platformFeeRate;

  /// Display label derived from the rate, e.g. "10%".
  static String get platformFeeLabel => config.platformFeeLabel;

  /// Scene tags that have platform pricing (the composer scene universe).
  static List<String> get scenes =>
      config.sceneBudgetTiers.keys.toList(growable: false);

  static List<int> tiersForScene(String scene) =>
      config.tiersForScene(scene);

  /// The default pick: the middle tier.
  static int defaultBudgetForScene(String scene) =>
      config.defaultBudgetForScene(scene);

  /// What the host receives after the platform commission.
  static int netEarnings(int fee) => config.netEarnings(fee);
}
