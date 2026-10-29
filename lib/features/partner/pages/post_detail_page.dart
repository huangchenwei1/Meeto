import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/pages/chat_detail_page.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/models/live_order.dart';
import '../../orders/pages/order_room_page.dart';
import '../../orders/pages/payment_page.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/pages/user_profile_page.dart';
import '../data/partner_repository.dart';
import '../models/date_post.dart';
import '../models/post_author.dart';
import '../../../core/network/api_client.dart';
import '../../auth/pages/verification_page.dart';

/// Full-screen date post detail.
///
/// Two viewpoints:
/// - Someone else's post: the current user signs up as a CANDIDATE for free
///   and sees the expected net earnings (fee minus platform commission).
/// - The current user's own post: shows the live candidate pool; approving
///   one candidate triggers the (male) payer's escrow payment and opens the
///   new deal conversation.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.post,
    required this.partnerRepository,
    required this.chatRepository,
    required this.profileRepository,
    this.ordersRepository,
  });

  final DatePost post;
  final PartnerRepository partnerRepository;
  final ChatRepository chatRepository;
  final ProfileRepository profileRepository;

  /// Present in API mode only: real orders replace the demo-director chat
  /// flow, so approvals land in the server-backed order room.
  final OrdersRepository? ordersRepository;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late DatePost _post = widget.post;
  late bool _signedUp = widget.post.hasApplied;
  bool _approving = false;

  /// Viewer's real distance to the venue; null hides the distance row
  /// (no structured venue or location unavailable).
  double? _venueDistanceKm;

  bool get _isMine => _post.author.id == AuthSession.currentUserId;

  @override
  void initState() {
    super.initState();
    _computeVenueDistance();
  }

  Future<void> _computeVenueDistance() async {
    if (!_post.hasVenueLocation) {
      return;
    }
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final Position position =
          await Geolocator.getLastKnownPosition() ??
              await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _venueDistanceKm = distanceKmBetween(
            position.latitude,
            position.longitude,
            _post.placeLat,
            _post.placeLng,
          );
        });
      }
    } on Exception {
      // Distance row stays hidden.
    }
  }

  /// Collects the required plan pitch, then signs up as a candidate.
  Future<void> _signUp() async {
    final String? proposal = await _askProposal();
    if (proposal == null || !mounted) {
      return;
    }
    await _signUpWith(proposal);
  }

  Future<String?> _askProposal() {
    final TextEditingController controller = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
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
              const Text(
                AppStrings.proposalSheetTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                AppStrings.proposalSheetSub,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey<String>('proposalField'),
                controller: controller,
                autofocus: true,
                maxLength: 200,
                maxLines: 3,
                minLines: 2,
                decoration: const InputDecoration(
                  hintText: AppStrings.proposalHint,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey<String>('proposalSubmitButton'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.onDarkPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    final String text = controller.text.trim();
                    if (text.isEmpty) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text(AppStrings.proposalRequiredHint),
                        ),
                      );
                      return;
                    }
                    Navigator.of(sheetContext).pop(text);
                  },
                  child: const Text(AppStrings.signUpCta),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _signUpWith(String proposal) async {
    setState(() => _signedUp = true);
    final DatePost updated;
    try {
      updated = await widget.partnerRepository.signUp(_post.id, proposal);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      // Revert the optimistic sign-up state before handling the error.
      setState(() => _signedUp = false);
      if (e.verificationRequired) {
        final bool verified = await promptVerification(context);
        if (verified && mounted) {
          return _signUpWith(proposal);
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
    if (widget.ordersRepository == null) {
      // DEMO NOTE (mock mode only): fakes the poster approving the current
      // user and paying the match fee into escrow.
      final DatePost post = updated;
      Timer(const Duration(seconds: 3), () {
        widget.chatRepository.createDealConversation(
          post: post,
          payer: post.author,
        );
      });
    }
    // API mode: nothing to fake — if the poster selects this user, the
    // order appears in the Chats tab (orders list) within a poll cycle.
  }

  Future<void> _approveCandidate(PostAuthor candidate) async {
    if (_approving) {
      return;
    }
    setState(() => _approving = true);
    final PostAuthor selected = await widget.partnerRepository.selectCandidate(
      _post.id,
      candidate.id,
    );

    final OrdersRepository? ordersRepository = widget.ordersRepository;
    if (ordersRepository != null) {
      // API mode: contact only exists behind the paywall. When the approver
      // is the payer (male poster), the escrow payment page opens right
      // here; otherwise the selected male pays from his device before chat
      // unlocks.
      LiveOrder? order = await ordersRepository.findByPostId(_post.id);
      if (!mounted) {
        return;
      }
      if (order != null &&
          order.isPayer(AuthSession.currentUserId) &&
          order.status == 'AWAITING_PAYMENT') {
        final LiveOrder? paid = await Navigator.of(context).push<LiveOrder>(
          MaterialPageRoute<LiveOrder>(
            builder: (_) => PaymentPage(
              repository: ordersRepository,
              order: order!,
            ),
          ),
        );
        if (paid != null) {
          order = paid;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() => _approving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.selectionDoneSnack)),
      );
      final LiveOrder? created = order;
      if (created != null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OrderRoomPage(
              repository: ordersRepository,
              orderId: created.id,
              initialOrder: created,
            ),
          ),
        );
      }
      return;
    }

    // Mock mode: the demo escrow payment happens instantly and the deal
    // conversation opens right away.
    final conversation = await widget.chatRepository.createDealConversation(
      post: _post,
      payer: selected,
    );
    if (!mounted) {
      return;
    }
    setState(() => _approving = false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailPage(
          repository: widget.chatRepository,
          conversation: conversation,
        ),
      ),
    );
  }

  void _openAuthor() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfilePage(
          userId: _post.author.id,
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
      await widget.partnerRepository.deletePost(_post.id);
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
                          _post.sceneTag,
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
                      candidatesStream: widget.partnerRepository
                          .watchCandidates(_post.id),
                      onApprove: _approveCandidate,
                    ),
                    const SizedBox(height: 14),
                  ],
                  _InfoCard(post: _post, venueDistanceKm: _venueDistanceKm),
                  if (!_isMine) ...<Widget>[
                    const SizedBox(height: 14),
                    _AuthorCard(post: _post, onTap: _openAuthor),
                  ],
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
  });

  final Stream<List<PostAuthor>> candidatesStream;
  final ValueChanged<PostAuthor> onApprove;

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
  const _CandidateRow({required this.candidate, required this.onApprove});

  final PostAuthor candidate;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.post, this.venueDistanceKm});

  final DatePost post;

  /// Viewer's real distance to the venue; the row is hidden when null.
  final double? venueDistanceKm;

  @override
  Widget build(BuildContext context) {
    final List<(IconData, String, String)> rows = <(IconData, String, String)>[
      (Iconsax.clock, AppStrings.labelTime, post.timeText),
      (Iconsax.location, AppStrings.labelPlace, post.place),
      if (venueDistanceKm != null)
        (
          Iconsax.send_2,
          AppStrings.labelDistance,
          AppStrings.distanceAway(venueDistanceKm!.toStringAsFixed(1)),
        ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: <Widget>[
                  Icon(rows[i].$1, size: 17, color: AppColors.textHint),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 64,
                    child: Text(
                      rows[i].$2,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].$3,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textPrimary,
                      ),
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

class _AuthorCard extends StatelessWidget {
  const _AuthorCard({required this.post, required this.onTap});

  final DatePost post;
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

  final DatePost post;
  final bool signedUp;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    final int amount = ScenePricing.netEarnings(post.tipAmount);
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

  final DatePost post;

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
                      MoneyFormat.format(post.tipAmount),
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
