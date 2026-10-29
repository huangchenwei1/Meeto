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

  static int feeForScene(String scene) => config.feeForScene(scene);

  /// What the female side receives after the platform commission.
  static int netEarnings(int fee) => config.netEarnings(fee);
}
