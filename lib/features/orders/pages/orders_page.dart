import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/env/app_env.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../notifications/pages/notifications_page.dart';
import '../../community/data/community_repository.dart';
import '../../community/models/post_author.dart';
import '../../hosts/data/hosts_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/orders_repository.dart';
import '../models/live_order.dart';
import 'order_room_page.dart';
import 'payment_page.dart';
import '../../../shared/widgets/app_avatar.dart';

/// Messages tab: a pinned notifications inbox on top, then the caller's
/// orders, polled from the server. Each order opens its order room
/// (status + chat with the matched peer). Invitations live on the
/// proposal detail pages, not here.
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
  State<OrdersPage> createState() => OrdersPageState();
}

class OrdersPageState extends State<OrdersPage> {
  List<LiveOrder> _orders = <LiveOrder>[];
  bool _loaded = false;
  int _unreadCount = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _poll();
    if (AppEnv.useRemoteApi) {
      // API mode: the peer acts from another device; poll for changes.
      // Mock mode state only changes locally, so a reload on tab return
      // (see the shell) is enough.
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
    try {
      final (List<LiveOrder>, int) result = await (
        widget.repository.listMine(),
        widget.notificationsRepository.unreadCount(),
      ).wait;
      if (mounted) {
        setState(() {
          _orders = result.$1;
          _unreadCount = result.$2;
          _loaded = true;
        });
      }
    } on Exception {
      // Keep the last known list; the next poll retries.
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
          hostsRepository: widget.hostsRepository,
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
      'FORFEITED' => (
          AppStrings.statusForfeited,
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
