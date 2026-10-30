import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/guidelines_banner.dart';
import '../../community/data/community_repository.dart';
import '../../community/pages/publish_page.dart';
import '../data/hosts_repository.dart';
import '../models/proposal_card.dart';
import '../widgets/invite_flow.dart';
import 'host_detail_page.dart';

/// User home (first tab): the activity proposal feed. Hosts pitch loose
/// activity ideas ("let's catch a live gig"); users buy the idea, not the
/// person — the host rides along as the signature line. Inviting from a
/// pitch enters the standard invitation -> payment -> plan flow. Also
/// carries the "post a request" entry, the demand-side mirror.
class HostsPage extends StatefulWidget {
  const HostsPage({
    super.key,
    required this.repository,
    required this.communityRepository,
  });

  final HostsRepository repository;
  final CommunityRepository communityRepository;

  @override
  State<HostsPage> createState() => HostsPageState();
}

class HostsPageState extends State<HostsPage> {
  List<ProposalCard> _proposals = <ProposalCard>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final List<ProposalCard> proposals =
          await widget.repository.fetchProposals();
      if (mounted) {
        setState(() {
          _proposals = proposals;
          _loading = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      AppStrings.hostsTitle,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  // Post-a-request entry, kept as a quiet icon so the
                  // proposal feed stays the hero of the page.
                  InkWell(
                    key: const ValueKey<String>('postRequestButton'),
                    onTap: _openPublish,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: AppColors.darkCard,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Iconsax.add,
                        size: 20,
                        color: AppColors.onDarkPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: reload,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                        // +1: the shared guidelines banner leads the list,
                        // same as on the community tab.
                        itemCount: _proposals.isEmpty
                            ? 2
                            : _proposals.length + 1,
                        // Borderless feed posts need more air between
                        // them than the old outlined cards did.
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 22),
                        itemBuilder: (BuildContext context, int index) {
                          if (index == 0) {
                            return const GuidelinesBanner();
                          }
                          if (_proposals.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 120),
                              child: Center(
                                child: Text(
                                  AppStrings.hostsEmpty,
                                  style:
                                      TextStyle(color: AppColors.textHint),
                                ),
                              ),
                            );
                          }
                          final ProposalCard proposal =
                              _proposals[index - 1];
                          return _ProposalTile(
                            proposal: proposal,
                            onTap: () => _openHost(proposal.hostId),
                            onInvite: () => _invite(proposal),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Inviting from a pitch: the scene is fixed by the proposal, and the
  /// pitch title travels as the default note so the host sees which idea
  /// the invitation came from.
  Future<void> _invite(ProposalCard proposal) async {
    await runInviteFlow(
      context,
      repository: widget.repository,
      hostId: proposal.hostId,
      hostName: proposal.hostName,
      scene: proposal.sceneTag,
      defaultNote: proposal.title,
    );
  }

  Future<void> _openHost(String hostId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HostDetailPage(
          repository: widget.repository,
          hostId: hostId,
        ),
      ),
    );
    reload();
  }

  /// The complementary path to proposals: post a request and let hosts
  /// pitch their plans (tracked afterwards in My Posts).
  Future<void> _openPublish() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => PublishPage(repository: widget.communityRepository),
      ),
    );
  }
}

/// One activity pitch, feed-post style: the host header rides on top
/// (avatar, name, verified mark, demographics + hosting record, time),
/// and the activity itself sits in an inset box — cover photo left, scene
/// chip + title + fee and the invite entry right. Only fields we actually
/// have: no distance, no schedule, no venue — those come later through
/// the plan flow. Tapping anywhere opens the host's profile; the invite
/// pill starts the invitation for this pitch's scene.
class _ProposalTile extends StatelessWidget {
  const _ProposalTile({
    required this.proposal,
    required this.onTap,
    required this.onInvite,
  });

  final ProposalCard proposal;
  final VoidCallback onTap;
  final VoidCallback onInvite;

  String get _hostMetaLine {
    final String record = proposal.hostCompletedActivities > 0
        ? AppStrings.hostCompletedLabel(proposal.hostCompletedActivities)
        : AppStrings.hostNewLabel;
    return proposal.hostMeta.isEmpty
        ? record
        : '${proposal.hostMeta} \u00b7 $record';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppAvatar(
                size: 42,
                imageUrl: proposal.hostAvatarUrl,
                squircle: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            proposal.hostName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (proposal.hostIsVerified) ...<Widget>[
                          const SizedBox(width: 5),
                          const Icon(
                            Iconsax.verify5,
                            size: 14,
                            color: AppColors.accent,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hostMetaLine,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatTimeAgo(proposal.createdAt),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // The activity box: what you are actually buying.
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: AppColors.surface,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (proposal.imageUrl.isNotEmpty)
                      SizedBox(
                        width: 112,
                        child: AppNetworkImage(url: proposal.imageUrl),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                AppStrings.sceneLabel(proposal.sceneTag),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              proposal.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: <Widget>[
                                Text(
                                  AppStrings.tipLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '\u20b1${ScenePricing.feeForScene(proposal.sceneTag)}',
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                InkWell(
                                  key: ValueKey<String>(
                                    'inviteProposal${proposal.id}',
                                  ),
                                  onTap: onInvite,
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.darkCard,
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      AppStrings.hostInviteCta,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.onDarkPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
