import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../community/models/post_author.dart';
import '../data/orders_repository.dart';
import '../models/live_order.dart';
import 'order_room_page.dart';
import 'pay_page.dart';

/// The full order history under the Me tab, as proper e-commerce order
/// cards: every status, newest first. Each card is title + status, the
/// peer and the locked plan, the total, and the status's own actions —
/// pay/cancel while unpaid, chat while running, details when closed. The
/// Messages tab only carries live conversations; this page is where
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
  bool _busy = false;

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

  Future<void> _pay(LiveOrder order) async {
    final LiveOrder? paid = await openPayPage(
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
    await _enterRoom(paid);
  }

  /// Backing out of an unpaid deal is free: no money moved, the pitch or
  /// post goes straight back on the market.
  Future<void> _cancelUnpaid(LiveOrder order) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.ordersRepository.cancel(order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.unpaidCancelledSnack)),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        unawaited(_load());
      }
    }
  }

  Future<void> _enterRoom(LiveOrder order) async {
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

  /// Tapping the card body follows the status's primary action: an unpaid
  /// order is an unfinished payment (payer) or a wait (earner); anything
  /// paid opens its room, read-only when closed.
  Future<void> _open(LiveOrder order) async {
    if (order.status == 'AWAITING_PAYMENT') {
      if (order.isPayer(AuthSession.currentUserId)) {
        await _pay(order);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.waitingForPayment)),
        );
      }
      return;
    }
    await _enterRoom(order);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(AppStrings.myOrdersTitle),
      ),
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
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                    itemCount: _orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final LiveOrder order = _orders[index];
                      return _OrderCard(
                        order: order,
                        busy: _busy,
                        onTap: () => _open(order),
                        onPay: () => _pay(order),
                        onCancel: () => _cancelUnpaid(order),
                        onChat: () => _enterRoom(order),
                      );
                    },
                  ),
                ),
    );
  }
}

/// One order as a service-purchase card, not a people card: the header
/// is the provider line (the merchant position — host for the payer,
/// initiator for the host), the body is the service item itself (the
/// activity with its locked plan and price), and the footer carries the
/// total plus the status's actions.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.busy,
    required this.onTap,
    required this.onPay,
    required this.onCancel,
    required this.onChat,
  });

  final LiveOrder order;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onPay;
  final VoidCallback onCancel;
  final VoidCallback onChat;

  bool get _iAmPayer => order.isPayer(AuthSession.currentUserId);

  (String, Color) get _statusText {
    switch (order.status) {
      case 'AWAITING_PAYMENT':
        return (AppStrings.statusAwaitingPayment, const Color(0xFFD97706));
      case 'ACTIVE':
        return (AppStrings.statusActive, AppColors.accent);
      case 'COMPLETED':
        return (AppStrings.statusCompleted, AppColors.textSecondary);
      case 'FORFEITED':
        return (AppStrings.statusForfeited, AppColors.textHint);
      default:
        return (AppStrings.statusCancelled, AppColors.textHint);
    }
  }

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
    final (String statusLabel, Color statusColor) = _statusText;
    final String fee = MoneyFormat.format(order.feePesos);
    final String whenLine = _whenLine(context);
    // The merchant line: the one providing or ordering the service, never
    // the item being sold.
    final String providerLine = _iAmPayer
        ? AppStrings.myOrderHostLine(peer.name)
        : AppStrings.myOrderGuestLine(peer.name);
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey<String>('myOrder-${order.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header: the provider line (merchant position) + status.
              Row(
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
                    statusLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Body: the service item — the activity with its locked
              // plan, the price on the right like a line item.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Iconsax.calendar_1,
                      size: 22,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          order.postTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (order.planPlace.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            order.planPlace,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (whenLine.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            whenLine,
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
                    fee,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Footer: order time, total, then the actions this status
              // actually supports.
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _createdLine(context),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                  Text.rich(
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
                ],
              ),
              ..._actions(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    final List<Widget> buttons = <Widget>[];
    if (order.status == 'AWAITING_PAYMENT') {
      if (_iAmPayer) {
        buttons.addAll(<Widget>[
          _pillButton(
            key: 'myOrderCancel-${order.id}',
            label: AppStrings.myOrderCancelCta,
            onPressed: busy ? null : onCancel,
          ),
          const SizedBox(width: 8),
          _pillButton(
            key: 'myOrderPay-${order.id}',
            label: AppStrings.myOrderPayCta,
            onPressed: busy ? null : onPay,
            primary: true,
          ),
        ]);
      } else {
        buttons.add(const Text(
          AppStrings.myOrderWaitingPeerPay,
          style: TextStyle(fontSize: 12.5, color: AppColors.textHint),
        ));
      }
    } else if (order.status == 'ACTIVE') {
      buttons.add(_pillButton(
        key: 'myOrderChat-${order.id}',
        label: AppStrings.myOrderChatCta,
        onPressed: onChat,
        primary: true,
      ));
    } else {
      buttons.add(_pillButton(
        key: 'myOrderDetail-${order.id}',
        label: AppStrings.myOrderDetailCta,
        onPressed: onChat,
      ));
    }
    return <Widget>[
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: buttons),
    ];
  }

  Widget _pillButton({
    required String key,
    required String label,
    required VoidCallback? onPressed,
    bool primary = false,
  }) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        key: ValueKey<String>(key),
        onPressed: onPressed,
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
