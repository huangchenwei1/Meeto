import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/env/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/feed_activity_card.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/guidelines_banner.dart';
import '../../community/data/community_repository.dart';
import '../../community/models/activity_post.dart';
import '../../community/pages/post_detail_page.dart';
import '../../hosts/data/hosts_repository.dart';
import '../../hosts/models/host_card.dart';
import '../../hosts/models/proposal_card.dart';
import '../../hosts/pages/host_detail_page.dart';
import '../../hosts/widgets/invite_flow.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/models/live_order.dart';
import '../../orders/pages/order_room_page.dart';
import '../../profile/data/profile_repository.dart';

/// Tab 2, identical for both roles: the dating hall. Every published
/// activity lives here in one feed — user requests (hosts pitch on them)
/// and host proposals (users invite from them) — in the same card
/// language. Whose cards you can act on depends on your role, so the feed
/// sorts actionable content first; the chips filter by side. Hosts also
/// get their pending direct invitations pinned on top: that queue is work,
/// not feed.
class HallPage extends StatefulWidget {
  const HallPage({
    super.key,
    required this.communityRepository,
    required this.profileRepository,
    required this.hostsRepository,
    required this.ordersRepository,
  });

  final CommunityRepository communityRepository;
  final ProfileRepository profileRepository;
  final HostsRepository hostsRepository;
  final OrdersRepository ordersRepository;

  @override
  State<HallPage> createState() => HallPageState();
}

/// Hall filter identifiers (display labels live in [AppStrings]).
const String _filterAll = 'ALL';
const String _filterRequests = 'REQUESTS';
const String _filterProposals = 'PROPOSALS';

class HallPageState extends State<HallPage> {
  List<ActivityPost> _requests = <ActivityPost>[];
  List<ProposalCard> _proposals = <ProposalCard>[];
  List<InvitationRecord> _pendingInvitations = <InvitationRecord>[];
  String _filter = _filterAll;
  bool _loaded = false;
  bool _respondingInvitation = false;
  Timer? _pollTimer;

  bool get _isHost => AuthSession.isHost;

