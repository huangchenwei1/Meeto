import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/env/app_env.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../community/data/community_repository.dart';
import '../../community/models/activity_post.dart';
import '../../community/models/post_author.dart';
import '../../community/pages/post_detail_page.dart';
import '../../hosts/data/hosts_repository.dart';
import '../../hosts/models/proposal_card.dart';
import '../../hosts/pages/proposal_detail_page.dart';
import '../../profile/data/profile_repository.dart';
import '../data/orders_repository.dart';
import '../models/live_order.dart';
import 'order_room_page.dart';

/// Tab 3: the My Activities board. One card per activity journey, the
/// status lives on the card, and the tap follows the status:
/// - a deal in progress opens its chat room
/// - my open post shows who signed up and opens the candidate screening
/// - my open pitch shows the invite queue (hosts)
/// - a post I signed up for waits for selection (hosts)
/// Deliberately simple: no awaiting-payment or cancelled entries — unpaid
/// deals finish (or expire) where they were formed, dead deals disappear.
class MyActivitiesPage extends StatefulWidget {
  const MyActivitiesPage({
    super.key,
    required this.ordersRepository,
    required this.communityRepository,
    required this.hostsRepository,
    required this.profileRepository,
  });

  final OrdersRepository ordersRepository;
  final CommunityRepository communityRepository;
  final HostsRepository hostsRepository;
  final ProfileRepository profileRepository;

  @override
  State<MyActivitiesPage> createState() => MyActivitiesPageState();
}

/// One entry on the board. [group] drives the sort: running deals first,
/// then everything still waiting, finished deals last.
sealed class _Journey {
  const _Journey();

  int get group;
  DateTime get createdAt;
}

class _OrderJourney extends _Journey {
  const _OrderJourney(this.order);

  final LiveOrder order;

  @override
  int get group => order.status == 'ACTIVE' ? 0 : 2;

  @override
  DateTime get createdAt => order.createdAt;
}

class _PostJourney extends _Journey {
  const _PostJourney(this.post, {required this.mine});

  final ActivityPost post;

  /// true: my own post waiting for signups; false: a post I signed up for.
  final bool mine;

  @override
  int get group => 1;

  @override
  DateTime get createdAt => post.createdAt;
}

class _ProposalJourney extends _Journey {
  const _ProposalJourney(this.proposal);

  final ProposalCard proposal;

  @override
  int get group => 1;

  @override
  DateTime get createdAt => proposal.createdAt;
}

