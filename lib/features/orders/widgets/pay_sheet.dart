import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/pages/verification_page.dart';
import '../data/orders_repository.dart';
import '../models/live_order.dart';

/// The escrow payment moment, as a half-screen sheet instead of a page:
/// payment is part of the deal-forming action (selection / being picked),
/// not a destination of its own. The single place where the payer commits
/// money; a real checkout (GCash / Maya) later slots in behind the pay
/// button.
///
/// Returns the paid [LiveOrder], or null when dismissed or cancelled.
Future<LiveOrder?> showPaySheet(
  BuildContext context, {
  required OrdersRepository repository,
  required LiveOrder order,
}) {
  return showModalBottomSheet<LiveOrder>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => PaySheet(repository: repository, order: order),
  );
}

class PaySheet extends StatefulWidget {
  const PaySheet({super.key, required this.repository, required this.order});

  final OrdersRepository repository;
  final LiveOrder order;

  @override
  State<PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<PaySheet> {
  bool _busy = false;

  String _planLine(BuildContext context, LiveOrder order) {
    final MaterialLocalizations loc = MaterialLocalizations.of(context);
    final DateTime local = order.planAt!.toLocal();
    final String when = '${loc.formatShortDate(local)} \u00b7 '
        '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
    return order.planDurationMinutes > 0
        ? '$when \u00b7 ${AppStrings.durationAbout(order.planDurationMinutes)}'
        : when;
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    try {
      final LiveOrder paid = await widget.repository.pay(widget.order.id);
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
      await widget.repository.cancel(widget.order.id);
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

  @override
  Widget build(BuildContext context) {
    final String fee = '\u20b1${widget.order.feePesos}';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.paddingOf(context).bottom +
            16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            AppStrings.paymentTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          // The locked plan: the payer commits to a concrete place and
          // time, not an abstract match.
          if (widget.order.planPlace.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.order.planPlace,
                    key: const ValueKey<String>('paySheetPlanPlace'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (widget.order.planAt != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      _planLine(context, widget.order),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
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
                key: const ValueKey<String>('paySheetFee'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Iconsax.shield_tick, size: 16, color: AppColors.accent),
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
          const SizedBox(height: 10),
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
              Icon(Icons.check_circle, size: 16, color: AppColors.accent),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey<String>('paySheetPayButton'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.darkCard,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
          Center(
            child: TextButton(
              key: const ValueKey<String>('paySheetCancelButton'),
              onPressed: _busy ? null : _cancelOrder,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textHint,
                textStyle: const TextStyle(fontSize: 12.5),
              ),
              child: const Text(AppStrings.paymentCancelOrderCta),
            ),
          ),
        ],
      ),
    );
  }
}
