import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../auth/pages/verification_page.dart';
import '../../community/models/activity_template.dart';
import '../../community/widgets/template_quote_card.dart';
import '../data/hosts_repository.dart';

/// Host-side composer for an activity pitch. The launched template is
/// quoted on top (the platform curates the activity type and content);
/// the title and description are the host's own words — never
/// pre-written. The pitch keeps the template's curated cover; no user
/// uploads here. No time or place either; those come later through the
/// standard order plan flow.
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
      ScenePricing.scenes;
  late final String _scene = () {
    final String? fromTemplate = widget.template?.sceneTag;
    return fromTemplate != null && _scenes.contains(fromTemplate)
        ? fromTemplate
        : _scenes.first;
  }();
  // The pitch keeps the template's curated cover: no user uploads.
  late final String _imageUrl = widget.template?.imageUrl ?? '';
  String _area = '';
  bool _busy = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_busy) {
      return;
    }
    // The host's own words are required: no pre-written copy.
    final String title = _titleController.text.trim();
    final String description = _descController.text.trim();
    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.publishFieldsRequiredHint)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.createProposal(
        title: title,
        description: description,
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
            // The launched platform activity, quoted: the type and content
            // are curated — the host describes it in their own words.
            if (widget.template != null) ...<Widget>[
              const FormFieldLabel(AppStrings.publishTemplateQuoteLabel),
              TemplateQuoteCard(template: widget.template!),
            ],
            // Budget -> title -> description: same order and widgets as
            // the users' request composer. The pitch itself carries no
            // price: the inviting user picks the tier, so the host sees
            // the scene's range.
            const FormFieldLabel(AppStrings.activityBudgetLabel),
            BudgetRangePanel(
              sceneTag: _scene,
              note: AppStrings.budgetCoversNoteHost,
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
