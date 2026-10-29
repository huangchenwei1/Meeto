import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../hosts/data/hosts_repository.dart';
import '../../hosts/models/host_card.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../notifications/pages/notifications_page.dart';
import '../../community/data/community_repository.dart';
import '../../community/models/post_author.dart';
import '../../profile/data/profile_repository.dart';
import '../data/orders_repository.dart';
import '../models/live_order.dart';
import 'order_room_page.dart';
import 'payment_page.dart';
import '../../../shared/widgets/app_avatar.dart';

/// Chats tab in API mode: a pinned notifications inbox on top, then the
/// caller's real orders, polled from the server. Each order opens its order
/// room (status + chat with the matched peer).
class OrdersPage extends StatefulWidget {
  const OrdersPage({
    super.key,
    required this.repository,
    required this.notificationsRepository,
    required this.communityRepository,
    required this.profileRepository,
    required this.hostsRepository,
  });

  final OrdersRepository repository;
  final NotificationsRepository notificationsRepository;
  final CommunityRepository communityRepository;
  final ProfileRepository profileRepository;
  final HostsRepository hostsRepository;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<LiveOrder> _orders = <LiveOrder>[];
  List<InvitationRecord> _pendingInvitations = <InvitationRecord>[];
  bool _loaded = false;
  int _unreadCount = 0;
  Timer? _pollTimer;
  bool _respondingInvitation = false;

  bool get _showInvitations => AuthSession.isHost;

