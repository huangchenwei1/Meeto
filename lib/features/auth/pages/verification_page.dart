import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/env/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import 'profile_setup_page.dart';

/// Real-person verification (API mode): a liveness selfie is matched
/// against the profile photo, so the avatar is shown as the reference and
/// no extra photo upload is asked from the user conceptually. MOCK NOTES:
/// the simulator has no camera, so the "liveness capture" picks from the
/// gallery, and the server-side comparison always passes; a real KYC
/// vendor SDK replaces both on device.
class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

/// Shows the "verification required" dialog and, if accepted, runs the
/// verification flow. Returns true when the user ends up verified.
Future<bool> promptVerification(BuildContext context) async {
  final bool? goVerify = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text(AppStrings.verifyDialogTitle),
      content: const Text(AppStrings.verifyDialogBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(AppStrings.verifyLater),
        ),
        FilledButton(
          key: const ValueKey<String>('verifyNowButton'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(AppStrings.verifyNow),
        ),
      ],
    ),
  );
  if (goVerify != true || !context.mounted) {
    return false;
  }
  final bool? verified = await Navigator.of(context).push(
    MaterialPageRoute<bool>(builder: (_) => const VerificationPage()),
  );
  return verified ?? false;
}

class _VerificationPageState extends State<VerificationPage> {
  final ImagePicker _picker = ImagePicker();
  final ApiClient _client = ApiClient(baseUrl: AppEnv.apiBaseUrl);

  String _avatarUrl = '';
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final Map<String, dynamic> user =
          await _client.get('/users/me') as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _avatarUrl = user['avatarUrl'] as String? ?? '';
          _loading = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _goSetAvatar() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileSetupPage(client: _client, isEditing: true),
      ),
    );
    if (mounted) {
      setState(() => _loading = true);
      await _loadAvatar();
    }
  }

  /// MOCK liveness capture: picks a gallery image in place of the real
  /// camera-based liveness check (the simulator has no camera).
  Future<void> _startVerification() async {
    final XFile? captured = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1440,
      imageQuality: 85,
    );
    if (captured == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final String selfieUrl = await _client.uploadImage(
        await captured.readAsBytes(),
        captured.name,
      );
      await _client.post('/verification', body: <String, dynamic>{
        'selfieUrl': selfieUrl,
      });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.verifySuccess)),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.setupUploadFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAvatar = _avatarUrl.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.verifyTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              children: <Widget>[
                const Icon(
                  Iconsax.security_user,
                  size: 56,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(height: 18),
                const Text(
                  AppStrings.verifySub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                if (hasAvatar) ...<Widget>[
                  Center(
                    child: Column(
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            resolveMediaUrl(_avatarUrl),
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          AppStrings.verifyYourPhoto,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey<String>('verifyStartButton'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.darkCard,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _busy ? null : _startVerification,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onDarkPrimary,
                              ),
                            )
                          : const Text(
                              AppStrings.verifyStart,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ] else ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      AppStrings.verifyNoAvatar,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey<String>('verifySetAvatarButton'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.darkCard,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _goSetAvatar,
                      child: const Text(
                        AppStrings.verifyGoSetAvatar,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
