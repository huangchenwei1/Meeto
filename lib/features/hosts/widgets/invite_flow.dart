import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/pages/verification_page.dart';
import '../data/hosts_repository.dart';

/// Opens the invitation confirm sheet for one fixed scene and sends the
/// invite, handling the verification prompt and duplicate-invite conflict.
/// Shared by the proposal feed and the host detail price list.
///
/// [defaultNote] fills in when the user leaves the note empty — e.g. the
/// proposal title the invitation came from, so the host sees the context.
Future<void> runInviteFlow(
  BuildContext context, {
  required HostsRepository repository,
  required String hostId,
  required String hostName,
  required String scene,
  String defaultNote = '',
}) async {
  final String? note = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => InviteSheet(hostName: hostName, scene: scene),
  );
  if (note == null || !context.mounted) {
    return;
  }
  await _send(
    context,
    repository: repository,
    hostId: hostId,
    sceneTag: scene,
    note: note.isEmpty ? defaultNote : note,
  );
}

Future<void> _send(
  BuildContext context, {
  required HostsRepository repository,
  required String hostId,
  required String sceneTag,
  required String note,
}) async {
  try {
    await repository.invite(hostId: hostId, sceneTag: sceneTag, note: note);
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

/// Invitation confirm sheet for one fixed scene. A proper StatefulWidget
/// so the note controller is disposed by the sheet's own State after the
/// route fully unmounts. Pops the (possibly empty) note text on send.
class InviteSheet extends StatefulWidget {
  const InviteSheet({super.key, required this.hostName, required this.scene});

  final String hostName;
  final String scene;

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
    final String fee = '\u20b1${ScenePricing.feeForScene(widget.scene)}';
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
              const SizedBox(width: 10),
              Text(
                fee,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
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