  @override
  void initState() {
    super.initState();
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final (List<LiveOrder>, int) result = await (
        widget.repository.listMine(),
        widget.notificationsRepository.unreadCount(),
      ).wait;
      List<InvitationRecord> pending = _pendingInvitations;
      if (_showInvitations) {
        final List<InvitationRecord> invitations =
            await widget.hostsRepository.fetchInvitations();
        pending = invitations
            .where((InvitationRecord i) => i.isPending)
            .toList(growable: false);
      }
      if (mounted) {
        setState(() {
          _orders = result.$1;
          _unreadCount = result.$2;
          _pendingInvitations = pending;
          _loaded = true;
        });
      }
    } on Exception {
      // Keep the last known list; the next poll retries.
    }
  }

  Future<void> _acceptInvitation(InvitationRecord invitation) async {
    setState(() => _respondingInvitation = true);
    try {
      final LiveOrder? order =
          await widget.hostsRepository.acceptInvitation(invitation.id);
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
              repository: widget.repository,
              orderId: order.id,
              initialOrder: order,
            ),
          ),
        );
      }
      unawaited(_poll());
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

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsPage(
          notificationsRepository: widget.notificationsRepository,
          communityRepository: widget.communityRepository,
          profileRepository: widget.profileRepository,
          ordersRepository: widget.repository,
        ),
      ),
    );
    if (mounted) {
      // The inbox marks everything read on open.
      setState(() => _unreadCount = 0);
      unawaited(_poll());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.tabMessages)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                _NotificationsInboxTile(
                  unreadCount: _unreadCount,
                  onTap: _openNotifications,
                ),
                const Divider(indent: 76, height: 1),
                for (final InvitationRecord invitation in _pendingInvitations)
                  _InvitationTile(
                    invitation: invitation,
                    busy: _respondingInvitation,
                    onAccept: () => _acceptInvitation(invitation),
                    onDecline: () => _declineInvitation(invitation),
                  ),
                if (_pendingInvitations.isNotEmpty)
                  const Divider(height: 1),
                Expanded(
                  child: _orders.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              AppStrings.ordersEmpty,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _orders.length,
                          separatorBuilder: (_, int i) =>
                              const Divider(indent: 76),
                          itemBuilder: (BuildContext context, int index) =>
                              _OrderTile(
                            order: _orders[index],
                            repository: widget.repository,
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

/// One pending direct invitation (host side): who wants what, with
/// accept/decline inline. Accepting opens the newly created order room.
class _InvitationTile extends StatelessWidget {
  const _InvitationTile({
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
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
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

/// Pinned inbox entry collecting all system notifications (new applicants,
/// selections, payments...), so the feed stays clean of bells.
class _NotificationsInboxTile extends StatelessWidget {
  const _NotificationsInboxTile({
    required this.unreadCount,
    required this.onTap,
  });

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const ValueKey<String>('notificationsInbox'),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: AppColors.darkCard,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Iconsax.notification,
          size: 24,
          color: AppColors.onDarkPrimary,
        ),
      ),
      title: const Text(
        AppStrings.notificationsTitle,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          AppStrings.notificationsInboxSub,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
      trailing: unreadCount > 0
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textHint,
            ),
      onTap: onTap,
    );
  }
}

/// One date (order) presented as a concrete event — "who · what · where ·
/// when" — rather than a bare conversation. Before payment the row is a
/// locked deal: dimmed, no chat semantics, and a direct pay entry for the
/// payer.
class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.repository});

  static const List<String> _weekdays = <String>[
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final LiveOrder order;
  final OrdersRepository repository;

  String? get _scheduleText {
    final DateTime? at = order.scheduledAt?.toLocal();
    if (at == null) {
      return null;
    }
    final int hour12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final String minute = at.minute.toString().padLeft(2, '0');
    final String ampm = at.hour < 12 ? 'AM' : 'PM';
    return '${_weekdays[at.weekday - 1]}, ${_months[at.month - 1]} '
        '${at.day} \u00b7 $hour12:$minute $ampm';
  }

  void _openRoom(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderRoomPage(
          repository: repository,
          orderId: order.id,
          initialOrder: order,
        ),
      ),
    );
  }

  Future<void> _payNow(BuildContext context) async {
    final LiveOrder? paid = await Navigator.of(context).push<LiveOrder>(
      MaterialPageRoute<LiveOrder>(
        builder: (_) => PaymentPage(repository: repository, order: order),
      ),
    );
    if (paid != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OrderRoomPage(
            repository: repository,
            orderId: paid.id,
            initialOrder: paid,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String myId = AuthSession.currentUserId;
    final PostAuthor peer = order.peerOf(myId);
    final bool iPay = order.isPayer(myId);
    final bool locked = order.status == 'AWAITING_PAYMENT';

    // The date, as a concrete event: scene · venue · time.
    final String dateLine = <String?>[
      order.postTitle,
      order.place,
      _scheduleText,
    ].whereType<String>().where((String s) => s.isNotEmpty).join(' \u00b7 ');

    final Widget tile = ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: AppAvatar(
        size: 52,
        imageUrl: peer.avatarUrl,
        fallbackLetter: peer.name.isEmpty ? '?' : peer.name[0],
      ),
      title: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              peer.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          if (locked) ...<Widget>[
            const SizedBox(width: 6),
            const Icon(
              Icons.lock_outline,
              size: 15,
              color: AppColors.textHint,
            ),
          ],
          const Spacer(),
          if (locked && iPay)
            FilledButton(
              key: const ValueKey<String>('payToUnlockButton'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.darkCard,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _payNow(context),
              child: const Text(
                AppStrings.payToUnlockCta,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            _StatusPill(status: order.status),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          dateLine.isEmpty ? AppStrings.statusPendingDate : dateLine,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
      onTap: () => _openRoom(context),
    );

    // Dim the waiting side; the payer keeps full contrast because the row
    // carries their primary action (pay).
    return locked && !iPay ? Opacity(opacity: 0.65, child: tile) : tile;
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color fg, Color bg) = switch (status) {
      'AWAITING_PAYMENT' => (
          AppStrings.statusAwaitingPayment,
          const Color(0xFF92400E),
          const Color(0xFFFEF3C7),
        ),
      'ACTIVE' => (
          AppStrings.statusActive,
          AppColors.accent,
          AppColors.accentSoft,
        ),
      'COMPLETED' => (
          AppStrings.statusCompleted,
          AppColors.textSecondary,
          AppColors.surface,
        ),
      _ => (
          AppStrings.statusCancelled,
          AppColors.textSecondary,
          AppColors.surface,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
