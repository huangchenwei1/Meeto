import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/env/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/pages/verification_page.dart';
import '../data/hosts_repository.dart';

/// Host-side composer for an activity pitch: one loose idea line plus the
/// scene it belongs to (which drives the platform fee shown to users).
/// Deliberately minimal — no time or place; those come later through the
/// standard order plan flow.
class ProposalComposerPage extends StatefulWidget {
  const ProposalComposerPage({
    super.key,
    required this.repository,
    required this.offeredScenes,
  });

  final HostsRepository repository;

  /// The host's offered scenes; falls back to the full priced list for
  /// hosts without a published list (the server accepts any scene then).
  final List<String> offeredScenes;

  @override
  State<ProposalComposerPage> createState() => _ProposalComposerPageState();
}

class _ProposalComposerPageState extends State<ProposalComposerPage> {
  final TextEditingController _titleController = TextEditingController();
  // Only priced scene tags qualify (callers may pass interest tags for
  // hosts without a published scene list).
  late final List<String> _scenes = () {
    final List<String> offered = widget.offeredScenes
        .where(ScenePricing.config.sceneFees.containsKey)
        .toList(growable: false);
    return offered.isNotEmpty
        ? offered
        : ScenePricing.config.sceneFees.keys.toList(growable: false);
  }();
  late String _scene = _scenes.first;
  final ImagePicker _picker = ImagePicker();
  String _imageUrl = '';
  String _area = '';
  bool _busy = false;

  /// Photo upload needs the API; mock mode posts text-only pitches.
  bool get _photoEnabled => AppEnv.useRemoteApi;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
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
        setState(() => _imageUrl = url);
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

  Future<void> _publish() async {
    final String title = _titleController.text.trim();
    if (title.isEmpty || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.createProposal(
        title: title,
        sceneTag: _scene,
        imageUrl: _imageUrl,
        area: _area,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.verificationRequired) {
        final bool verified = await promptVerification(context);
        if (verified && mounted) {
          setState(() => _busy = false);
          return _publish();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorNetwork)),
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
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.proposalComposerTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('proposalTitleField'),
              controller: _titleController,
              maxLength: 80,
              minLines: 2,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: AppStrings.proposalTitleHint,
              ),
            ),
            if (_photoEnabled) ...<Widget>[
              const SizedBox(height: 8),
              // Optional cover photo: one image, replaced on re-pick.
              InkWell(
                key: const ValueKey<String>('proposalAddPhoto'),
                onTap: _busy ? null : _pickCover,
                borderRadius: BorderRadius.circular(12),
                child: _imageUrl.isEmpty
                    ? Container(
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
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          resolveMediaUrl(_imageUrl),
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              AppStrings.proposalSceneLabel,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String scene in _scenes)
                  InkWell(
                    key: ValueKey<String>('proposalScene$scene'),
                    onTap: () => setState(() => _scene = scene),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _scene == scene
                            ? AppColors.darkCard
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${AppStrings.sceneLabel(scene)} \u00b7 '
                        '\u20b1${ScenePricing.feeForScene(scene)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _scene == scene
                              ? AppColors.onDarkPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              AppStrings.proposalAreaLabel,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String area in AppStrings.manilaAreas)
                  InkWell(
                    key: ValueKey<String>('proposalArea$area'),
                    // Tap again to clear: the area is optional.
                    onTap: () => setState(
                      () => _area = _area == area ? '' : area,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _area == area
                            ? AppColors.darkCard
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        area,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _area == area
                              ? AppColors.onDarkPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey<String>('proposalPublishButton'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkCard,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _busy ? null : _publish,
                child: const Text(AppStrings.proposalPublishCta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
