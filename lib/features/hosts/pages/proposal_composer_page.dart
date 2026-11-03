import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/env/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../auth/pages/verification_page.dart';
import '../../community/models/activity_template.dart';
import '../data/hosts_repository.dart';

/// Host-side composer for an activity pitch: scene, title and description
/// — the same field set as the users' request composer, so both sides of
/// the board read identically — plus the supply-side extras (cover photo,
/// rough area). No time or place; those come later through the standard
/// order plan flow. Launching from a community-shelf template prefills
/// the text and cover.
class ProposalComposerPage extends StatefulWidget {
  const ProposalComposerPage({
    super.key,
    required this.repository,
    this.template,
  });

  final HostsRepository repository;

  /// When launched from the "hot activities" shelf; null for a blank form.
  final ActivityTemplate? template;

  @override
  State<ProposalComposerPage> createState() => _ProposalComposerPageState();
}

class _ProposalComposerPageState extends State<ProposalComposerPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  // Any priced scene goes: what a host offers is whatever they pitch.
  late final List<String> _scenes =
      ScenePricing.config.sceneFees.keys.toList(growable: false);
  late String _scene = () {
    final String? fromTemplate = widget.template?.sceneTag;
    return fromTemplate != null && _scenes.contains(fromTemplate)
        ? fromTemplate
        : _scenes.first;
  }();
  final ImagePicker _picker = ImagePicker();
  late String _imageUrl = widget.template?.imageUrl ?? '';
  String _area = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final ActivityTemplate? template = widget.template;
    if (template != null && template.id.isNotEmpty) {
      _titleController.text = template.title;
      _descController.text = template.description;
    }
  }

  /// Photo upload needs the API; mock mode posts text-only pitches.
  bool get _photoEnabled => AppEnv.useRemoteApi;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
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
        description: _descController.text.trim(),
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: <Widget>[
            // Scene -> title -> description: same order and widgets as the
            // users' request composer.
            const FormFieldLabel(AppStrings.proposalSceneLabel),
            ScenePriceChips(
              scenes: _scenes,
              selected: _scene,
              onSelect: (String scene) => setState(() => _scene = scene),
              keyPrefix: 'proposalScene',
            ),
            const FormFieldLabel(AppStrings.publishFieldTitle),
            TextField(
              key: const ValueKey<String>('proposalTitleField'),
              controller: _titleController,
              maxLength: 80,
              decoration: const InputDecoration(
                hintText: AppStrings.proposalTitleHint,
              ),
            ),
            const FormFieldLabel(
              AppStrings.publishFieldDesc,
              hint: AppStrings.publishFieldDescHint,
            ),
            TextField(
              key: const ValueKey<String>('proposalDescField'),
              controller: _descController,
              maxLength: 300,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: AppStrings.proposalDescHint,
              ),
            ),
            if (_photoEnabled) ...<Widget>[
              const FormFieldLabel(AppStrings.proposalCoverLabel),
              // Optional cover photo: one image, replaced on re-pick.
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
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
              ),
            ],
            const FormFieldLabel(AppStrings.proposalAreaLabel),
            OptionChips(
              options: AppStrings.manilaAreas,
              selected: _area,
              onChanged: (String value) => setState(() => _area = value),
              keyPrefix: 'proposalArea',
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
