import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../community/models/post_author.dart';
import '../data/orders_repository.dart';
import '../models/live_order.dart';
import 'order_room_page.dart';

/// Completed orders only, under the Me tab: the purchase history of
/// finished activities, newest first. Running deals live on the Messages
/// tab, unpaid deals finish (or expire) right where they were formed —
/// neither belongs in an order archive.
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
          _orders = orders
              .where((LiveOrder o) => o.status == 'COMPLETED')
              .toList(growable: false);
          _loaded = true;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() => _loaded = true);
      }
    }
  }

  Future<void> _openRoom(LiveOrder order) async {
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
                        onTap: () => _openRoom(order),
                      );
                    },
                  ),
                ),
    );
  }
}

/// One completed order as a service-purchase card: the header is the
/// provider line (the merchant position — host for the payer, initiator
/// for the host), the body is the service item itself (the activity with
/// its locked plan and price), and the footer carries the total and the
/// details action.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final LiveOrder order;
  final VoidCallback onTap;

  bool get _iAmPayer => order.isPayer(AuthSession.currentUserId);

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
                  const Text(
                    AppStrings.statusCompleted,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
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
              // Footer: order time + total; the card itself opens the
              // read-only room.
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
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      key: ValueKey<String>('myOrderDetail-${order.id}'),
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text(AppStrings.myOrderDetailCta),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
