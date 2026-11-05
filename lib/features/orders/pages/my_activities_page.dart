import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/env/app_env.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_network_image.dart';
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

/// My Activities filter identifiers (display labels live in [AppStrings]).
const String _filterAll = 'ALL';
const String _filterWaiting = 'WAITING';
const String _filterActive = 'ACTIVE';
const String _filterDone = 'DONE';

/// Tab 3: the My Activities board — the order page folded into the tab.
/// One big order-style card per activity journey, filterable by stage:
/// - 待加入 (waiting): my open post collecting signups, my open pitch
///   collecting invites, a post I signed up for awaiting selection
/// - 进行中 (active): formed deals; the card opens the chat room
/// - 已完成 (done): finished deals, reviewable forever
/// Deliberately no awaiting-payment or cancelled entries — unpaid deals
/// finish (or expire) where they were formed, dead deals disappear.
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

/// One entry on the board. [group] drives the all-view sort: running
/// deals first, then everything still waiting, finished deals last.
sealed class _Journey {
  const _Journey();

  int get group;
  DateTime get createdAt;
}

class _OrderJourney extends _Journey {
  const _OrderJourney(this.order);

  final LiveOrder order;

  bool get active => order.status == 'ACTIVE';

  @override
  int get group => active ? 0 : 2;

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
  String _filter = _filterAll;
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
        widget.ordersRepository.listMine(all: true),
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
        // Formed deals only: unpaid and cancelled orders stay off the
        // board on purpose.
        ...r.$1
            .where(
              (LiveOrder o) =>
                  o.status == 'ACTIVE' || o.status == 'COMPLETED',
            )
            .map(_OrderJourney.new),
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

