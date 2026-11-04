import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/env/app_env.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../community/models/post_author.dart';
import '../data/orders_repository.dart';
import '../models/live_order.dart';
import 'order_room_page.dart';
import '../widgets/order_status_pill.dart';
import '../../../shared/widgets/app_avatar.dart';

/// Messages tab: the caller's conversations — orders whose money is
/// already in escrow. Unpaid deals never show here (no chat before
/// escrow; they live on the My Orders page under the profile tab).
/// Each row opens its order room. There is no notification inbox:
/// every state lives on its own surface.
class OrdersPage extends StatefulWidget {
  const OrdersPage({
    super.key,
    required this.repository,
  });

  final OrdersRepository repository;

  @override
  State<OrdersPage> createState() => OrdersPageState();
}

class OrdersPageState extends State<OrdersPage> {
  List<LiveOrder> _orders = <LiveOrder>[];
  bool _loaded = false;
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
      final List<LiveOrder> orders = await widget.repository.listMine();
      if (mounted) {
        setState(() {
          _orders = orders;
          _loaded = true;
        });
      }
    } on Exception {
      // Keep the last known list; the next poll retries.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.tabMessages)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
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
                  separatorBuilder: (_, int i) => const Divider(indent: 76),
                  itemBuilder: (BuildContext context, int index) =>
                      _OrderTile(
                    order: _orders[index],
                    repository: widget.repository,
                  ),
                ),
    );
  }
}

/// One date (order) presented as a concrete event — "who · what · where ·
/// when" — rather than a bare conversation.
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

  @override
  Widget build(BuildContext context) {
    final String myId = AuthSession.currentUserId;
    final PostAuthor peer = order.peerOf(myId);

    // The date, as a concrete event: scene · venue · time.
    final String dateLine = <String?>[
      order.postTitle,
      order.place,
      _scheduleText,
    ].whereType<String>().where((String s) => s.isNotEmpty).join(' \u00b7 ');

    return ListTile(
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
          const Spacer(),
          OrderStatusPill(status: order.status),
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
  }
}
