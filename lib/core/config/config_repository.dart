import 'pricing_config.dart';

/// Data source contract for platform configuration.
///
/// To go live, implement it with a real API client (e.g. a
/// `GET /config/pricing` endpoint) and swap the instance used at startup —
/// no other code changes required.
abstract interface class ConfigRepository {
  Future<PricingConfig> fetchPricingConfig();
}

/// In-memory mock used for the demo build.
class MockConfigRepository implements ConfigRepository {
  @override
  Future<PricingConfig> fetchPricingConfig() async {
    // Simulated network latency.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return PricingConfig.defaults;
  }
}
