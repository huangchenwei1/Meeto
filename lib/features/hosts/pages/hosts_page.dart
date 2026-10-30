import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/feed_activity_card.dart';
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

/// One activity pitch in the shared feed-post card: host header on top,
/// activity box below with the rough location in the footer and the
/// invite pill as the action. Tapping anywhere opens the host's profile.
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
    return FeedActivityCard(
      onTap: onTap,
      avatarUrl: proposal.hostAvatarUrl,
      authorName: proposal.hostName,
      authorVerified: proposal.hostIsVerified,
      metaLine: _hostMetaLine,
      createdAt: proposal.createdAt,
      imageUrl: proposal.imageUrl,
      sceneLabel: AppStrings.sceneLabel(proposal.sceneTag),
      title: proposal.title,
      description: proposal.description,
      // Where, roughly. The fee waits for the invite sheet; the exact
      // venue for the plan flow.
      footerIcon: Iconsax.location,
      footerText: proposal.locationLine,
      action: FeedActionPill(
        key: ValueKey<String>('inviteProposal${proposal.id}'),
        label: AppStrings.hostInviteCta,
        onTap: onInvite,
      ),
    );
  }
}
