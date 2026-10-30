import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/constants/app_strings.dart';
import '../../core/env/app_env.dart';
import '../../core/network/api_client.dart';
import '../../core/session/auth_session.dart';
import '../gigs/pages/gigs_page.dart';
import '../hosts/data/api_hosts_repository.dart';
import '../hosts/data/hosts_repository.dart';
import '../hosts/pages/hosts_page.dart';
import '../notifications/data/notifications_repository.dart';
import '../orders/data/api_orders_repository.dart';
import '../orders/data/orders_repository.dart';
import '../orders/pages/orders_page.dart';
import '../community/data/api_community_repository.dart';
import '../community/data/community_repository.dart';
import '../profile/data/api_profile_repository.dart';
import '../community/pages/feed_page.dart';
import '../profile/data/profile_repository.dart';
import '../profile/pages/profile_page.dart';

/// Root scaffold hosting the bottom navigation. The tab set depends on the
/// account role, fixed at registration; each role's first tab is its work
/// surface and the community wall is shared:
/// - USER:  Hosts (find a host) / Community / Messages / Me
/// - HOST:  Requests (gig hall) / Community / Messages / Me
///
/// Repositories are created here and passed down via constructors; the
/// mock/API choice is a build-time switch ([AppEnv.useRemoteApi]).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final CommunityRepository _communityRepository;
  late final ProfileRepository _profileRepository;
  late final HostsRepository _hostsRepository;
  late final OrdersRepository _ordersRepository;
  late final NotificationsRepository _notificationsRepository;

  final GlobalKey<ProfilePageState> _profileKey =
      GlobalKey<ProfilePageState>();
  final GlobalKey<FeedPageState> _feedKey = GlobalKey<FeedPageState>();
  final GlobalKey<HostsPageState> _hostsKey = GlobalKey<HostsPageState>();
  final GlobalKey<GigsPageState> _gigsKey = GlobalKey<GigsPageState>();
  final GlobalKey<OrdersPageState> _messagesKey =
      GlobalKey<OrdersPageState>();

  bool get _isHost => AuthSession.isHost;

  @override
  void initState() {
    super.initState();
    if (AppEnv.useRemoteApi) {
      final ApiClient apiClient = ApiClient(baseUrl: AppEnv.apiBaseUrl);
      _communityRepository = ApiCommunityRepository(apiClient);
      _profileRepository = ApiProfileRepository(apiClient);
      _hostsRepository = ApiHostsRepository(apiClient);
      _ordersRepository = ApiOrdersRepository(apiClient);
      _notificationsRepository = ApiNotificationsRepository(apiClient);
    } else {
      final MockOrdersRepository mockOrders = MockOrdersRepository();
      _communityRepository = MockCommunityRepository(orders: mockOrders);
      _profileRepository = MockProfileRepository();
      _hostsRepository = MockHostsRepository();
      _ordersRepository = mockOrders;
      _notificationsRepository = MockNotificationsRepository();
    }
  }

  int _selectedIndex = 0;

  /// Community sharing wall (identical for both shells).
  Widget get _communityTab => FeedPage(
        key: _feedKey,
        communityRepository: _communityRepository,
        profileRepository: _profileRepository,
      );

  /// Messages tab: the caller's orders plus the notifications inbox.
  Widget get _messagesTab => OrdersPage(
        key: _messagesKey,
        repository: _ordersRepository,
        notificationsRepository: _notificationsRepository,
        communityRepository: _communityRepository,
        profileRepository: _profileRepository,
      );

  Widget get _meTab => ProfilePage(
        key: _profileKey,
        repository: _profileRepository,
        communityRepository: _communityRepository,
        ordersRepository: _ordersRepository,
      );

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = <Widget>[
      if (_isHost)
        GigsPage(
          key: _gigsKey,
          communityRepository: _communityRepository,
          profileRepository: _profileRepository,
          hostsRepository: _hostsRepository,
          ordersRepository: _ordersRepository,
        )
      else
        HostsPage(
          key: _hostsKey,
          repository: _hostsRepository,
          communityRepository: _communityRepository,
        ),
      _communityTab,
      _messagesTab,
      _meTab,
    ];
    const int communityIndex = 1;
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
          if (index == 0) {
            if (_isHost) {
              _gigsKey.currentState?.reload();
            } else {
              _hostsKey.currentState?.reload();
            }
          } else if (index == communityIndex) {
            _feedKey.currentState?.reload();
          } else if (index == meIndex) {
            _profileKey.currentState?.reload();
          } else {
            _messagesKey.currentState?.reload();
          }
        },
        destinations: <NavigationDestination>[
          if (_isHost)
            const NavigationDestination(
              icon: Icon(Iconsax.briefcase),
              selectedIcon: Icon(Iconsax.briefcase5),
              label: AppStrings.tabGigs,
            )
          else
            const NavigationDestination(
              icon: Icon(Iconsax.home_2),
              selectedIcon: Icon(Iconsax.home_25),
              label: AppStrings.tabHosts,
            ),
          const NavigationDestination(
            icon: Icon(Iconsax.people),
            selectedIcon: Icon(Iconsax.people5),
            label: AppStrings.tabCommunity,
          ),
          const NavigationDestination(
            icon: Icon(Iconsax.message),
            selectedIcon: Icon(Iconsax.message5),
            label: AppStrings.tabMessages,
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
