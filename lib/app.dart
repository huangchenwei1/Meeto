import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository_factory.dart';
import 'features/auth/pages/login_page.dart';

class MeetoApp extends StatelessWidget {
  const MeetoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: LoginPage(authRepository: createAuthRepository()),
    );
  }
}
