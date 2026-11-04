import 'package:flutter_test/flutter_test.dart';
import 'package:meeto/core/config/config_repository.dart';
import 'package:meeto/core/config/pricing_config.dart';
import 'package:meeto/core/constants/scene_pricing.dart';

void main() {
  group('PricingConfig', () {
    test('defaults carry the confirmed business rules', () {
      const PricingConfig config = PricingConfig.defaults;
      expect(config.platformFeeRate, 0.10);
      expect(config.platformFeeLabel, '10%');
      expect(config.tiersForScene('Dinner'), <int>[300, 400, 600]);
      expect(config.defaultBudgetForScene('Dinner'), 400);
      expect(
        config.tiersForScene('UnknownScene'),
        <int>[config.defaultFee],
      );
      expect(config.defaultBudgetForScene('UnknownScene'), config.defaultFee);
      expect(config.netEarnings(1000), 900);
    });

    test('rate changes propagate to settlement and display label', () {
      final PricingConfig original = ScenePricing.config;
      addTearDown(() => ScenePricing.config = original);

      // Simulates the platform tuning the commission via server config.
      ScenePricing.config = PricingConfig.fromJson(<String, dynamic>{
        'platformFeeRate': 0.15,
        'sceneBudgetTiers': <String, dynamic>{
          'Coffee': <dynamic>[500, 700, 900],
        },
        'defaultFee': 700,
      });

      expect(ScenePricing.platformFeeLabel, '15%');
      expect(ScenePricing.tiersForScene('Coffee'), <int>[500, 700, 900]);
      expect(ScenePricing.defaultBudgetForScene('Coffee'), 700);
      expect(ScenePricing.netEarnings(700), 595);
    });

    test('mock repository serves the default config', () async {
      final PricingConfig config =
          await MockConfigRepository().fetchPricingConfig();
      expect(config.toJson(), PricingConfig.defaults.toJson());
    });
  });
}