  @override
  void initState() {
    super.initState();
    _load();
    if (AppEnv.useRemoteApi) {
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Called by the shell when the tab comes back into view.
  void reload() => _load();

  Future<void> _load() async {
    try {
      final (
        List<ActivityPost>,
        List<ProposalCard>,
        List<InvitationRecord>,
      ) result = await (
        widget.communityRepository.fetchOpenRequests(),
        widget.hostsRepository.fetchProposals(),
        _isHost
            ? widget.hostsRepository.fetchInvitations()
            : Future<List<InvitationRecord>>.value(
                const <InvitationRecord>[],
              ),
      ).wait;
      if (!mounted) {
        return;
      }
      setState(() {
        _requests = result.$1;
        _proposals = result.$2;
        _pendingInvitations = result.$3
            .where((InvitationRecord i) => i.isPending)
            .toList(growable: false);
        _loaded = true;
      });
    } on Exception {
      // Keep the last known list; pull-to-refresh or the next poll retries.
    }
  }

  /// The merged feed under the current filter. Cards the caller can act on
  /// come first (hosts work the requests, users shop the proposals),
  /// newest first within each group.
  List<Object> get _items {
    final List<Object> items = <Object>[
      if (_filter != _filterProposals) ..._requests,
      if (_filter != _filterRequests) ..._proposals,
    ];
    int group(Object item) {
      final bool isRequest = item is ActivityPost;
      final bool actionable = _isHost ? isRequest : !isRequest;
      return actionable ? 0 : 1;
    }

    DateTime createdAt(Object item) => item is ActivityPost
        ? item.createdAt
        : (item as ProposalCard).createdAt;
    items.sort((Object a, Object b) {
      final int byGroup = group(a).compareTo(group(b));
      if (byGroup != 0) {
        return byGroup;
      }
      return createdAt(b).compareTo(createdAt(a));
    });
    return items;
  }

  Future<void> _openRequest(ActivityPost post) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailPage(
          post: post,
          communityRepository: widget.communityRepository,
          profileRepository: widget.profileRepository,
          ordersRepository: widget.ordersRepository,
        ),
      ),
    );
    unawaited(_load());
  }

  Future<void> _openHost(String hostId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HostDetailPage(
          repository: widget.hostsRepository,
          hostId: hostId,
        ),
      ),
    );
    unawaited(_load());
  }

  /// Inviting from a pitch: the scene and the price are both locked to
  /// the proposal, and the pitch title travels as the default note.
  Future<void> _invite(ProposalCard proposal) async {
    await runInviteFlow(
      context,
      repository: widget.hostsRepository,
      hostId: proposal.hostId,
      hostName: proposal.hostName,
      scene: proposal.sceneTag,
      budget: proposal.budgetAmount,
      defaultNote: proposal.title,
    );
  }

  Future<void> _acceptInvitation(InvitationRecord invitation) async {
    setState(() => _respondingInvitation = true);
    try {
      final LiveOrder? order = await widget.hostsRepository.acceptInvitation(
        invitation.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingInvitations = _pendingInvitations
            .where((InvitationRecord i) => i.id != invitation.id)
            .toList(growable: false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.inviteAcceptedSnack)),
      );
      if (order != null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OrderRoomPage(
              repository: widget.ordersRepository,
              orderId: order.id,
              initialOrder: order,
            ),
          ),
        );
      }
      unawaited(_load());
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _respondingInvitation = false);
      }
    }
  }

  Future<void> _declineInvitation(InvitationRecord invitation) async {
    setState(() => _respondingInvitation = true);
    try {
      await widget.hostsRepository.declineInvitation(invitation.id);
      if (mounted) {
        setState(() {
          _pendingInvitations = _pendingInvitations
              .where((InvitationRecord i) => i.id != invitation.id)
              .toList(growable: false);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.inviteDeclinedSnack)),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _respondingInvitation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Object> items = _items;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Text(
                AppStrings.hallTitle,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: OptionChips(
                options: const <String>[
                  _filterAll,
                  _filterRequests,
                  _filterProposals,
                ],
                selected: _filter,
                // A filter is always active; re-tapping the selected chip
                // (which yields '') is a no-op.
                onChanged: (String value) {
                  if (value.isNotEmpty) {
                    setState(() => _filter = value);
                  }
                },
                keyPrefix: 'hallFilter',
                labelOf: (String value) => switch (value) {
                  _filterRequests => AppStrings.hallFilterRequests,
                  _filterProposals => AppStrings.hallFilterProposals,
                  _ => AppStrings.hallFilterAll,
                },
              ),
            ),
            Expanded(
              child: !_loaded
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                        // index 0: guidelines banner (+ the host's pending
                        // invitation queue when present).
                        itemCount: items.isEmpty ? 2 : items.length + 1,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 22),
                        itemBuilder: (BuildContext context, int index) {
                          if (index == 0) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const GuidelinesBanner(),
                                if (_pendingInvitations
                                    .isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 14),
                                  const _SectionHeader(
                                    label: AppStrings.gigsInvitesHeader,
                                  ),
                                  for (final InvitationRecord invitation
                                      in _pendingInvitations)
                                    _InvitationCard(
                                      invitation: invitation,
                                      busy: _respondingInvitation,
                                      onAccept: () =>
                                          _acceptInvitation(invitation),
                                      onDecline: () =>
                                          _declineInvitation(invitation),
                                    ),
                                ],
                              ],
                            );
                          }
                          if (items.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 100),
                              child: Center(
                                child: Text(
                                  AppStrings.hallEmpty,
                                  style:
                                      TextStyle(color: AppColors.textHint),
                                ),
                              ),
                            );
                          }
                          final Object item = items[index - 1];
                          return item is ActivityPost
                              ? _RequestCard(
                                  post: item,
                                  isHost: _isHost,
                                  onTap: () => _openRequest(item),
                                )
                              : _ProposalTile(
                                  proposal: item as ProposalCard,
                                  canInvite: !_isHost,
                                  onTap: () => _openHost(item.hostId),
                                  onInvite: () => _invite(item),
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
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// One open user request in the shared feed-post card. The fuzzy window,
/// rough district and signup count ride the info line. No money on the
/// card; the budget and earnings breakdown live on the detail page. Hosts
/// get the pitch pill; users just browse.
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.post,
    required this.isHost,
    required this.onTap,
  });

  final ActivityPost post;
  final bool isHost;
  final VoidCallback onTap;

  String get _infoLine => <String>[
        if (post.timeSlot.isNotEmpty) AppStrings.timeSlotLabel(post.timeSlot),
        if (post.area.isNotEmpty) post.area,
        if (post.signedCount > 0) AppStrings.appliedCount(post.signedCount),
      ].join(' \u00b7 ');

  @override
  Widget build(BuildContext context) {
    return FeedActivityCard(
      onTap: onTap,
      avatarUrl: post.author.avatarUrl,
      authorName: post.author.name,
      authorVerified: post.author.isVerified,
      metaLine: post.author.meta,
      createdAt: post.createdAt,
      imageUrl: post.imageUrl,
      sceneLabel: AppStrings.sceneLabel(post.sceneTag),
      title: post.title,
      description: post.description,
      infoIcon: Iconsax.clock,
      infoText: _infoLine,
      // The activity budget is the host's core take-the-gig signal, so it
      // rides on the card footer.
      footerIcon: Iconsax.empty_wallet,
      footerText: MoneyFormat.format(post.budgetAmount),
      action: !isHost
          ? const SizedBox.shrink()
          : post.hasApplied
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    AppStrings.gigAppliedBadge,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : FeedActionPill(
                  key: ValueKey<String>('pitchGig${post.id}'),
                  label: AppStrings.gigPitchCta,
                  onTap: onTap,
                ),
    );
  }
}

