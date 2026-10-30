import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/env/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/home_shell.dart';
import '../data/auth_repository.dart';
import 'profile_setup_page.dart';

enum _LoginStep { phone, code }

/// Phone OTP sign-in: phone -> code -> home, or (new users) the profile
/// setup wizard, which creates the account after its gender + name steps.
///
/// The demo build uses a fixed code which is hinted on screen; a real SMS
/// gateway removes the hint without changing this flow.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  _LoginStep _step = _LoginStep.phone;
  String? _devCode;
  String? _error;
  bool _busy = false;

  String get _phone => '+63${_phoneController.text.trim()}';

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitPhone() async {
    final String digits = _phoneController.text.trim();
    if (digits.length < 9) {
      setState(() => _error = AppStrings.loginPhoneRequiredHint);
      return;
    }
    await _run(() async {
      _devCode = await widget.authRepository.requestOtp(_phone);
      setState(() => _step = _LoginStep.code);
    });
  }

  Future<void> _submitCode() async {
    await _run(() async {
      final AuthResult result = await widget.authRepository.verifyOtp(
        _phone,
        _codeController.text.trim(),
      );
      if (result.status == AuthStatus.loggedIn) {
        _goHome();
      } else {
        // New phone: the onboarding wizard collects gender + name and
        // registers the account itself, then fills in the profile.
        _goOnboarding(result.registrationToken!);
      }
    });
  }

  void _goOnboarding(String registrationToken) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => ProfileSetupPage(
          client: ApiClient(baseUrl: AppEnv.apiBaseUrl),
          authRepository: widget.authRepository,
          registrationToken: registrationToken,
        ),
      ),
      (_) => false,
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      setState(
        () => _error =
            e is AuthException ? e.message : AppStrings.errorGeneric,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 64),
              const Text(
                'Meeto',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                AppStrings.loginTagline,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 48),
              ..._stepFields(),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              _primaryButton(),
              if (_step == _LoginStep.code) ...<Widget>[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _step = _LoginStep.phone;
                              _codeController.clear();
                              _error = null;
                            }),
                    child: const Text(
                      AppStrings.loginChangeNumber,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _stepFields() {
    switch (_step) {
      case _LoginStep.phone:
        return <Widget>[
          const Text(
            AppStrings.loginSignInTitle,
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey<String>('loginPhoneField'),
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              prefixText: '+63 ',
              hintText: '9XX XXX XXXX',
            ),
          ),
        ];
      case _LoginStep.code:
        return <Widget>[
          Text(
            AppStrings.loginCodeSentTo(_phone),
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey<String>('otpCodeField'),
            controller: _codeController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration:
                const InputDecoration(hintText: AppStrings.loginCodeHint),
          ),
          if (_devCode != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AppStrings.loginDevCodeNote(_devCode!),
                style: const TextStyle(fontSize: 13, color: AppColors.accent),
              ),
            ),
          ],
        ];
    }
  }

  Widget _primaryButton() {
    final (String label, Future<void> Function() onTap, String keyName) =
        switch (_step) {
      _LoginStep.phone => (
          AppStrings.loginContinueCta,
          _submitPhone,
          'loginContinueButton'
        ),
      _LoginStep.code => (
          AppStrings.loginVerifyCta,
          _submitCode,
          'otpVerifyButton'
        ),
    };
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: ValueKey<String>(keyName),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.darkCard,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _busy ? null : onTap,
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onDarkPrimary,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
