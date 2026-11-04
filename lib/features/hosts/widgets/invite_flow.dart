import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../auth/pages/verification_page.dart';
import '../data/hosts_repository.dart';
import '../models/proposal_card.dart';

/// Opens the invitation confirm sheet and queues the invite on the pitch,
/// handling the verification prompt and the duplicate/closed conflicts.
/// Invitations only start from a concrete activity pitch — the product
/// trades activities, not people — so the scene and the price are both
/// locked to the pitch: whoever launches the activity prices it.
///
/// Returns true when the invitation was sent.
Future<bool> runInviteFlow(
  BuildContext context, {
  required HostsRepository repository,
  required ProposalCard proposal,
}) async {
  final String? note = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => InviteSheet(
      hostName: proposal.hostName,
      scene: proposal.sceneTag,
      budget: proposal.budgetAmount,
    ),
  );
  if (note == null || !context.mounted) {
    return false;
  }
  // An empty note still carries context server-side via the pitch itself.
  return _send(
    context,
    repository: repository,
    proposalId: proposal.id,
    note: note.isEmpty ? proposal.title : note,
  );
}

Future<bool> _send(
  BuildContext context, {
  required HostsRepository repository,
  required String proposalId,
  required String note,
}) async {
  try {
    await repository.inviteToProposal(proposalId, note: note);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.inviteSentSnack)),
      );
    }
    return true;
  } on ApiException catch (e) {
    if (!context.mounted) {
      return false;
    }
    if (e.verificationRequired) {
      final bool verified = await promptVerification(context);
      if (verified && context.mounted) {
        return _send(
          context,
          repository: repository,
          proposalId: proposalId,
          note: note,
        );
      }
      return false;
    }
    final String message = switch (e.message) {
      'INVITE_ALREADY_PENDING' => AppStrings.inviteAlreadyPendingSnack,
      'PROPOSAL_NOT_OPEN' => AppStrings.proposalNotOpenSnack,
      _ => e.message,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    return false;
  }
}

/// Invitation confirm sheet. The scene and price come from the pitch and
/// are read-only here: the sheet just shows what the user is agreeing to
/// pay and collects an optional note. A proper StatefulWidget so the note
/// controller is disposed by the sheet's own State after the route fully
/// unmounts. Pops the note text on send.
class InviteSheet extends StatefulWidget {
  const InviteSheet({
    super.key,
    required this.hostName,
    required this.scene,
    required this.budget,
  });

  final String hostName;
  final String scene;

  /// The pitch's budget tier (whole pesos), locked.
  final int budget;

  @override
  State<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<InviteSheet> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String fee = MoneyFormat.format(widget.budget);
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
          // Scene pill + the pitch's locked price side by side.
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  AppStrings.sceneLabel(widget.scene),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onDarkPrimary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                fee,
                key: const ValueKey<String>('inviteLockedPrice'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.budgetCoversNoteUser,
            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
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
              onPressed: () =>
                  Navigator.of(context).pop(_noteController.text.trim()),
              child: const Text(AppStrings.inviteSendCta),
            ),
          ),
        ],
      ),
    );
  }
}
