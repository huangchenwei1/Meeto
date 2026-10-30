import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/env/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../community/data/community_repository.dart';
import '../../community/models/activity_post.dart';
import '../../community/pages/post_detail_page.dart';
import '../../hosts/data/hosts_repository.dart';
import '../../hosts/models/host_card.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/models/live_order.dart';
import '../../orders/pages/order_room_page.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/models/user_detail.dart';

/// Host-side first tab: the work surface. Lists direct invitations for the
/// host plus all OPEN activity requests as gigs to pitch on — net earnings,
/// competition, and the pitch entry. The community wall stays read-only;
/// hosts take work from here.
class GigsPage extends StatefulWidget {
  const GigsPage({
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
  State<GigsPage> createState() => GigsPageState();
}

class GigsPageState extends State<GigsPage> {
  List<ActivityPost> _requests = <ActivityPost>[];
  List<InvitationRecord> _pendingInvitations = <InvitationRecord>[];
  List<String> _myTags = const <String>[];
  bool _loaded = false;
  bool _respondingInvitation = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMyTags();
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

  Future<void> _loadMyTags() async {
    try {
      final UserDetail? me = await widget.profileRepository
          .fetchUserDetail(AuthSession.currentUserId);
      if (mounted && me != null) {
        setState(() => _myTags = me.tags);
      }
    } on Exception {
      // Tag-based ordering is a nicety; recency ordering still works.
    }
  }

  Future<void> _load() async {
    try {
      final (List<ActivityPost>, List<InvitationRecord>) result = await (
        widget.communityRepository.fetchOpenRequests(),
        widget.hostsRepository.fetchInvitations(),
      ).wait;
      if (!mounted) {
        return;
      }
      setState(() {
        _requests = _workView(result.$1);
        _pendingInvitations = result.$2
            .where((InvitationRecord i) => i.isPending)
            .toList(growable: false);
        _loaded = true;
      });
    } on Exception {
      // Keep the last known list; pull-to-refresh or the next poll retries.
    }
  }

  /// Requests matching the host's own interest tags come first, newest
  /// first within each group.
  List<ActivityPost> _workView(List<ActivityPost> posts) {
    final List<ActivityPost> open = posts.toList();
    int group(ActivityPost p) => _myTags.contains(p.sceneTag) ? 0 : 1;
    open.sort((ActivityPost a, ActivityPost b) {
      final int byTag = group(a).compareTo(group(b));
      if (byTag != 0) {
        return byTag;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return open;
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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(AppStrings.gigsTitle),
            Text(
              AppStrings.gigsSubtitle,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _pendingInvitations.isEmpty && _requests.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const <Widget>[
                        Padding(
                          padding: EdgeInsets.only(top: 120),
                          child: Center(
                            child: Text(
                              AppStrings.gigsEmpty,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: <Widget>[
                        if (_pendingInvitations.isNotEmpty) ...<Widget>[
                          const _SectionHeader(
                            label: AppStrings.gigsInvitesHeader,
                          ),
                          for (final InvitationRecord invitation
                              in _pendingInvitations)
                            _InvitationCard(
                              invitation: invitation,
                              busy: _respondingInvitation,
                              onAccept: () => _acceptInvitation(invitation),
                              onDecline: () => _declineInvitation(invitation),
                            ),
                          const SizedBox(height: 12),
                        ],
                        if (_requests.isNotEmpty) ...<Widget>[
                          const _SectionHeader(
                            label: AppStrings.gigsRequestsHeader,
                          ),
                          for (final ActivityPost post in _requests)
                            _RequestCard(
                              post: post,
                              onTap: () => _openRequest(post),
                            ),
                        ],
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
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
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

/// One open request in the work view: what the activity is, who posted it,
/// what the host nets, and how crowded the pitch pool already is.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.post, required this.onTap});

  final ActivityPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int net = ScenePricing.netEarnings(post.budgetAmount);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        post.sceneTag,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (post.signedCount > 0)
                      Text(
                        AppStrings.appliedCount(post.signedCount),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  post.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    AppAvatar(
                      size: 22,
                      imageUrl: post.author.avatarUrl,
                      fallbackLetter:
                          post.author.name.isEmpty ? '?' : post.author.name[0],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${post.author.name} \u00b7 ${post.timeText}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Text(
                      AppStrings.gigEarnLine('\u20b1$net'),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                    const Spacer(),
                    if (post.hasApplied)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          AppStrings.gigAppliedBadge,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      Row(
                        children: <Widget>[
                          const Text(
                            AppStrings.gigPitchCta,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: AppColors.textPrimary,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
                    invitation.sceneTag,
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
