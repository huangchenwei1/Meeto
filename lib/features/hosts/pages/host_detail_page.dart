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

  Future<void> _openInviteSheet() async {
    final HostCard host = _host!;
    final List<String> scenes =
        ScenePricing.config.sceneFees.keys.toList(growable: false);
    String selectedScene = scenes.first;
    final TextEditingController noteController = TextEditingController();
    final bool? send = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppStrings.inviteSheetTitle(host.name),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    AppStrings.inviteSceneLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: scenes.map((String scene) {
                      final bool selected = scene == selectedScene;
                      return InkWell(
                        onTap: () =>
                            setSheetState(() => selectedScene = scene),
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
                            scene,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? AppColors.onDarkPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(growable: false),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const ValueKey<String>('inviteNoteField'),
                    controller: noteController,
                    maxLength: 300,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: AppStrings.inviteNoteHint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.inviteFeeNote(
                      '\u20b1${ScenePricing.feeForScene(selectedScene)}',
                    ),
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
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: const Text(AppStrings.inviteSendCta),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (send != true || !mounted) {
      noteController.dispose();
      return;
    }
    final String note = noteController.text.trim();
    noteController.dispose();
    await _sendInvite(selectedScene, note);
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
          _ActivityPriceList(host: host),
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: FilledButton(
            key: const ValueKey<String>('inviteButton'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.onDarkPrimary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: _busy ? null : _openInviteSheet,
            child: const Text(AppStrings.inviteCta),
          ),
        ),
      ),
    );
  }
}

/// Price list of the activities this host can run: the host's specialty
/// scenes (matched by tags) with the platform-set budget per scene. Falls
/// back to the full scene table for hosts without matching tags.
class _ActivityPriceList extends StatelessWidget {
  const _ActivityPriceList({required this.host});

  final HostCard host;

  @override
  Widget build(BuildContext context) {
    final List<String> allScenes =
        ScenePricing.config.sceneFees.keys.toList(growable: false);
    final Set<String> tagSet =
        host.tags.map((String t) => t.toLowerCase()).toSet();
    final List<String> matched = allScenes
        .where((String scene) => tagSet.contains(scene.toLowerCase()))
        .toList(growable: false);
    final List<String> scenes = matched.isEmpty ? allScenes : matched;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < scenes.length; i++) ...<Widget>[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
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
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
