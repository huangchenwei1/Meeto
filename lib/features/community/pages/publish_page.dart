import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../data/community_repository.dart';
import '../../../core/network/api_client.dart';
import '../../auth/pages/verification_page.dart';

/// Full-screen form to publish a new activity request: scene, title and
/// description only. Time and place are deliberately absent — the selected
/// host proposes the concrete plan after the match (the plan flow).
///
/// Pops with `true` when a post was published.
class PublishPage extends StatefulWidget {
  const PublishPage({super.key, required this.repository});

  final CommunityRepository repository;

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  List<String> _scenes = <String>[];
  String? _selectedScene;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadScenes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadScenes() async {
    final List<String> scenes = await widget.repository.fetchScenes();
    if (!mounted) {
      return;
    }
    setState(() {
      _scenes = scenes;
      _selectedScene = scenes.first;
    });
  }

  Future<void> _submit() async {
    final String scene = _selectedScene ?? _scenes.first;
    setState(() => _submitting = true);
    try {
      await widget.repository.createPost(
        CreatePostInput(
          sceneTag: scene,
          title: _titleController.text.trim().isEmpty
              ? scene
              : _titleController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? AppStrings.publishDefaultDesc
              : _descController.text.trim(),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      if (e.verificationRequired) {
        final bool verified = await promptVerification(context);
        if (verified && mounted) {
          return _submit();
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.publishSuccess)));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.publishTitle),
        leading: IconButton(
          icon: const Icon(Iconsax.close_circle, size: 22),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: <Widget>[
          const _FieldLabel(AppStrings.publishScene),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _scenes.map((String scene) {
              final bool selected = scene == _selectedScene;
              return InkWell(
                onTap: () => setState(() => _selectedScene = scene),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.background,
                    border: Border.all(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    AppStrings.sceneLabel(scene),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? AppColors.background
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          _MatchFeeCard(
            fee: ScenePricing.feeForScene(_selectedScene ?? 'Coffee'),
          ),
          const _FieldLabel(AppStrings.publishFieldTitle),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: AppStrings.publishPhTitle,
            ),
          ),
          const _FieldLabel(
            AppStrings.publishFieldDesc,
            hint: AppStrings.publishFieldDescHint,
          ),
          TextField(
            controller: _descController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: AppStrings.publishPhDesc,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: AppColors.onDarkPrimary,
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(
            _submitting ? AppStrings.publishSuccess : AppStrings.publishSubmit,
          ),
        ),
      ),
    );
  }
}

/// Read-only service fee preview: pricing is platform-set per scene, so the
/// poster cannot edit it. The poster always pays the full fee.
class _MatchFeeCard extends StatelessWidget {
  const _MatchFeeCard({required this.fee});

  final int fee;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Iconsax.shield_tick, size: 17, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text(
                      AppStrings.tipLabel,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      MoneyFormat.format(fee),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  AppStrings.publishTipPayNote,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {this.hint});

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 9),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (hint != null) ...<Widget>[
            const SizedBox(width: 6),
            Text(
              hint!,
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
        ],
      ),
    );
  }
}

