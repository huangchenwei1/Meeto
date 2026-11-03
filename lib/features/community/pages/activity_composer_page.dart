import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../auth/pages/verification_page.dart';
import '../models/activity_template.dart';
import '../widgets/template_quote_card.dart';

/// Everything a composer collects; the caller turns it into a demand post
/// (user side) or an activity pitch (host side).
class ActivityDraft {
  const ActivityDraft({
    required this.sceneTag,
    required this.title,
    required this.description,
    required this.budget,
    required this.timeSlot,
    required this.area,
    required this.imageUrl,
  });

  final String sceneTag;
  final String title;
  final String description;

  /// The platform budget tier picked by whoever launches the activity
  /// (whole pesos).
  final int budget;
  final String timeSlot;
  final String area;
  final String imageUrl;
}

/// The one activity composer both roles share: users publish a request,
/// hosts publish a pitch — same form, same rules, different budget note
/// and submit action. The launched template is quoted on top (the
/// platform curates the activity type and content); the title and
/// description are the author's own words — never pre-written.
///
/// Pops with `true` when published.
class ActivityComposerPage extends StatefulWidget {
  const ActivityComposerPage({
    super.key,
    required this.pageTitle,
    required this.budgetNote,
    required this.template,
    required this.onSubmit,
  });

  final String pageTitle;

  /// Role-specific one-liner under the budget tiers.
  final String budgetNote;

  /// The launched platform activity; null for a blank form.
  final ActivityTemplate? template;

  /// Publishes the draft; may throw [ApiException].
  final Future<void> Function(ActivityDraft draft) onSubmit;

  @override
  State<ActivityComposerPage> createState() => _ActivityComposerPageState();
}

class _ActivityComposerPageState extends State<ActivityComposerPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // The scene is fixed by the launched template — the shelf is the only
  // publish entry — so the composer surfaces the platform budget tiers
  // instead of a scene picker.
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
    // The author's own words are required: no pre-written copy to fall
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
      await widget.onSubmit(
        ActivityDraft(
          sceneTag: _scene,
          title: title,
          description: description,
          budget: _budget,
          timeSlot: _timeSlot,
          area: _area,
          // The template's curated cover rides along; no user uploads.
          imageUrl: widget.template?.imageUrl ?? '',
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
        title: Text(widget.pageTitle),
        leading: IconButton(
          icon: const Icon(Iconsax.close_circle, size: 22),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: <Widget>[
          // The launched platform activity, quoted: the type and content
          // are curated — the author describes it in their own words.
          if (widget.template != null) ...<Widget>[
            const FormFieldLabel(AppStrings.publishTemplateQuoteLabel),
            TemplateQuoteCard(template: widget.template!),
          ],
          const FormFieldLabel(AppStrings.activityBudgetLabel),
          BudgetTierChips(
            sceneTag: _scene,
            selected: _budget,
            onSelect: (int tier) => setState(() => _budget = tier),
            note: widget.budgetNote,
            keyPrefix: 'publishBudget',
          ),
          const FormFieldLabel(AppStrings.publishFieldTitle),
          TextField(
            key: const ValueKey<String>('composerTitleField'),
            controller: _titleController,
            maxLength: 80,
            decoration: const InputDecoration(
              hintText: AppStrings.publishPhTitle,
            ),
          ),
          const FormFieldLabel(
            AppStrings.publishFieldDesc,
            hint: AppStrings.publishFieldDescHint,
          ),
          TextField(
            key: const ValueKey<String>('composerDescField'),
            controller: _descController,
            maxLength: 300,
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
          key: const ValueKey<String>('composerPublishButton'),
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
