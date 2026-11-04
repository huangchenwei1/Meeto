import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../auth/pages/verification_page.dart';
import '../../community/models/post_author.dart';
import '../data/orders_repository.dart';
import '../models/live_order.dart';

/// Pushes the full-screen payment confirmation and resolves with the paid
/// [LiveOrder], or null when the payer backed out or just left.
Future<LiveOrder?> openPayPage(
  BuildContext context, {
  required OrdersRepository repository,
  required LiveOrder order,
}) {
  return Navigator.of(context).push<LiveOrder>(
    MaterialPageRoute<LiveOrder>(
      builder: (_) => PayPage(repository: repository, order: order),
    ),
  );
}

/// The escrow payment moment: a proper full-screen page — this is the
/// single heaviest action in the product, where the payer commits money
/// to a locked plan. Shows who, what plan, and what the escrow promises
/// before the one pay button. A real checkout (GCash / Maya) later slots
/// in behind it. The free way out of an unpaid deal also lives here.
class PayPage extends StatefulWidget {
  const PayPage({super.key, required this.repository, required this.order});

  final OrdersRepository repository;
  final LiveOrder order;

  @override
  State<PayPage> createState() => _PayPageState();
}

class _PayPageState extends State<PayPage> {
  bool _busy = false;

  LiveOrder get order => widget.order;

  Future<void> _pay() async {
    setState(() => _busy = true);
    try {
      final LiveOrder paid = await widget.repository.pay(order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.paymentDoneSnack)),
        );
        Navigator.of(context).pop(paid);
      }
    } on ApiException catch (e) {
      if (e.verificationRequired && mounted) {
        final bool verified = await promptVerification(context);
        if (verified && mounted) {
          setState(() => _busy = false);
          return _pay();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.paymentFailedSnack)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Backing out of an unpaid deal is free: no money moved, the pitch or
  /// post goes straight back on the market.
  Future<void> _cancelOrder() async {
    setState(() => _busy = true);
    try {
      await widget.repository.cancel(order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.unpaidCancelledSnack)),
        );
        Navigator.of(context).pop();
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
      }
    }
  }

  String _planWhen(BuildContext context) {
    final MaterialLocalizations loc = MaterialLocalizations.of(context);
    final DateTime local = order.planAt!.toLocal();
    final String when = '${loc.formatShortDate(local)} \u00b7 '
        '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
    return order.planDurationMinutes > 0
        ? '$when \u00b7 ${AppStrings.durationAbout(order.planDurationMinutes)}'
        : when;
  }

  @override
  Widget build(BuildContext context) {
    final PostAuthor peer = order.peerOf(AuthSession.currentUserId);
    final String fee = MoneyFormat.format(order.feePesos);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          AppStrings.paymentTitle,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Who you are meeting: the deal is with a person, not
                    // an order id.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              AppAvatar(
                                size: 44,
                                imageUrl: peer.avatarUrl,
                                fallbackLetter:
                                    peer.name.isEmpty ? '?' : peer.name[0],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      peer.name,
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (peer.meta.isNotEmpty)
                                      Text(
                                        peer.meta,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // The locked plan: the payer commits to a
                          // concrete place and time, not an abstract match.
                          if (order.planPlace.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 14),
                            Text(
                              order.planPlace,
                              key: const ValueKey<String>('payPagePlanPlace'),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (order.planAt != null) ...<Widget>[
                              const SizedBox(height: 3),
                              Text(
                                _planWhen(context),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (order.planNote.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              Text(
                                order.planNote,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: <Widget>[
                        const Text(
                          AppStrings.paymentFeeLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          fee,
                          key: const ValueKey<String>('payPageFee'),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Iconsax.shield_tick,
                            size: 16,
                            color: AppColors.accent,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              AppStrings.paymentEscrowNote,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Iconsax.wallet_3,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            AppStrings.paymentMethodDemo,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey<String>('payPagePayButton'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.darkCard,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: _busy ? null : _pay,
                      child: Text(
                        _busy
                            ? AppStrings.paymentPaying
                            : AppStrings.paymentPayCta(fee),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey<String>('payPageCancelButton'),
                    onPressed: _busy ? null : _cancelOrder,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textHint,
                      textStyle: const TextStyle(fontSize: 12.5),
                    ),
                    child: const Text(AppStrings.paymentCancelOrderCta),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
