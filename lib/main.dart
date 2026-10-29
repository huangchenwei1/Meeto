import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/api_config_repository.dart';
import 'core/config/config_repository.dart';
import 'core/config/pricing_config.dart';
import 'core/constants/scene_pricing.dart';
import 'core/env/app_env.dart';
import 'core/network/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pricing (commission rate, per-scene fees) is platform-controlled and
  // loaded before the first frame so every screen renders consistent money.
  final ConfigRepository configRepository = AppEnv.useRemoteApi
      ? ApiConfigRepository(ApiClient(baseUrl: AppEnv.apiBaseUrl))
      : MockConfigRepository();
  try {
    ScenePricing.config = await configRepository.fetchPricingConfig();
  } on Exception {
    // Server unreachable at launch: fall back to bundled defaults so the
    // app still renders instead of dying on a white screen.
    ScenePricing.config = PricingConfig.defaults;
  }
  runApp(const MeetoApp());
}
