import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../auth/pages/verification_page.dart';
import '../data/hosts_repository.dart';
import '../models/host_card.dart';

/// Host profile + the direct invitation entry (user side).
class HostDetailPage extends StatefulWidget {
  const HostDetailPage({
    super.key,
    required this.repository,
    required this.hostId,
    this.initial,
  });

  final HostsRepository repository;
  final String hostId;
  final HostCard? initial;

  @override
  State<HostDetailPage> createState() => _HostDetailPageState();
}

class _HostDetailPageState extends State<HostDetailPage> {
  HostCard? _host;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _host = widget.initial;
    _load();
  }

  Future<void> _load() async {
    try {
      final HostCard host = await widget.repository.fetchHost(widget.hostId);
      if (mounted) {
        setState(() => _host = host);
      }
    } on Exception {
      // Keep the initial card if the refresh fails.
    }
  }

  /// Invitation confirm sheet for one scene, opened from the activity
  /// price list. The scene is fixed by the row the user tapped; only the
  /// optional note and the fee confirmation remain.
  Future<void> _openInviteSheet(String scene) async {
    final HostCard host = _host!;
    // The sheet owns its text controller (disposed by its own State after
    // the route fully unmounts); disposing right after the await crashes
    // the exit animation ('_dependents.isEmpty'). Pops the note to send.
    final String? note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _InviteSheet(hostName: host.name, scene: scene),
    );
    if (note == null || !mounted) {
      return;
    }
    await _sendInvite(scene, note);
  }

  Future<void> _sendInvite(String sceneTag, String note) async {
    setState(() => _busy = true);
    try {
      await widget.repository.invite(
        hostId: widget.hostId,
        sceneTag: sceneTag,
        note: note,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.inviteSentSnack)),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.verificationRequired) {
        final bool verified = await promptVerification(context);
        if (verified && mounted) {
          setState(() => _busy = false);
          return _sendInvite(sceneTag, note);
        }
      } else {
        final String message = e.statusCode == 409
            ? AppStrings.inviteAlreadyPendingSnack
            : e.message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
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
    final HostCard? host = _host;
    if (host == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          Row(
            children: <Widget>[
              AppAvatar(size: 72, imageUrl: host.avatarUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            host.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (host.isVerified) ...<Widget>[
                          const SizedBox(width: 6),
                          const Icon(
                            Iconsax.verify5,
                            size: 18,
                            color: AppColors.accent,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      host.city.isEmpty
                          ? host.meta
                          : '${host.meta} \u00b7 ${host.city}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      host.completedActivities > 0
                          ? AppStrings.hostCompletedLabel(
                              host.completedActivities,
                            )
                          : AppStrings.hostNewLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (host.bio.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Text(
              host.bio,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (host.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: host.tags
                  .map(
                    (String tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            AppStrings.hostActivitiesTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _ActivityPriceList(
            host: host,
            onInvite: _busy ? null : _openInviteSheet,
          ),
          if (host.recentProposals.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            const Text(
              AppStrings.hostRecentPlanLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final String proposal in host.recentProposals)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '\u201c$proposal\u201d',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Price list of the activities this host offers (picked at registration),
/// with the platform-set fee per scene. Each row is the invitation entry
/// for that scene. Hosts without a published list take any scene.
class _ActivityPriceList extends StatelessWidget {
  const _ActivityPriceList({required this.host, required this.onInvite});

  final HostCard host;
  final ValueChanged<String>? onInvite;

  @override
  Widget build(BuildContext context) {
    final List<String> scenes = host.hostScenes.isNotEmpty
        ? host.hostScenes
        : ScenePricing.config.sceneFees.keys.toList(growable: false);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < scenes.length; i++) ...<Widget>[
            if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14),
            InkWell(
              key: ValueKey<String>('inviteScene${scenes[i]}'),
              onTap:
                  onInvite == null ? null : () => onInvite!(scenes[i]),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Iconsax.calendar_1,
                      size: 15,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        scenes[i],
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '\u20b1${ScenePricing.feeForScene(scenes[i])}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        AppStrings.inviteRowCta,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onDarkPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Invitation confirm sheet for one fixed scene. A proper StatefulWidget
/// so the note controller is disposed by the sheet's own State after the
/// route fully unmounts. Pops the (possibly empty) note text on send.
class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.hostName, required this.scene});

  final String hostName;
  final String scene;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
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
                  widget.scene,
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
