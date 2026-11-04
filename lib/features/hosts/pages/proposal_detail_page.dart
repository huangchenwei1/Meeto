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
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/models/live_order.dart';
import '../../orders/pages/order_room_page.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/pages/user_profile_page.dart';
import '../data/hosts_repository.dart';
import '../models/host_card.dart';
import '../models/proposal_card.dart';
import '../widgets/invite_flow.dart';
import 'host_detail_page.dart';

/// Full-screen proposal detail — the exact mirror of the activity post
/// detail on the demand side.
///
/// Two viewpoints:
/// - Someone else's open pitch (user viewer): the locked price plus the
///   invite CTA; several users can queue on the same pitch.
/// - The host's own pitch: the live invite pool; picking one inviter
///   creates the order awaiting that inviter's payment.
class ProposalDetailPage extends StatefulWidget {
  const ProposalDetailPage({
    super.key,
    required this.proposal,
    required this.hostsRepository,
    required this.profileRepository,
    required this.ordersRepository,
  });

  final ProposalCard proposal;
  final HostsRepository hostsRepository;
  final ProfileRepository profileRepository;
  final OrdersRepository ordersRepository;

  @override
  State<ProposalDetailPage> createState() => _ProposalDetailPageState();
}

class _ProposalDetailPageState extends State<ProposalDetailPage> {
  late ProposalCard _proposal = widget.proposal;
  List<InvitationRecord> _invites = <InvitationRecord>[];
  bool _selecting = false;
  Timer? _pollTimer;

  bool get _isMine => _proposal.hostId == AuthSession.currentUserId;

  @override
  void initState() {
    super.initState();
    _load();
    // The invite pool is the host's main waiting surface, so it polls
    // like the hall does.
    if (AppEnv.useRemoteApi) {
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final ProposalCard proposal =
          await widget.hostsRepository.fetchProposal(_proposal.id);
      final List<InvitationRecord> invites = _isMine
          ? await widget.hostsRepository.fetchProposalInvites(_proposal.id)
          : const <InvitationRecord>[];
      if (mounted) {
        setState(() {
          _proposal = proposal;
          _invites = invites;
        });
      }
    } on Exception {
      // Keep the last known state; the next poll retries.
    }
  }

  Future<void> _invite() async {
    final bool sent = await runInviteFlow(
      context,
      repository: widget.hostsRepository,
      proposal: _proposal,
    );
    if (sent && mounted) {
      setState(() => _proposal = _proposal.copyWith(hasInvited: true));
      unawaited(_load());
    }
  }

  /// The host picks one inviter: the server creates the order awaiting
  /// that inviter's payment, and the pitch leaves the market.
  Future<void> _select(InvitationRecord invitation) async {
    if (_selecting) {
      return;
    }
    setState(() => _selecting = true);
    try {
      final LiveOrder? order = await widget.hostsRepository.selectInvite(
        _proposal.id,
        invitation.id,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.selectInviterDoneSnack)),
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
        setState(() => _selecting = false);
      }
    }
  }

  void _openHost() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HostDetailPage(
          repository: widget.hostsRepository,
          hostId: _proposal.hostId,
        ),
      ),
    );
  }

  /// Screening inviters is screening people: tapping a row opens the
  /// inviter's full profile.
  void _openInviterProfile(InvitationRecord invitation) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfilePage(
          userId: invitation.fromId,
          profileRepository: widget.profileRepository,
        ),
      ),
    );
  }

  String get _infoLine => <String>[
        if (_proposal.timeSlot.isNotEmpty)
          AppStrings.timeSlotLabel(_proposal.timeSlot),
        if (_proposal.locationLine.isNotEmpty) _proposal.locationLine,
        if (_proposal.inviteCount > 0)
          AppStrings.proposalInviteCount(_proposal.inviteCount),
      ].join(' \u00b7 ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: _BackButton(onTap: () => Navigator.of(context).pop()),
            flexibleSpace: FlexibleSpaceBar(
              background: AppNetworkImage(url: _proposal.coverImageUrl),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
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
                          AppStrings.sceneLabel(_proposal.sceneTag),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      if (!_proposal.isOpen) ...<Widget>[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.otherMessageBubble,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            AppStrings.proposalNotOpenSnack,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _proposal.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_proposal.description.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      _proposal.description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (_infoLine.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Iconsax.location,
                          size: 15,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _infoLine,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (_isMine) ...<Widget>[
                    _InvitesSection(
                      invites: _invites,
                      busy: _selecting,
                      onSelect: _select,
                      onOpenProfile: _openInviterProfile,
                    ),
                    const SizedBox(height: 14),
                  ] else ...<Widget>[
                    _HostCardTile(proposal: _proposal, onTap: _openHost),
                    const SizedBox(height: 14),
                  ],
                  const _SafetyNote(),
                ],
              ),
            ),
          ),
        ],
      ),
      // Inviting is a user action on open pitches; the host owner and
      // host browsers get no transactional bar.
      bottomNavigationBar:
          !_isMine && !AuthSession.isHost && _proposal.isOpen
              ? _InviteBottomBar(
                  proposal: _proposal,
                  onInvite: _invite,
                )
              : null,
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.92),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Iconsax.arrow_left_2,
            size: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Live invite pool shown to the pitch's host, with a pick action per
