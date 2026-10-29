import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../auth/pages/verification_page.dart';
import '../../partner/models/post_author.dart';
import '../data/orders_repository.dart';
import '../models/live_order.dart';

/// Escrow payment confirmation. The single place where the payer commits
/// money; swapping the mock payment for a real checkout (GCash / Maya)
/// only touches this page.
///
/// Pops with the paid [LiveOrder] on success, or null when dismissed.
class PaymentPage extends StatefulWidget {
  const PaymentPage({
    super.key,
    required this.repository,
    required this.order,
  });

  final OrdersRepository repository;
  final LiveOrder order;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _paying = false;

  Future<void> _pay() async {
    setState(() => _paying = true);
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
          setState(() => _paying = false);
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
        setState(() => _paying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final LiveOrder order = widget.order;
    final PostAuthor peer = order.peerOf(AuthSession.currentUserId);
    final String fee = '\u20b1${order.feePesos}';
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.paymentTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: <Widget>[
          // Who the match is with.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                AppAvatar(
                  size: 46,
                  imageUrl: peer.avatarUrl,
                  fallbackLetter: peer.name.isEmpty ? '?' : peer.name[0],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        peer.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        AppStrings.paymentMatchLine,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Fee breakdown.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: <Widget>[
                _row(AppStrings.paymentFeeLabel, fee, emphasized: true),
                const Divider(height: 24),
                _row(AppStrings.paymentHeldByLabel, AppStrings.paymentHeldBy),
                const SizedBox(height: 10),
                _row(
                  AppStrings.paymentReleaseLabel,
                  AppStrings.paymentRelease,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Payment method (mock for now; real checkout replaces this row).
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Iconsax.wallet_3,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    AppStrings.paymentMethodDemo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.check_circle,
                    size: 18, color: AppColors.accent),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: FilledButton(
          onPressed: _paying ? null : _pay,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.darkCard,
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(
            _paying
                ? AppStrings.paymentPaying
                : AppStrings.paymentPayCta(fee),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasized = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: emphasized ? 17 : 13,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
