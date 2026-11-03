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
import '../widgets/template_quote_card.dart';

/// Full-screen form to publish a new activity request. The launched
/// template is quoted on top (the platform curates the activity type and
/// content); the title and description are the user's own words — never
/// pre-written. The exact schedule stays absent on purpose: the selected
/// host proposes the concrete plan after the match (the plan flow).
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
            ScenePricing.config.sceneBudgetTiers.containsKey(fromTemplate)
        ? fromTemplate
        : ScenePricing.scenes.first;
  }();
  late int _budget = ScenePricing.defaultBudgetForScene(_scene);
  String _timeSlot = '';
  String _area = '';
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String scene = _scene;
    // The user's own words are required: no pre-written copy to fall
    // back on.
    final String title = _titleController.text.trim();
    final String description = _descController.text.trim();
    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.publishFieldsRequiredHint)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.repository.createPost(
        CreatePostInput(
          sceneTag: scene,
          title: title,
          description: description,
          timeSlot: _timeSlot,
          area: _area,
          budget: _budget,
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
          // The launched platform activity, quoted: the type and content
          // are curated — users describe it in their own words below.
          if (widget.template != null) ...<Widget>[
            const FormFieldLabel(AppStrings.publishTemplateQuoteLabel),
            TemplateQuoteCard(template: widget.template!),
          ],
          const FormFieldLabel(AppStrings.activityBudgetLabel),
          BudgetTierChips(
            sceneTag: _scene,
            selected: _budget,
            onSelect: (int tier) => setState(() => _budget = tier),
            note: AppStrings.budgetCoversNoteUser,
            keyPrefix: 'publishBudget',
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