/// inviter — the mirror of the candidate pool on a demand post.
class _InvitesSection extends StatelessWidget {
  const _InvitesSection({
    required this.invites,
    required this.busy,
    required this.onSelect,
    required this.onOpenProfile,
  });

  final List<InvitationRecord> invites;
  final bool busy;
  final ValueChanged<InvitationRecord> onSelect;
  final ValueChanged<InvitationRecord> onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            AppStrings.proposalInvitesTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if (invites.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                AppStrings.proposalInvitesEmpty,
                style: TextStyle(fontSize: 12.5, color: AppColors.textHint),
              ),
            )
          else
            Column(
              children: <Widget>[
                for (int i = 0; i < invites.length; i++) ...<Widget>[
                  if (i > 0) const Divider(),
                  _InviteRow(
                    invitation: invites[i],
                    busy: busy,
                    onSelect: () => onSelect(invites[i]),
                    onTap: () => onOpenProfile(invites[i]),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.invitation,
    required this.busy,
    required this.onSelect,
    required this.onTap,
  });

  final InvitationRecord invitation;
  final bool busy;
  final VoidCallback onSelect;

  /// Opens the inviter's full profile: picking an inviter is picking a
  /// person, not just a note.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey<String>('inviteRow-${invitation.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppAvatar(size: 42, imageUrl: invitation.fromAvatarUrl),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        invitation.fromName,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (invitation.fromVerified) const VerifiedBadge(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    invitation.fromMeta,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                  if (invitation.note.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
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
                ],
              ),
            ),
            SizedBox(
              height: 32,
              child: FilledButton(
                key: ValueKey<String>('selectInvite-${invitation.id}'),
                onPressed: busy ? null : onSelect,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.onDarkPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text(AppStrings.approveCta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The host's signature card: tapping it opens the full host profile.
class _HostCardTile extends StatelessWidget {
  const _HostCardTile({required this.proposal, required this.onTap});

  final ProposalCard proposal;
  final VoidCallback onTap;

  String get _metaLine {
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
      key: const ValueKey<String>('proposalHostCard'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            AppAvatar(size: 46, imageUrl: proposal.hostAvatarUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        proposal.hostName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (proposal.hostIsVerified) const VerifiedBadge(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _metaLine,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Iconsax.arrow_right_3,
              size: 18,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const <Widget>[
          Icon(Iconsax.shield_tick, size: 17, color: AppColors.accent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.safetyNotice,
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom bar for a user viewing someone else's open pitch: the locked
/// price they would pay, plus the invite CTA (disabled once queued).
class _InviteBottomBar extends StatelessWidget {
  const _InviteBottomBar({required this.proposal, required this.onInvite});

  final ProposalCard proposal;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  AppStrings.tipPayLabel,
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
                const SizedBox(height: 2),
                Text(
                  MoneyFormat.format(proposal.budgetAmount),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            key: const ValueKey<String>('proposalInviteButton'),
            onPressed: proposal.hasInvited ? null : onInvite,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.onDarkPrimary,
              disabledBackgroundColor: AppColors.textPrimary.withValues(
                alpha: 0.55,
              ),
              disabledForegroundColor: AppColors.onDarkPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 14,
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(
              proposal.hasInvited
                  ? AppStrings.invitedBadge
                  : AppStrings.hostInviteCta,
            ),
          ),
        ],
      ),
    );
  }
}
