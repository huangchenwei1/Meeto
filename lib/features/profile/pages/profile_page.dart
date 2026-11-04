import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/env/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/session/auth_session.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../auth/data/auth_repository_factory.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/pages/profile_setup_page.dart';
import '../../auth/pages/verification_page.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/pages/my_orders_page.dart';
import '../../community/data/community_repository.dart';
import '../../community/pages/my_posts_page.dart';
import '../data/profile_repository.dart';
import '../models/current_user.dart';
import '../models/profile_parts.dart';
import 'wallet_page.dart';

/// Me tab: profile card, stats, wallet and menu entries.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.repository,
    required this.communityRepository,
    required this.ordersRepository,
  });

  final ProfileRepository repository;
  final CommunityRepository communityRepository;
  final OrdersRepository ordersRepository;

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  CurrentUser? _user;
  WalletSummary? _wallet;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Re-fetches profile and wallet. Called by the shell whenever this tab
  /// becomes visible, so settled earnings show up without a restart.
  void reload() {
    _load();
  }

  Future<void> _load() async {
    final (CurrentUser, WalletSummary) result = await (
      widget.repository.fetchCurrentUser(),
      widget.repository.fetchWallet(),
    ).wait;
    if (!mounted) {
      return;
    }
    setState(() {
      _user = result.$1;
      _wallet = result.$2;
    });
  }

  Future<void> _openWallet() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WalletPage(repository: widget.repository),
      ),
    );
    _load();
  }

  /// The full order history (every status): unpaid deals get finished or
  /// cancelled here, closed ones stay reviewable.
  Future<void> _openMyOrders() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MyOrdersPage(ordersRepository: widget.ordersRepository),
      ),
    );
    _load();
  }

  Future<void> _openMyPosts() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MyPostsPage(
          communityRepository: widget.communityRepository,
          profileRepository: widget.repository,
          ordersRepository: widget.ordersRepository,
        ),
      ),
    );
    _load();
  }

  Future<void> _openVerification() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => const VerificationPage()),
    );
    _load();
  }

  Future<void> _editProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileSetupPage(
          client: ApiClient(baseUrl: AppEnv.apiBaseUrl),
          isEditing: true,
        ),
      ),
    );
    _load();
  }

  void _logout() {
    AuthSession.accessToken = null;
    AuthSession.refreshToken = null;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(authRepository: createAuthRepository()),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final CurrentUser? user = _user;
    final WalletSummary? wallet = _wallet;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.tabMe)),
      body: user == null || wallet == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: <Widget>[
                _ProfileCard(
                  user: user,
                  // Editing hits the API; mock mode keeps the static demo.
                  onEdit: AppEnv.useRemoteApi ? _editProfile : null,
                ),
                const SizedBox(height: 16),
                _StatsRow(stats: user.stats),
                const SizedBox(height: 16),
                // Only hosts earn, so only the host side gets a wallet.
                if (AuthSession.isHost) ...<Widget>[
                  _WalletCard(wallet: wallet, onOpen: _openWallet),
                  const SizedBox(height: 8),
                ],
                _MenuItem(
                  icon: Iconsax.receipt_1,
                  label: AppStrings.myOrdersTitle,
                  onTap: _openMyOrders,
                ),
                _MenuItem(
                  icon: Iconsax.note_2,
                  label: AppStrings.menuMyPosts,
                  onTap: _openMyPosts,
                ),
                _MenuItem(
                  icon: Iconsax.verify,
                  label: AppStrings.menuVerification,
                  hint: user.isVerified
                      ? AppStrings.verifiedStatus
                      : AppStrings.notVerifiedStatus,
                  onTap: !user.isVerified && AppEnv.useRemoteApi
                      ? _openVerification
                      : null,
                ),
                const _MenuItem(
                  icon: Iconsax.setting_2,
                  label: AppStrings.menuSettings,
                ),
                ListTile(
                  key: const ValueKey<String>('logoutMenuItem'),
                  onTap: _logout,
                  leading: const Icon(
                    Iconsax.logout,
                    size: 21,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    AppStrings.menuLogout,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, this.onEdit});

  final CurrentUser user;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: <Widget>[
          AppAvatar(
            size: 64,
            imageUrl: user.avatarUrl,
            fallbackLetter: user.name.isEmpty ? '?' : user.name[0],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (user.isVerified) const VerifiedBadge(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.idLine,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              key: const ValueKey<String>('editProfileButton'),
              onPressed: onEdit,
              icon: const Icon(
                Iconsax.edit_2,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: stats
            .map(
              (ProfileStat s) => Expanded(
                child: Column(
                  children: <Widget>[
                    Text(
                      s.value,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.wallet, required this.onOpen});

  final WalletSummary wallet;

  /// Opens the wallet page (card tap and Withdraw button both lead there).
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('walletCard'),
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: const <Widget>[
              Icon(Iconsax.wallet_3, size: 15, color: AppColors.onDarkSecondary),
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
                onPressed: onOpen,
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
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.hint,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // Demo: entries without a handler are placeholders; wire navigation
      // when the real sub-pages exist.
      onTap: onTap ?? () {},
      leading: Icon(icon, size: 21, color: AppColors.textPrimary),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14.5, color: AppColors.textPrimary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (hint != null)
            Text(
              hint!,
              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          const SizedBox(width: 6),
          const Icon(
            Iconsax.arrow_right_3,
            size: 17,
            color: AppColors.textHint,
          ),
        ],
      ),
    );
  }
}
