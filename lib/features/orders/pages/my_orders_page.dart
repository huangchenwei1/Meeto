import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../community/models/post_author.dart';
import '../data/orders_repository.dart';
import '../models/live_order.dart';
import '../widgets/order_status_pill.dart';
import '../widgets/pay_sheet.dart';
import 'order_room_page.dart';

/// The full order history under the Me tab: every status, newest first.
/// The Messages tab only carries live conversations; this page is where
/// unpaid deals get finished (or quietly expire) and old orders stay
/// reviewable forever.
class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key, required this.ordersRepository});

  final OrdersRepository ordersRepository;

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  List<LiveOrder> _orders = <LiveOrder>[];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<LiveOrder> orders =
          await widget.ordersRepository.listMine(all: true);
      if (mounted) {
        setState(() {
          _orders = orders;
          _loaded = true;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() => _loaded = true);
      }
    }
  }

  /// An unpaid order is an unfinished action, not a conversation: the
  /// payer gets the pay sheet (pay or cancel), the other side just waits.
  /// Everything else opens its room, read-only when closed.
  Future<void> _open(LiveOrder order) async {
    if (order.status == 'AWAITING_PAYMENT') {
      if (!order.isPayer(AuthSession.currentUserId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.waitingForPayment)),
        );
        return;
      }
      final LiveOrder? paid = await showPaySheet(
        context,
        repository: widget.ordersRepository,
        order: order,
      );
      if (!mounted) {
        return;
      }
      unawaited(_load());
      if (paid == null) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OrderRoomPage(
            repository: widget.ordersRepository,
            orderId: paid.id,
            initialOrder: paid,
          ),
        ),
      );
      unawaited(_load());
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderRoomPage(
          repository: widget.ordersRepository,
          orderId: order.id,
          initialOrder: order,
        ),
      ),
    );
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.myOrdersTitle)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(
                  child: Text(
                    AppStrings.myOrdersEmpty,
                    style: TextStyle(color: AppColors.textHint),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _orders.length,
                    separatorBuilder: (_, _) =>
                        const Divider(indent: 76, height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final LiveOrder order = _orders[index];
                      return _MyOrderTile(
                        order: order,
                        onTap: () => _open(order),
                      );
                    },
                  ),
                ),
    );
  }
}

class _MyOrderTile extends StatelessWidget {
  const _MyOrderTile({required this.order, required this.onTap});

  final LiveOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PostAuthor peer = order.peerOf(AuthSession.currentUserId);
    final String line = <String>[
      if (order.postTitle.isNotEmpty) order.postTitle,
      '\u20b1${order.feePesos}',
    ].join(' \u00b7 ');
    return ListTile(
      key: ValueKey<String>('myOrder-${order.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      leading: AppAvatar(
        size: 48,
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
                fontSize: 15.5,
              ),
            ),
          ),
          const Spacer(),
          OrderStatusPill(status: order.status),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          line,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
