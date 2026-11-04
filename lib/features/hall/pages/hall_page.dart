import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/env/app_env.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/feed_activity_card.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/guidelines_banner.dart';
import '../../community/data/community_repository.dart';
import '../../community/models/activity_post.dart';
import '../../community/pages/activity_composer_page.dart';
import '../../community/pages/post_detail_page.dart';
import '../../hosts/data/hosts_repository.dart';
import '../../hosts/models/proposal_card.dart';
import '../../hosts/pages/proposal_detail_page.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../notifications/pages/notifications_page.dart';
import '../../orders/data/orders_repository.dart';
import '../../profile/data/profile_repository.dart';

/// Tab 2, identical for both roles: the dating hall. Every published
/// activity lives here in one feed — user requests (hosts pitch on them)
/// and host proposals (users invite on them) — in the same card
/// language, and both sides open a full detail page where the owner
/// screens the queue and the other side joins it. Whose cards you can act
/// on depends on your role, so the feed sorts actionable content first;
/// the chips filter by side.
class HallPage extends StatefulWidget {
  const HallPage({
    super.key,
    required this.communityRepository,
    required this.profileRepository,
    required this.hostsRepository,
    required this.ordersRepository,
    required this.notificationsRepository,
  });

  final CommunityRepository communityRepository;
  final ProfileRepository profileRepository;
  final HostsRepository hostsRepository;
  final OrdersRepository ordersRepository;
  final NotificationsRepository notificationsRepository;

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
  int _unreadCount = 0;
  String _unreadAvatarUrl = '';
  String _filter = _filterAll;
  bool _loaded = false;
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
        List<AppNotification>,
      ) result = await (
        widget.communityRepository.fetchOpenRequests(),
        widget.hostsRepository.fetchProposals(),
        widget.notificationsRepository.list(),
      ).wait;
      if (!mounted) {
        return;
      }
      // Newest-first inbox: the first unread actor fronts the pill, like
      // the WeChat Moments notice.
      final List<AppNotification> unread = result.$3
          .where((AppNotification n) => !n.isRead)
          .toList(growable: false);
      setState(() {
        _requests = result.$1;
        _proposals = result.$2;
        _unreadCount = unread.length;
        _unreadAvatarUrl = unread.isEmpty ? '' : unread.first.actorAvatarUrl;
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

  /// Both roles land on the same detail page: the owner screens the
  /// invite queue there, users join it (mirror of the request detail).
  Future<void> _openProposal(ProposalCard proposal) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProposalDetailPage(
          proposal: proposal,
          hostsRepository: widget.hostsRepository,
          profileRepository: widget.profileRepository,
          ordersRepository: widget.ordersRepository,
        ),
      ),
    );
    unawaited(_load());
  }

  /// The unread pill goes to the shared inbox, which marks everything
  /// read on open; the pill disappears when we come back.
  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsPage(
          notificationsRepository: widget.notificationsRepository,
          communityRepository: widget.communityRepository,
          profileRepository: widget.profileRepository,
          ordersRepository: widget.ordersRepository,
          hostsRepository: widget.hostsRepository,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _unreadCount = 0;
        _unreadAvatarUrl = '';
      });
      unawaited(_load());
    }
  }

  /// Free-form publish from the hall: no template, so the composer asks
  /// for the scene and a curated cover. The fresh card should show up
  /// right away, so reload on success.
  Future<void> _publish() async {
    final bool? posted = await openActivityComposer(
      context,
      communityRepository: widget.communityRepository,
      hostsRepository: widget.hostsRepository,
    );
    if ((posted ?? false) && mounted) {
      unawaited(_load());
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: <Widget>[
                  const Text(
                    AppStrings.hallTitle,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // Free-form publish, next to the shelf-template path:
                  // the composer opens blank and the author picks the
                  // scene and a curated cover inside.
                  IconButton(
                    key: const ValueKey<String>('hallPublishButton'),
                    icon: const Icon(
                      Iconsax.add_square,
                      size: 24,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: _publish,
                  ),
                ],
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
                        // index 0: guidelines banner + unread pill.
                        itemCount: items.isEmpty ? 2 : items.length + 1,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 22),
                        itemBuilder: (BuildContext context, int index) {
                          if (index == 0) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const GuidelinesBanner(),
                                // The WeChat-Moments-style unread notice:
                                // latest unread actor + count, centered
                                // under the banner.
                                if (_unreadCount > 0) ...<Widget>[
                                  const SizedBox(height: 14),
                                  Center(
                                    child: _UnreadNoticePill(
                                      count: _unreadCount,
                                      avatarUrl: _unreadAvatarUrl,
                                      onTap: _openNotifications,
                                    ),
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
                                  onTap: () => _openProposal(item),
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
/// card: time window, rough location and the invite queue size in the
/// info line, the host's picked price on the footer (inviting pays
/// exactly this). The whole card — invite pill included — opens the
/// proposal detail, where users queue and the host screens the queue.
class _ProposalTile extends StatelessWidget {
  const _ProposalTile({
    required this.proposal,
    required this.canInvite,
    required this.onTap,
  });

  final ProposalCard proposal;
  final bool canInvite;
  final VoidCallback onTap;

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
        if (proposal.locationLine.isNotEmpty) proposal.locationLine,
        if (proposal.inviteCount > 0)
          AppStrings.proposalInviteCount(proposal.inviteCount),
      ].join(' \u00b7 '),
      footerIcon: Iconsax.empty_wallet,
      footerText: MoneyFormat.format(proposal.budgetAmount),
      action: !canInvite
          ? const SizedBox.shrink()
          : proposal.hasInvited
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
                    AppStrings.invitedBadge,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : FeedActionPill(
                  key: ValueKey<String>('inviteProposal${proposal.id}'),
                  label: AppStrings.hostInviteCta,
                  onTap: onTap,
                ),
    );
  }
}

/// The WeChat-Moments-style unread notice pill: dark capsule with the
/// latest unread actor's avatar and the unread count, opening the shared
/// notifications inbox.
class _UnreadNoticePill extends StatelessWidget {
  const _UnreadNoticePill({
    required this.count,
    required this.avatarUrl,
    required this.onTap,
  });

  final int count;
  final String avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey<String>('hallUnreadPill'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (avatarUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AppNetworkImage(url: avatarUrl, width: 30, height: 30),
              ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                AppStrings.unreadNoticePill(count),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onDarkPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