class MyActivitiesPageState extends State<MyActivitiesPage> {
  List<_Journey> _journeys = <_Journey>[];
  bool _loaded = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _poll();
    if (AppEnv.useRemoteApi) {
      // API mode: the peer acts from another device; poll for changes.
      _pollTimer =
          Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    }
  }

  /// Called by the shell when the tab comes back into view.
  void reload() => _poll();

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final String myId = AuthSession.currentUserId;
    final bool isHost = AuthSession.isHost;
    try {
      final (
        List<LiveOrder>,
        List<ActivityPost>,
        List<ProposalCard>,
        List<ActivityPost>,
      ) r = await (
        widget.ordersRepository.listMine(),
        isHost
            ? Future<List<ActivityPost>>.value(const <ActivityPost>[])
            : widget.communityRepository.fetchPostsByAuthor(myId),
        isHost
            ? widget.hostsRepository.fetchProposals()
            : Future<List<ProposalCard>>.value(const <ProposalCard>[]),
        isHost
            ? widget.communityRepository.fetchAppliedRequests()
            : Future<List<ActivityPost>>.value(const <ActivityPost>[]),
      ).wait;
      if (!mounted) {
        return;
      }
      final List<_Journey> journeys = <_Journey>[
        // Deals (paid and recent finished) — the conversations view
        // already excludes unpaid and cancelled orders.
        ...r.$1.map(_OrderJourney.new),
        // My open posts, waiting for signups. Posts with a live deal are
        // already represented by their order card.
        ...r.$2
            .where((ActivityPost p) => !p.isMoment && p.status == 'OPEN')
            .map((ActivityPost p) => _PostJourney(p, mine: true)),
        // My open pitches with their invite queues (hosts).
        ...r.$3
            .where((ProposalCard p) => p.hostId == myId && p.isOpen)
            .map(_ProposalJourney.new),
        // Posts I signed up for, waiting for the poster to pick (hosts).
        ...r.$4.map((ActivityPost p) => _PostJourney(p, mine: false)),
      ];
      journeys.sort((_Journey a, _Journey b) {
        final int byGroup = a.group.compareTo(b.group);
        if (byGroup != 0) {
          return byGroup;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      setState(() {
        _journeys = journeys;
        _loaded = true;
      });
    } on Exception {
      // Keep the last known board; the next poll retries.
    }
  }

  Future<void> _openOrder(LiveOrder order) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderRoomPage(
          repository: widget.ordersRepository,
          orderId: order.id,
          initialOrder: order,
        ),
      ),
    );
    unawaited(_poll());
  }

  Future<void> _openPost(ActivityPost post) async {
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
    unawaited(_poll());
  }

  Future<void> _openProposal(ProposalCard proposal) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProposalDetailPage(
          proposal: proposal,
          hostsRepository: widget.hostsRepository,
          profileRepository: widget.profileRepository,
        ),
      ),
    );
    unawaited(_poll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(AppStrings.tabMyActivities),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _journeys.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      AppStrings.myActivitiesEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _poll,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                    itemCount: _journeys.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      return switch (_journeys[index]) {
                        final _OrderJourney j => _OrderCard(
                            order: j.order,
                            onTap: () => _openOrder(j.order),
                          ),
                        final _PostJourney j => _WaitingCard(
                            key: ValueKey<String>('myActivity-${j.post.id}'),
                            icon: j.mine
                                ? Iconsax.calendar_1
                                : Iconsax.send_2,
                            title: j.post.title,
                            statusLine: j.mine
                                ? (j.post.signedCount > 0
                                    ? AppStrings
                                        .appliedCount(j.post.signedCount)
                                    : AppStrings.activityWaitingSignups)
                                : AppStrings.activityAwaitingSelection,
                            highlighted:
                                j.mine && j.post.signedCount > 0,
                            onTap: () => _openPost(j.post),
                          ),
                        final _ProposalJourney j => _WaitingCard(
                            key: ValueKey<String>(
                              'myActivity-${j.proposal.id}',
                            ),
                            icon: Iconsax.magic_star,
                            title: j.proposal.title,
                            statusLine: j.proposal.inviteCount > 0
                                ? AppStrings
                                    .activityInvites(j.proposal.inviteCount)
                                : AppStrings.activityWaitingInvites,
                            highlighted: j.proposal.inviteCount > 0,
                            onTap: () => _openProposal(j.proposal),
                          ),
                      };
                    },
                  ),
                ),
    );
  }
}

/// A formed deal: the peer fronts the card and the tap goes straight to
/// the chat room (read-only once closed).
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final LiveOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PostAuthor peer = order.peerOf(AuthSession.currentUserId);
    final bool active = order.status == 'ACTIVE';
    final String eventLine = <String>[
      order.postTitle,
      if (order.planPlace.isNotEmpty) order.planPlace,
    ].where((String s) => s.isNotEmpty).join(' \u00b7 ');
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey<String>('myActivity-${order.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: <Widget>[
              AppAvatar(
                size: 44,
                imageUrl: peer.avatarUrl,
                fallbackLetter: peer.name.isEmpty ? '?' : peer.name[0],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      peer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (eventLine.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        eventLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                active
                    ? AppStrings.statusActive
                    : AppStrings.statusCompleted,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color:
                      active ? AppColors.accent : AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A journey still waiting on the market: my post collecting signups, my
/// pitch collecting invites, or my signup waiting for selection.
class _WaitingCard extends StatelessWidget {
  const _WaitingCard({
    super.key,
    required this.icon,
    required this.title,
    required this.statusLine,
    required this.highlighted,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String statusLine;

  /// true when something is waiting for the owner (signups/invites
  /// arrived), coloring the status line as a call to action.
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      statusLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            highlighted ? FontWeight.w600 : FontWeight.w400,
                        color: highlighted
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Iconsax.arrow_right_3,
                size: 16,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
