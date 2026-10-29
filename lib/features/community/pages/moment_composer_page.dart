import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/env/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/pages/verification_page.dart';
import '../data/community_repository.dart';

/// Composer for a community recap (moment): short text + up to 3 photos.
class MomentComposerPage extends StatefulWidget {
  const MomentComposerPage({super.key, required this.repository});

  final CommunityRepository repository;

  @override
  State<MomentComposerPage> createState() => _MomentComposerPageState();
}

class _MomentComposerPageState extends State<MomentComposerPage> {
  static const int _maxPhotos = 3;

  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<String> _photoUrls = <String>[];
  bool _busy = false;

  /// Photo upload needs the API; mock mode posts text-only moments.
  bool get _photosEnabled => AppEnv.useRemoteApi;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final ApiClient client = ApiClient(baseUrl: AppEnv.apiBaseUrl);
      final String url =
          await client.uploadImage(await picked.readAsBytes(), picked.name);
      if (mounted) {
        setState(() => _photoUrls.add(url));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.momentPhotoFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submit() async {
    final String text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.momentTextRequiredHint)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.createMoment(text, _photoUrls);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      if (e.verificationRequired) {
        final bool verified = await promptVerification(context);
        if (verified && mounted) {
          return _submit();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } on Exception {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.momentComposerTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('momentTextField'),
            controller: _textController,
            maxLength: 600,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: AppStrings.momentTextHint,
            ),
          ),
          if (_photosEnabled) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                for (final String url in _photoUrls)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      resolveMediaUrl(url),
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (_photoUrls.length < _maxPhotos)
                  InkWell(
                    key: const ValueKey<String>('momentAddPhoto'),
                    onTap: _busy ? null : _addPhoto,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Iconsax.gallery_add,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: FilledButton(
            key: const ValueKey<String>('momentSubmitButton'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.onDarkPrimary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: _busy ? null : _submit,
            child: const Text(AppStrings.momentPostCta),
          ),
        ),
      ),
    );
  }
}
