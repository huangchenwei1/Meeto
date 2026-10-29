import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/pages/order_room_page.dart';
import '../../partner/data/partner_repository.dart';
import '../../partner/models/date_post.dart';
import '../../partner/pages/post_detail_page.dart';
import '../../profile/data/profile_repository.dart';
import '../data/notifications_repository.dart';

/// Notification inbox (API mode). Opening it marks everything read; each
/// entry deep-links to the post (candidate pool) or the order room.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.notificationsRepository,
    required this.partnerRepository,
    required this.profileRepository,
    required this.ordersRepository,
  });

  final NotificationsRepository notificationsRepository;
  final PartnerRepository partnerRepository;
  final ProfileRepository profileRepository;
  final OrdersRepository ordersRepository;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<AppNotification> _items = <AppNotification>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<AppNotification> items =
          await widget.notificationsRepository.list();
      // Entering the inbox acknowledges everything, like most socials.
      await widget.notificationsRepository.markAllRead();
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(AppNotification item) async {
    if (item.orderId.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OrderRoomPage(
            orderId: item.orderId,
            repository: widget.ordersRepository,
          ),
        ),
      );
      return;
    }
    if (item.postId.isNotEmpty) {
      final DatePost post =
          await widget.partnerRepository.fetchPostById(item.postId);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PostDetailPage(
            post: post,
            partnerRepository: widget.partnerRepository,
            profileRepository: widget.profileRepository,
            ordersRepository: widget.ordersRepository,
          ),
        ),
      );
    }
  }

  String _label(AppNotification item) {
    switch (item.type) {
      case 'NEW_APPLICANT':
        return AppStrings.notifyNewApplicant(item.actorName);
      case 'SELECTED':
        return AppStrings.notifySelected(item.actorName);
      case 'ORDER_PAID':
        return AppStrings.notifyOrderPaid(item.actorName);
      case 'ORDER_CANCELLED':
        return AppStrings.notifyOrderCancelled(item.actorName);
      case 'ORDER_MET':
        return AppStrings.notifyOrderMet(item.actorName);
      case 'ORDER_SETTLED':
        return AppStrings.notifyOrderSettled;
      case 'ORDER_DISPUTED':
        return AppStrings.notifyOrderDisputed(item.actorName);
      case 'PLAN_PROPOSED':
        return AppStrings.notifyPlanProposed(item.actorName);
      case 'PLAN_CONFIRMED':
        return AppStrings.notifyPlanConfirmed(item.actorName);
      case 'INVITE_RECEIVED':
        return AppStrings.notifyInviteReceived(item.actorName);
      case 'INVITE_ACCEPTED':
        return AppStrings.notifyInviteAccepted(item.actorName);
      case 'INVITE_DECLINED':
        return AppStrings.notifyInviteDeclined(item.actorName);
      default:
        return item.type;
    }
  }

  String _timeAgo(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) {
      return AppStrings.timeJustNow;
    }
    if (diff.inHours < 1) {
      return AppStrings.timeMinutesAgo(diff.inMinutes);
    }
    if (diff.inDays < 1) {
      return AppStrings.timeHoursAgo(diff.inHours);
    }
    return AppStrings.timeDaysAgo(diff.inDays);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.notificationsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Text(
                    AppStrings.notificationsEmpty,
                    style: TextStyle(color: AppColors.textHint),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (BuildContext context, int index) {
                    final AppNotification item = _items[index];
                    return ListTile(
                      onTap: () => _open(item),
                      leading: AppAvatar(
                        size: 44,
                        imageUrl: item.actorAvatarUrl,
                        fallbackLetter: item.actorName.isEmpty
                            ? '?'
                            : item.actorName[0],
                      ),
                      title: Text(
                        _label(item),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              item.isRead ? FontWeight.w500 : FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          _timeAgo(item.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                      trailing: item.isRead
                          ? null
                          : Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                    );
                  },
                ),
    );
  }
}
