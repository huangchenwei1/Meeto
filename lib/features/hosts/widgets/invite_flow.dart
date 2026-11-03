import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../auth/pages/verification_page.dart';
import '../data/hosts_repository.dart';

/// Opens the invitation confirm sheet and sends the invite, handling the
/// verification prompt and duplicate-invite conflict. Shared by the hall
/// (scene fixed by the proposal) and the host profile ([scene] null: the
/// sheet lets the user pick any priced scene).
///
/// [defaultNote] fills in when the user leaves the note empty — e.g. the
/// proposal title the invitation came from, so the host sees the context.
Future<void> runInviteFlow(
  BuildContext context, {
  required HostsRepository repository,
  required String hostId,
  required String hostName,
  String? scene,
  String defaultNote = '',
}) async {
  final (String, int, String)? result =
      await showModalBottomSheet<(String, int, String)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => InviteSheet(hostName: hostName, scene: scene),
  );
  if (result == null || !context.mounted) {
    return;
  }
  final (String sceneTag, int budget, String note) = result;
  await _send(
    context,
    repository: repository,
    hostId: hostId,
    sceneTag: sceneTag,
    budget: budget,
    note: note.isEmpty ? defaultNote : note,
  );
}

Future<void> _send(
  BuildContext context, {
  required HostsRepository repository,
  required String hostId,
  required String sceneTag,
  required int budget,
  required String note,
}) async {
  try {
    await repository.invite(
      hostId: hostId,
      sceneTag: sceneTag,
      budget: budget,
      note: note,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.inviteSentSnack)),
      );
    }
  } on ApiException catch (e) {
    if (!context.mounted) {
      return;
    }
    if (e.verificationRequired) {
      final bool verified = await promptVerification(context);
      if (verified && context.mounted) {
        return _send(
          context,
          repository: repository,
          hostId: hostId,
          sceneTag: sceneTag,
          budget: budget,
          note: note,
        );
      }
    } else {
      final String message = e.statusCode == 409
          ? AppStrings.inviteAlreadyPendingSnack
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

/// Invitation confirm sheet. With a fixed [scene] (invited from a pitch)
/// it shows the scene pill; with none (invited from the host profile) it
/// offers all priced scenes as chips. Either way the inviter picks a
/// platform budget tier for the activity. A proper StatefulWidget so the
/// note controller is disposed by the sheet's own State after the route
/// fully unmounts. Pops the chosen (scene, budget, note) on send.
class InviteSheet extends StatefulWidget {
  const InviteSheet({super.key, required this.hostName, this.scene});

  final String hostName;
  final String? scene;

  @override
  State<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<InviteSheet> {
  final TextEditingController _noteController = TextEditingController();
  late String _scene = widget.scene ?? ScenePricing.scenes.first;
  late int _budget = ScenePricing.defaultBudgetForScene(_scene);

  void _pickScene(String scene) {
    setState(() {
      _scene = scene;
      // Each scene prices in its own tiers; re-default to the middle one.
      _budget = ScenePricing.defaultBudgetForScene(scene);
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String fee = MoneyFormat.format(_budget);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.inviteSheetTitle(widget.hostName),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.scene == null)
            // Profile entry: the user picks the activity type first.
            ScenePriceChips(
              scenes: ScenePricing.scenes,
              selected: _scene,
              onSelect: _pickScene,
              keyPrefix: 'inviteScene',
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  AppStrings.sceneLabel(_scene),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onDarkPrimary,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          // The inviter picks the activity budget tier; the note under the
          // chips explains what the money covers.
          BudgetTierChips(
            sceneTag: _scene,
            selected: _budget,
            onSelect: (int tier) => setState(() => _budget = tier),
            note: AppStrings.budgetCoversNoteUser,
            keyPrefix: 'inviteBudget',
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey<String>('inviteNoteField'),
            controller: _noteController,
            maxLength: 300,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: AppStrings.inviteNoteHint,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.inviteFeeNote(fee),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey<String>('inviteSendButton'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.darkCard,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.of(context)
                  .pop((_scene, _budget, _noteController.text.trim())),
              child: const Text(AppStrings.inviteSendCta),
            ),
          ),
        ],
      ),
    );
  }
}
