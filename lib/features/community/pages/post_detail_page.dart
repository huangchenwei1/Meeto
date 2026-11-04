import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/models/live_order.dart';
import '../../orders/pages/order_room_page.dart';
import '../../orders/widgets/pay_sheet.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/pages/user_profile_page.dart';
import 'signup_plan_page.dart';
import '../data/community_repository.dart';
import '../models/activity_post.dart';
import '../models/post_author.dart';
import '../../../core/network/api_client.dart';
import '../../auth/pages/verification_page.dart';

/// Full-screen activity post detail.
///
/// Two viewpoints:
/// - Someone else's open request (host viewer): sign up with a plan pitch
///   and see the expected net earnings (fee minus platform commission).
/// - The current user's own post: shows the live candidate pool; approving
///   one plan creates the escrow order and opens the payment + order room.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.post,
    required this.communityRepository,
    required this.profileRepository,
    required this.ordersRepository,
  });

  final ActivityPost post;
  final CommunityRepository communityRepository;
  final ProfileRepository profileRepository;
  final OrdersRepository ordersRepository;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late ActivityPost _post = widget.post;
  late bool _signedUp = widget.post.hasApplied;
  bool _approving = false;

  bool get _isMine => _post.author.id == AuthSession.currentUserId;

  /// Collects the pitch plus the plan card (place + time + duration), then
  /// signs up. If the poster selects this candidate, the plan is approved
  /// in the same tap and the order starts ready to chat once paid.
  Future<void> _signUp() async {
    final (String, String, DateTime, int)? card = await _askProposal();
    if (card == null || !mounted) {
      return;
    }
    await _signUpWith(card);
  }

  Future<(String, String, DateTime, int)?> _askProposal() {
    // A formal full-screen composer, not a casual bottom sheet. Pops
    // (proposal, place, scheduledAt, durationMinutes).
    return Navigator.of(context).push<(String, String, DateTime, int)>(
      MaterialPageRoute<(String, String, DateTime, int)>(
        fullscreenDialog: true,
        builder: (_) => const SignUpPlanPage(),
      ),
    );
  }

  Future<void> _signUpWith((String, String, DateTime, int) card) async {
    setState(() => _signedUp = true);
    final ActivityPost updated;
    try {
      updated = await widget.communityRepository.signUp(
        _post.id,
        card.$1,
        place: card.$2,
        scheduledAt: card.$3,
        durationMinutes: card.$4,
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      // Revert the optimistic sign-up state before handling the error.
      setState(() => _signedUp = false);
      if (e.verificationRequired) {
        final bool verified = await promptVerification(context);
        if (verified && mounted) {
          return _signUpWith(card);
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _post = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.candidateSignedUpSnack)),
    );
    // If the poster selects this host, the order appears in the Messages
    // tab (orders list) within a poll cycle.
  }

  /// Selection and payment are one gesture: approving a candidate creates
  /// the escrow order and the pay sheet opens on the spot. Only a paid
  /// order opens the conversation; a dismissed sheet leaves the order in
  /// My Orders (it auto-cancels when the pay window runs out).
  Future<void> _approveCandidate(PostAuthor candidate) async {
    if (_approving) {
      return;
    }
    setState(() => _approving = true);
    await widget.communityRepository.selectCandidate(_post.id, candidate.id);

    final LiveOrder? order =
        await widget.ordersRepository.findByPostId(_post.id);
    if (!mounted) {
      return;
    }
    setState(() => _approving = false);
    LiveOrder? paid;
    if (order != null &&
        order.isPayer(AuthSession.currentUserId) &&
        order.status == 'AWAITING_PAYMENT') {
      paid = await showPaySheet(
        context,
        repository: widget.ordersRepository,
        order: order,
      );
    }
    if (!mounted) {
      return;
    }
    if (paid != null) {
      final LiveOrder opened = paid;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OrderRoomPage(
            repository: widget.ordersRepository,
            orderId: opened.id,
            initialOrder: opened,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.paymentLaterSnack)),
      );
    }
  }

  void _openAuthor() => _openProfile(_post.author.id);

  /// Screening candidates is really screening people: tapping a candidate
  /// row opens their full profile.
  void _openProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfilePage(
          userId: userId,
          profileRepository: widget.profileRepository,
        ),
      ),
    );
  }

  Future<void> _showOwnerActions() async {
    final bool? requested = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 8),
            ListTile(
              leading:
                  const Icon(Iconsax.trash, color: Colors.redAccent, size: 20),
              title: const Text(
                AppStrings.deletePostCta,
                style: TextStyle(color: Colors.redAccent, fontSize: 15),
              ),
              onTap: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!(requested ?? false) || !mounted) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(AppStrings.deletePostConfirmTitle),
        content: const Text(AppStrings.deletePostConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.deletePostNo),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              AppStrings.deletePostYes,
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) {
      return;
    }
    try {
      await widget.communityRepository.deletePost(_post.id);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.deletePostDone)),
      );
      Navigator.of(context).pop(true);
    }
  }

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
            actions: <Widget>[
              if (_isMine)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _MoreButton(onTap: _showOwnerActions),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: AppNetworkImage(url: _post.imageUrl),
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
                          AppStrings.sceneLabel(_post.sceneTag),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _post.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _post.detail,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.7,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_isMine) ...<Widget>[
                    _CandidatesSection(
                      candidatesStream: widget.communityRepository
                          .watchCandidates(_post.id),
                      onApprove: _approveCandidate,
                      onOpenProfile: (PostAuthor c) => _openProfile(c.id),
                    ),
                    const SizedBox(height: 14),
                  ],
                  // No time/place card: the host proposes the concrete
                  // plan in the order room after matching.
                  if (!_isMine)
                    _AuthorCard(post: _post, onTap: _openAuthor),
                  const SizedBox(height: 14),
                  const _SafetyNote(),
                ],
              ),
            ),
          ),
        ],
      ),
      // Sign-up is a host action on posts still waiting for a host: users
      // viewing someone else's post get no transactional bar (they invite
      // hosts from the directory instead), and in-progress activities are
      // read-only for everyone but the poster.
      bottomNavigationBar: _isMine
          ? _PosterBottomBar(post: _post)
          : AuthSession.isHost && _post.status == 'OPEN'
              ? _CandidateBottomBar(
                  post: _post,
                  signedUp: _signedUp,
                  onSignUp: _signUp,
                )
              : null,
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onTap});

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
            Iconsax.more,
            size: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
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

