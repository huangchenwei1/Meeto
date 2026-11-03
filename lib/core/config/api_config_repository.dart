import '../network/api_client.dart';
import 'config_repository.dart';
import 'pricing_config.dart';

/// Loads platform pricing from the backend (GET /config/pricing) and maps
/// server units (centavos / basis points) to the client display units
/// (whole pesos / rate fraction).
class ApiConfigRepository implements ConfigRepository {
  ApiConfigRepository(this._client);

  final ApiClient _client;

  @override
  Future<PricingConfig> fetchPricingConfig() async {
    final Map<String, dynamic> json =
        await _client.get('/config/pricing') as Map<String, dynamic>;
    final Map<String, dynamic> tiers =
        json['sceneBudgetTiers'] as Map<String, dynamic>;
    return PricingConfig(
      platformFeeRate: (json['platformFeeRateBp'] as int) / 10000,
      defaultFee: minorToPesos(json['defaultFeeMinor'] as int),
      sceneBudgetTiers: tiers.map(
        (String scene, dynamic tierList) => MapEntry(
          scene,
          (tierList as List<dynamic>)
              .map((dynamic t) => minorToPesos(t as int))
              .toList(growable: false),
        ),
      ),
    );
  }
}