  List<_Journey> get _visible => switch (_filter) {
        _filterWaiting =>
          _journeys.where((_Journey j) => j.group == 1).toList(),
        _filterActive => _journeys
            .where((_Journey j) => j is _OrderJourney && j.active)
            .toList(),
        _filterDone => _journeys
            .where((_Journey j) => j is _OrderJourney && !j.active)
            .toList(),
        _ => _journeys,
      };

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
    final List<_Journey> visible = _visible;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(AppStrings.tabMyActivities),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(
              children: <Widget>[
                for (final (String id, String label)
                    in <(String, String)>[
                  (_filterAll, AppStrings.activityFilterAll),
                  (_filterWaiting, AppStrings.activityFilterWaiting),
                  (_filterActive, AppStrings.statusActive),
                  (_filterDone, AppStrings.statusCompleted),
                ]) ...<Widget>[
                  _FilterChip(
                    key: ValueKey<String>('activityFilter$id'),
                    label: label,
                    selected: _filter == id,
                    onTap: () => setState(() => _filter = id),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
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
                          padding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 20),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int index) {
                            return switch (visible[index]) {
                              final _OrderJourney j => _OrderCard(
                                  order: j.order,
                                  onTap: () => _openOrder(j.order),
                                ),
                              final _PostJourney j => _WaitingCard(
                                  cardKey: 'myActivity-${j.post.id}',
                                  typeLabel: j.mine
                                      ? AppStrings.activityMinePostLabel
                                      : AppStrings.activityAppliedLabel,
                                  imageUrl: j.post.imageUrl,
                                  icon: j.mine
                                      ? Iconsax.calendar_add
                                      : Iconsax.send_2,
                                  title: j.post.title,
                                  infoLine: <String>[
                                    AppStrings.sceneLabel(j.post.sceneTag),
                                    if (j.post.timeSlot.isNotEmpty)
                                      AppStrings
                                          .timeSlotLabel(j.post.timeSlot),
                                    if (j.post.area.isNotEmpty) j.post.area,
                                  ].join(' \u00b7 '),
                                  amount: j.post.budgetAmount,
                                  statusLine: j.mine
                                      ? (j.post.signedCount > 0
                                          ? AppStrings.appliedCount(
                                              j.post.signedCount,
                                            )
                                          : AppStrings
                                              .activityWaitingSignups)
                                      : AppStrings
                                          .activityAwaitingSelection,
                                  highlighted:
                                      j.mine && j.post.signedCount > 0,
                                  actionLabel:
                                      j.mine && j.post.signedCount > 0
                                          ? AppStrings.activityPickCta
                                          : null,
                                  createdAt: j.post.createdAt,
                                  onTap: () => _openPost(j.post),
                                ),
                              final _ProposalJourney j => _WaitingCard(
                                  cardKey: 'myActivity-${j.proposal.id}',
                                  typeLabel:
                                      AppStrings.activityProposalLabel,
                                  imageUrl: j.proposal.coverImageUrl,
                                  icon: Iconsax.magic_star,
                                  title: j.proposal.title,
                                  infoLine: <String>[
                                    AppStrings
                                        .sceneLabel(j.proposal.sceneTag),
                                    if (j.proposal.timeSlot.isNotEmpty)
                                      AppStrings.timeSlotLabel(
                                        j.proposal.timeSlot,
                                      ),
                                    if (j.proposal.area.isNotEmpty)
                                      j.proposal.area,
                                  ].join(' \u00b7 '),
                                  amount: j.proposal.budgetAmount,
                                  statusLine: j.proposal.inviteCount > 0
                                      ? AppStrings.activityInvites(
                                          j.proposal.inviteCount,
                                        )
                                      : AppStrings.activityWaitingInvites,
                                  highlighted: j.proposal.inviteCount > 0,
                                  actionLabel: j.proposal.inviteCount > 0
                                      ? AppStrings.activityInvitesCta
                                      : null,
                                  createdAt: j.proposal.createdAt,
                                  onTap: () => _openProposal(j.proposal),
                                ),
                            };
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkCard : AppColors.background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected
                ? AppColors.onDarkPrimary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// A formed deal as a service-purchase card: provider line + status in
/// the header, the service item (activity + locked plan + price) as the
/// body, order time + total + the stage's action in the footer. Tap (or
/// the pill) opens the chat room, read-only once closed.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final LiveOrder order;
  final VoidCallback onTap;

  bool get _iAmPayer => order.isPayer(AuthSession.currentUserId);
  bool get _active => order.status == 'ACTIVE';

  String _whenLine(BuildContext context) {
    if (order.planAt == null) {
      return '';
    }
    final MaterialLocalizations loc = MaterialLocalizations.of(context);
    final DateTime local = order.planAt!.toLocal();
    final String when = '${loc.formatShortDate(local)} '
        '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
    return order.planDurationMinutes > 0
        ? '$when \u00b7 ${AppStrings.durationAbout(order.planDurationMinutes)}'
        : when;
  }

  String _createdLine(BuildContext context) {
    final MaterialLocalizations loc = MaterialLocalizations.of(context);
    final DateTime local = order.createdAt.toLocal();
    return AppStrings.myOrderCreatedAt(
      '${loc.formatShortDate(local)} '
      '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final PostAuthor peer = order.peerOf(AuthSession.currentUserId);
    final String fee = MoneyFormat.format(order.feePesos);
    final String whenLine = _whenLine(context);
    // The merchant line: the one providing or ordering the service, never
    // the item being sold.
    final String providerLine = _iAmPayer
        ? AppStrings.myOrderHostLine(peer.name)
        : AppStrings.myOrderGuestLine(peer.name);
    return _BigCard(
      cardKey: 'myActivity-${order.id}',
      onTap: onTap,
      header: Row(
        children: <Widget>[
          AppAvatar(
            size: 22,
            imageUrl: peer.avatarUrl,
            fallbackLetter: peer.name.isEmpty ? '?' : peer.name[0],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              providerLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _active ? AppStrings.statusActive : AppStrings.statusCompleted,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _active ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
        ],
      ),
      imageUrl: order.postImageUrl,
      icon: Iconsax.calendar_1,
      title: order.postTitle,
      lines: <String>[
        if (order.planPlace.isNotEmpty) order.planPlace,
        if (whenLine.isNotEmpty) whenLine,
      ],
      amount: fee,
      footerLeft: _createdLine(context),
      footerRight: Text.rich(
        TextSpan(
          text: AppStrings.myOrderTotal(''),
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
          children: <InlineSpan>[
            TextSpan(
              text: fee,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      action: _Pill(
        pillKey: 'myActivityAction-${order.id}',
        label: _active
            ? AppStrings.myOrderChatCta
            : AppStrings.myOrderDetailCta,
        primary: _active,
        onTap: onTap,
      ),
    );
  }
}

/// A journey still waiting on the market: my post collecting signups, my
/// pitch collecting invites, or my signup waiting for selection. The
/// header names the journey type, the status rides on the right, and an
/// action pill appears only when something actually arrived to act on.
class _WaitingCard extends StatelessWidget {
  const _WaitingCard({
    required this.cardKey,
    required this.typeLabel,
    required this.imageUrl,
    required this.icon,
    required this.title,
    required this.infoLine,
    required this.amount,
    required this.statusLine,
    required this.highlighted,
    required this.actionLabel,
    required this.createdAt,
    required this.onTap,
  });

  final String cardKey;

  /// The journey kind fronting the header (my post / my signup / my pitch).
  final String typeLabel;
  final String imageUrl;
  final IconData icon;
  final String title;
  final String infoLine;
  final int amount;
  final String statusLine;

  /// true when something arrived for the owner (signups/invites),
  /// coloring the status as a call to action.
  final bool highlighted;

  /// Pill label when the status demands action; null hides the pill
  /// (the whole card stays tappable).
  final String? actionLabel;
  final DateTime createdAt;
  final VoidCallback onTap;

  String _postedLine(BuildContext context) {
    final MaterialLocalizations loc = MaterialLocalizations.of(context);
    final DateTime local = createdAt.toLocal();
    return AppStrings.activityPostedAt(
      '${loc.formatShortDate(local)} '
      '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? label = actionLabel;
    return _BigCard(
      cardKey: cardKey,
      onTap: onTap,
      header: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              typeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            statusLine,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: highlighted
                  ? AppColors.accent
                  : const Color(0xFFD97706),
            ),
          ),
        ],
      ),
      imageUrl: imageUrl,
      icon: icon,
      title: title,
      lines: <String>[if (infoLine.isNotEmpty) infoLine],
      amount: MoneyFormat.format(amount),
      footerLeft: _postedLine(context),
      footerRight: null,
      action: label == null
          ? null
          : _Pill(
              pillKey: '$cardKey-open',
              label: label,
              primary: true,
              onTap: onTap,
            ),
    );
  }
}

/// The shared big-card skeleton: header row, divider, service-item body
/// (cover image + title + info lines + amount), footer row + action pill.
class _BigCard extends StatelessWidget {
  const _BigCard({
    required this.cardKey,
    required this.onTap,
    required this.header,
    required this.imageUrl,
    required this.icon,
    required this.title,
    required this.lines,
    required this.amount,
    required this.footerLeft,
    required this.footerRight,
    required this.action,
  });

  final String cardKey;
  final VoidCallback onTap;
  final Widget header;

  /// The activity's cover; [icon] is the fallback tile for entries
  /// without one (e.g. legacy orders).
  final String imageUrl;
  final IconData icon;
  final String title;
  final List<String> lines;
  final String amount;
  final String footerLeft;
  final Widget? footerRight;

  /// The stage's action pill; null when the card has nothing to push
  /// (the whole card is tappable regardless).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey<String>(cardKey),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              header,
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AppNetworkImage(
                        url: imageUrl,
                        width: 48,
                        height: 48,
                      ),
                    )
                  else
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 22, color: AppColors.accent),
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
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        for (final String line in lines) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            line,
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
                    amount,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      footerLeft,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                  ?footerRight,
                ],
              ),
              if (action != null) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[action!],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.pillKey,
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String pillKey;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        key: ValueKey<String>(pillKey),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor:
              primary ? AppColors.background : AppColors.textSecondary,
          backgroundColor: primary ? AppColors.darkCard : null,
          side: primary
              ? BorderSide.none
              : const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