/// Live candidate pool shown to the poster, with an approve action per
/// candidate.
class _CandidatesSection extends StatelessWidget {
  const _CandidatesSection({
    required this.candidatesStream,
    required this.onApprove,
    required this.onOpenProfile,
  });

  final Stream<List<PostAuthor>> candidatesStream;
  final ValueChanged<PostAuthor> onApprove;
  final ValueChanged<PostAuthor> onOpenProfile;

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
            AppStrings.candidatesTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<PostAuthor>>(
            stream: candidatesStream,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<PostAuthor>> snapshot,
                ) {
                  final List<PostAuthor> candidates =
                      snapshot.data ?? const <PostAuthor>[];
                  if (candidates.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        AppStrings.candidatesEmpty,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textHint,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: <Widget>[
                      for (int i = 0; i < candidates.length; i++) ...<Widget>[
                        if (i > 0) const Divider(),
                        _CandidateRow(
                          candidate: candidates[i],
                          onApprove: () => onApprove(candidates[i]),
                          onTap: () => onOpenProfile(candidates[i]),
                        ),
                      ],
                    ],
                  );
                },
          ),
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.onApprove,
    required this.onTap,
  });

  final PostAuthor candidate;
  final VoidCallback onApprove;

  /// Opens the candidate's full profile: picking a host is picking a
  /// person, not just a plan.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey<String>('candidateRow-${candidate.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppAvatar(size: 42, imageUrl: candidate.avatarUrl),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      candidate.name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (candidate.isVerified) const VerifiedBadge(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  candidate.meta,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
                if (candidate.planPlace.isNotEmpty &&
                    candidate.planAt != null) ...<Widget>[
                  const SizedBox(height: 4),
                  // The plan card: approved as-is when this candidate is
                  // selected.
                  Text(
                    candidate.planDurationMinutes > 0
                        ? '${candidate.planPlace} \u00b7 '
                            '${_formatPlanDateTime(context, candidate.planAt!)} \u00b7 '
                            '${AppStrings.durationAbout(candidate.planDurationMinutes)}'
                        : '${candidate.planPlace} \u00b7 '
                            '${_formatPlanDateTime(context, candidate.planAt!)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                if (candidate.proposal.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    '\u201c${candidate.proposal}\u201d',
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
              onPressed: onApprove,
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

class _AuthorCard extends StatelessWidget {
  const _AuthorCard({required this.post, required this.onTap});

  final ActivityPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
            AppAvatar(size: 46, imageUrl: post.author.avatarUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        post.author.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (post.author.isVerified) const VerifiedBadge(),
                    ],
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

/// Bottom bar for someone else's post: the viewer is a potential host, so
/// they see the net service fee they would receive + the sign-up CTA.
class _CandidateBottomBar extends StatelessWidget {
  const _CandidateBottomBar({
    required this.post,
    required this.signedUp,
    required this.onSignUp,
  });

  final ActivityPost post;
  final bool signedUp;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    final int amount = ScenePricing.netEarnings(post.budgetAmount);
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
                  AppStrings.tipReceiveLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  MoneyFormat.format(amount),
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
            onPressed: signedUp ? null : onSignUp,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.onDarkPrimary,
              disabledBackgroundColor: AppColors.textPrimary.withValues(
                alpha: 0.55,
              ),
              disabledForegroundColor: AppColors.onDarkPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(
              signedUp ? AppStrings.signedUpCta : AppStrings.signUpCta,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom bar for the current user's own post: the poster pays the full
/// service fee into escrow when they approve a host.
class _PosterBottomBar extends StatelessWidget {
  const _PosterBottomBar({required this.post});

  final ActivityPost post;

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
                Row(
                  children: <Widget>[
                    const Text(
                      AppStrings.tipPayLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      MoneyFormat.format(post.budgetAmount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  AppStrings.tipPayNote,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatPlanDateTime(BuildContext context, DateTime at) {
  final MaterialLocalizations loc = MaterialLocalizations.of(context);
  final DateTime local = at.toLocal();
  return '${loc.formatShortDate(local)} \u00b7 '
      '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