/// One host pitch in the shared feed-post card, mirroring the request
/// card: time window and rough location in the info line, the host's
/// picked price on the footer (inviting pays exactly this), the invite
/// pill for users; hosts browse the competition read-only.
class _ProposalTile extends StatelessWidget {
  const _ProposalTile({
    required this.proposal,
    required this.canInvite,
    required this.onTap,
    required this.onInvite,
  });

  final ProposalCard proposal;
  final bool canInvite;
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
      infoIcon: Iconsax.location,
      infoText: <String>[
        if (proposal.timeSlot.isNotEmpty)
          AppStrings.timeSlotLabel(proposal.timeSlot),
        proposal.locationLine,
      ].join(' \u00b7 '),
      footerIcon: Iconsax.empty_wallet,
      footerText: MoneyFormat.format(proposal.budgetAmount),
      action: canInvite
          ? FeedActionPill(
              key: ValueKey<String>('inviteProposal${proposal.id}'),
              label: AppStrings.hostInviteCta,
              onTap: onInvite,
            )
          : const SizedBox.shrink(),
    );
  }
}

/// One pending direct invitation: who wants what, with accept/decline
/// inline. Accepting opens the newly created order room.
class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final InvitationRecord invitation;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppAvatar(size: 38, imageUrl: invitation.fromAvatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppStrings.inviteFromLine(
                    invitation.fromName,
                    AppStrings.sceneLabel(invitation.sceneTag),
                  ),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (invitation.note.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '\u201c${invitation.note}\u201d',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Spacer(),
              TextButton(
                key: ValueKey<String>('declineInvite${invitation.id}'),
                onPressed: busy ? null : onDecline,
                child: const Text(AppStrings.inviteDeclineCta),
              ),
              const SizedBox(width: 6),
              FilledButton(
                key: ValueKey<String>('acceptInvite${invitation.id}'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.onDarkPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: busy ? null : onAccept,
                child: const Text(
                  AppStrings.inviteAcceptCta,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
