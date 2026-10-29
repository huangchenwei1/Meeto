import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/constants/app_strings.dart';
import '../../core/env/app_env.dart';
import '../../core/network/api_client.dart';
import '../../core/session/auth_session.dart';
import '../chat/data/chat_repository.dart';
import '../chat/pages/chat_list_page.dart';
import '../hosts/data/api_hosts_repository.dart';
import '../hosts/data/hosts_repository.dart';
import '../hosts/pages/hosts_page.dart';
import '../notifications/data/notifications_repository.dart';
import '../orders/data/orders_repository.dart';
import '../orders/pages/orders_page.dart';
import '../partner/data/api_partner_repository.dart';
import '../partner/data/partner_repository.dart';
import '../profile/data/api_profile_repository.dart';
import '../partner/pages/feed_page.dart';
import '../profile/data/profile_repository.dart';
import '../profile/pages/profile_page.dart';

/// Root scaffold hosting the bottom navigation. The tab set depends on the
/// account role, fixed at registration:
/// - USER:  Hosts / Community / Messages / Me
/// - HOST:  Community / Messages / Me
///
/// Repositories are created here and passed down via constructors; the
/// mock/API choice is a build-time switch ([AppEnv.useRemoteApi]).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final PartnerRepository _partnerRepository;
  late final ChatRepository _chatRepository;
  late final ProfileRepository _profileRepository;
  late final HostsRepository _hostsRepository;
  OrdersRepository? _ordersRepository;
  NotificationsRepository? _notificationsRepository;

  final GlobalKey<ProfilePageState> _profileKey =
      GlobalKey<ProfilePageState>();
  final GlobalKey<FeedPageState> _feedKey = GlobalKey<FeedPageState>();
  final GlobalKey<HostsPageState> _hostsKey = GlobalKey<HostsPageState>();

  bool get _isHost => AuthSession.isHost;

  @override
  void initState() {
    super.initState();
    if (AppEnv.useRemoteApi) {
      final ApiClient apiClient = ApiClient(baseUrl: AppEnv.apiBaseUrl);
      _partnerRepository = ApiPartnerRepository(apiClient);
      _chatRepository = MockChatRepository();
      _profileRepository = ApiProfileRepository(apiClient);
      _hostsRepository = ApiHostsRepository(apiClient);
      _ordersRepository = OrdersRepository(apiClient);
      _notificationsRepository = NotificationsRepository(apiClient);
    } else {
      _partnerRepository = MockPartnerRepository();
      _chatRepository = MockChatRepository();
      _profileRepository = MockProfileRepository();
      _hostsRepository = MockHostsRepository();
    }
  }

  int _selectedIndex = 0;

  /// Community feed tab (shared by both shells).
  Widget get _communityTab => FeedPage(
        key: _feedKey,
        partnerRepository: _partnerRepository,
        chatRepository: _chatRepository,
        profileRepository: _profileRepository,
        ordersRepository: _ordersRepository,
      );

  /// Messages tab: live orders in API mode, demo chat in mock mode.
  Widget get _messagesTab => _ordersRepository != null
      ? OrdersPage(
          repository: _ordersRepository!,
          notificationsRepository: _notificationsRepository!,
          partnerRepository: _partnerRepository,
          chatRepository: _chatRepository,
          profileRepository: _profileRepository,
          hostsRepository: _hostsRepository,
        )
      : ChatListPage(repository: _chatRepository);

  Widget get _meTab => ProfilePage(
        key: _profileKey,
        repository: _profileRepository,
        partnerRepository: _partnerRepository,
        chatRepository: _chatRepository,
        ordersRepository: _ordersRepository,
      );

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = _isHost
        ? <Widget>[_communityTab, _messagesTab, _meTab]
        : <Widget>[
            HostsPage(key: _hostsKey, repository: _hostsRepository),
            _communityTab,
            _messagesTab,
            _meTab,
          ];
    final int communityIndex = _isHost ? 0 : 1;
    final int meIndex = tabs.length - 1;
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() => _selectedIndex = index);
          // IndexedStack keeps tabs alive; refresh tab data when it comes
          // back into view so server-side changes are current.
          if (!_isHost && index == 0) {
            _hostsKey.currentState?.reload();
          } else if (index == communityIndex) {
            _feedKey.currentState?.reload();
          } else if (index == meIndex) {
            _profileKey.currentState?.reload();
          }
        },
        destinations: <NavigationDestination>[
          if (!_isHost)
            const NavigationDestination(
              icon: Icon(Iconsax.people),
              selectedIcon: Icon(Iconsax.people5),
              label: AppStrings.tabHosts,
            ),
          const NavigationDestination(
            icon: Icon(Iconsax.home_2),
            selectedIcon: Icon(Iconsax.home_25),
            label: AppStrings.tabCommunity,
          ),
          const NavigationDestination(
            icon: Icon(Iconsax.message),
            selectedIcon: Icon(Iconsax.message5),
            label: AppStrings.tabDates,
          ),
          const NavigationDestination(
            icon: Icon(Iconsax.user),
            selectedIcon: Icon(Iconsax.profile_circle5),
            label: AppStrings.tabMe,
          ),
        ],
      ),
    );
  }
}
