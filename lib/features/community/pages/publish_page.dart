import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../auth/pages/verification_page.dart';
import '../data/community_repository.dart';
import '../models/activity_template.dart';

/// Full-screen form to publish a new activity request: scene, title,
/// description, plus an optional fuzzy time window and rough district.
/// The exact schedule stays absent on purpose: the selected host proposes
/// the concrete plan after the match (the plan flow). The platform fee
/// rides on the scene chips. Launching from a template on the community
/// shelf prefills everything, so posting is "choose and confirm".
///
/// Pops with `true` when a post was published.
class PublishPage extends StatefulWidget {
  const PublishPage({super.key, required this.repository, this.template});

  final CommunityRepository repository;

  /// When launched from the "hot activities" shelf; null for a blank form.
  final ActivityTemplate? template;

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // The scene is fixed by the launched template — the shelf is the only
  // publish entry — so the composer surfaces the platform-set activity
  // budget instead of a scene picker.
  late final String _scene = () {
    final String? fromTemplate = widget.template?.sceneTag;
    return fromTemplate != null &&
            ScenePricing.config.sceneFees.containsKey(fromTemplate)
        ? fromTemplate
        : ScenePricing.config.sceneFees.keys.first;
  }();
  String _timeSlot = '';
  String _area = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final ActivityTemplate? template = widget.template;
    if (template != null && template.id.isNotEmpty) {
      _titleController.text = template.title;
      _descController.text = template.description;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String scene = _scene;
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
          timeSlot: _timeSlot,
          area: _area,
          // Template launches keep the curated cover; a scene default
          // covers blank launches server-side.
          imageUrl: scene == widget.template?.sceneTag
              ? (widget.template?.imageUrl ?? '')
              : '',
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
          const FormFieldLabel(AppStrings.activityBudgetLabel),
          ActivityBudgetPanel(
            sceneTag: _scene,
            note: AppStrings.budgetCoversNoteUser,
          ),
          const FormFieldLabel(AppStrings.publishFieldTitle),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: AppStrings.publishPhTitle,
            ),
          ),
          const FormFieldLabel(
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
          // Fuzzy window and rough district only; the exact schedule comes
          // later through the plan flow.
          const FormFieldLabel(AppStrings.publishTimeSlotLabel),
          OptionChips(
            options: AppStrings.timeSlots,
            selected: _timeSlot,
            onChanged: (String value) => setState(() => _timeSlot = value),
            keyPrefix: 'publishTimeSlot',
            labelOf: AppStrings.timeSlotLabel,
          ),
          const FormFieldLabel(AppStrings.proposalAreaLabel),
          OptionChips(
            options: AppStrings.manilaAreas,
            selected: _area,
            onChanged: (String value) => setState(() => _area = value),
            keyPrefix: 'publishArea',
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

