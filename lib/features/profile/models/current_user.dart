import 'profile_parts.dart';

/// The signed-in user's own summary shown on the Me tab.
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.name,
    required this.gender,
    required this.avatarUrl,
    required this.meta,
    required this.isVerified,
    required this.idLine,
    required this.stats,
  });

  final String id;
  final String name;

  /// MALE | FEMALE. Drives money UI: only the female side earns, so the
  /// wallet card is shown to female users only.
  final String gender;

  final String avatarUrl;

  /// Short display meta, e.g. "Female · 24".
  final String meta;

  final bool isVerified;

  /// Display line under the name, e.g. "Meeto ID 20481 · Manila".
  final String idLine;

  final List<ProfileStat> stats;
}

/// Wallet summary shown on the Me tab.
///
/// Amounts are whole pesos for the demo; production should use minor units
/// plus a currency code.
class WalletSummary {
  const WalletSummary({
    required this.monthTipIncome,
    required this.withdrawable,
  });

  final int monthTipIncome;
  final int withdrawable;
}

/// One withdrawal request (whole pesos). Status: PENDING until the payout
/// channel confirms, then PAID.
class WithdrawalRecord {
  const WithdrawalRecord({
    required this.id,
    required this.amountPesos,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final int amountPesos;
  final String status;
  final DateTime createdAt;
}
