import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../auth/pages/verification_page.dart';
import '../data/profile_repository.dart';
import '../models/current_user.dart';

/// Wallet: balance summary, a real withdrawal action (the ledger is debited
/// immediately; payout via GCash/Maya comes later) and withdrawal history.
class WalletPage extends StatefulWidget {
  const WalletPage({super.key, required this.repository});

  final ProfileRepository repository;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  WalletSummary? _wallet;
  List<WithdrawalRecord> _withdrawals = <WithdrawalRecord>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (WalletSummary, List<WithdrawalRecord>) result = await (
      widget.repository.fetchWallet(),
      widget.repository.fetchWithdrawals(),
    ).wait;
    if (!mounted) {
      return;
    }
    setState(() {
      _wallet = result.$1;
      _withdrawals = result.$2;
    });
  }

  Future<void> _startWithdraw() async {
    final WalletSummary? wallet = _wallet;
    if (wallet == null || wallet.withdrawable <= 0) {
      return;
    }
    final TextEditingController controller =
        TextEditingController(text: '${wallet.withdrawable}');
    final int? amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                AppStrings.withdrawSheetTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.withdrawSheetSub(
                  MoneyFormat.format(wallet.withdrawable),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey<String>('withdrawAmountField'),
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  prefixText: '\u20b1 ',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey<String>('withdrawConfirmButton'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.darkCard,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    final int? value = int.tryParse(controller.text.trim());
                    if (value == null || value <= 0) {
                      return;
                    }
                    Navigator.of(sheetContext).pop(value);
                  },
                  child: const Text(AppStrings.withdraw),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (amount == null || !mounted) {
      return;
    }
    await _withdraw(amount);
  }

  Future<void> _withdraw(int amountPesos) async {
    setState(() => _busy = true);
    try {
      await widget.repository.requestWithdrawal(amountPesos);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.withdrawSubmitted)),
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.verificationRequired) {
        final bool verified = await promptVerification(context);
        if (verified && mounted) {
          await _withdraw(amountPesos);
          return;
        }
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.withdrawFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final WalletSummary? wallet = _wallet;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.walletTitle)),
      body: wallet == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _SummaryCard(
                  wallet: wallet,
                  busy: _busy,
                  onWithdraw: _startWithdraw,
                ),
                const SizedBox(height: 24),
                const Text(
                  AppStrings.withdrawHistoryTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                if (_withdrawals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        AppStrings.withdrawHistoryEmpty,
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ..._withdrawals
                      .map((WithdrawalRecord r) => _WithdrawalTile(record: r)),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.wallet,
    required this.busy,
    required this.onWithdraw,
  });

  final WalletSummary wallet;
  final bool busy;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Iconsax.wallet_3,
                size: 15,
                color: AppColors.onDarkSecondary,
              ),
              SizedBox(width: 7),
              Text(
                AppStrings.walletLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.onDarkSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            MoneyFormat.format(wallet.monthTipIncome),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.onDarkPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppStrings.walletWithdrawable(
                    MoneyFormat.format(wallet.withdrawable),
                  ),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.onDarkSecondary,
                  ),
                ),
              ),
              FilledButton(
                key: const ValueKey<String>('walletWithdrawButton'),
                onPressed: busy || wallet.withdrawable <= 0
                    ? null
                    : onWithdraw,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.background,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text(AppStrings.withdraw),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WithdrawalTile extends StatelessWidget {
  const _WithdrawalTile({required this.record});

  final WithdrawalRecord record;

  @override
  Widget build(BuildContext context) {
    final DateTime at = record.createdAt.toLocal();
    final String date =
        '${at.year}-${at.month.toString().padLeft(2, '0')}-'
        '${at.day.toString().padLeft(2, '0')} '
        '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    final bool pending = record.status == 'PENDING';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  MoneyFormat.format(record.amountPesos),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: pending ? const Color(0xFFFEF3C7) : AppColors.accentSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              pending
                  ? AppStrings.withdrawalPending
                  : AppStrings.withdrawalPaid,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    pending ? const Color(0xFF92400E) : AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
