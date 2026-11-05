import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/constants/app_strings.dart';
import '../../core/env/app_env.dart';
import '../../core/network/api_client.dart';
import '../community/data/api_community_repository.dart';
import '../community/data/community_repository.dart';
import '../community/pages/activity_community_page.dart';
import '../hall/pages/hall_page.dart';
import '../hosts/data/api_hosts_repository.dart';
import '../hosts/data/hosts_repository.dart';
import '../orders/data/api_orders_repository.dart';
import '../orders/data/orders_repository.dart';
import '../orders/pages/my_activities_page.dart';
import '../profile/data/api_profile_repository.dart';
import '../profile/data/profile_repository.dart';
import '../profile/pages/profile_page.dart';

/// Root scaffold hosting the bottom navigation. Both roles see the same
/// four tabs — the browsing surfaces are identical and only the actions
/// differ by role (users invite and post requests, hosts pitch and take
/// work):
/// - Community: the curated template shelf + the sharing wall (publish
///   entry for both roles).
/// - Hall: the unified activity board where everything published lands.
/// - Messages / Me.
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

  final GlobalKey<ProfilePageState> _profileKey =
      GlobalKey<ProfilePageState>();
  final GlobalKey<ActivityCommunityPageState> _communityKey =
      GlobalKey<ActivityCommunityPageState>();
  final GlobalKey<HallPageState> _hallKey = GlobalKey<HallPageState>();
  final GlobalKey<MyActivitiesPageState> _activitiesKey =
      GlobalKey<MyActivitiesPageState>();

  @override
  void initState() {
    super.initState();
    if (AppEnv.useRemoteApi) {
      final ApiClient apiClient = ApiClient(baseUrl: AppEnv.apiBaseUrl);
      _communityRepository = ApiCommunityRepository(apiClient);
      _profileRepository = ApiProfileRepository(apiClient);
      _hostsRepository = ApiHostsRepository(apiClient);
      _ordersRepository = ApiOrdersRepository(apiClient);
    } else {
      final MockOrdersRepository mockOrders = MockOrdersRepository();
      _communityRepository = MockCommunityRepository(orders: mockOrders);
      _profileRepository = MockProfileRepository();
      _hostsRepository = MockHostsRepository();
      _ordersRepository = mockOrders;
    }
  }

  int _selectedIndex = 0;

  /// Journeys with a counterpart action waiting (signups on my posts,
  /// invites on my pitches); badges the My Activities tab.
  int _actionableCount = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = <Widget>[
      ActivityCommunityPage(
        key: _communityKey,
        communityRepository: _communityRepository,
        profileRepository: _profileRepository,
        hostsRepository: _hostsRepository,
        // A launch lands on the hall; keep it current behind the scenes.
        onPosted: () => _hallKey.currentState?.reload(),
      ),
      HallPage(
        key: _hallKey,
        communityRepository: _communityRepository,
        profileRepository: _profileRepository,
        hostsRepository: _hostsRepository,
        ordersRepository: _ordersRepository,
      ),
      MyActivitiesPage(
        key: _activitiesKey,
        ordersRepository: _ordersRepository,
        communityRepository: _communityRepository,
        hostsRepository: _hostsRepository,
        profileRepository: _profileRepository,
        onActionableCount: (int count) {
          if (count != _actionableCount && mounted) {
            setState(() => _actionableCount = count);
          }
        },
      ),
      ProfilePage(
        key: _profileKey,
        repository: _profileRepository,
        communityRepository: _communityRepository,
        ordersRepository: _ordersRepository,
      ),
    ];
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
          switch (index) {
            case 0:
              _communityKey.currentState?.reload();
            case 1:
              _hallKey.currentState?.reload();
            case 2:
              _activitiesKey.currentState?.reload();
            default:
              _profileKey.currentState?.reload();
          }
        },
        destinations: <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Iconsax.people),
            selectedIcon: Icon(Iconsax.people5),
            label: AppStrings.tabActivityCommunity,
          ),
          const NavigationDestination(
            icon: Icon(Iconsax.home_2),
            selectedIcon: Icon(Iconsax.home_25),
            label: AppStrings.tabHall,
          ),
          NavigationDestination(
            icon: Badge.count(
              count: _actionableCount,
              isLabelVisible: _actionableCount > 0,
              child: const Icon(Iconsax.calendar_1),
            ),
            selectedIcon: Badge.count(
              count: _actionableCount,
              isLabelVisible: _actionableCount > 0,
              child: const Icon(Iconsax.calendar5),
            ),
            label: AppStrings.tabMyActivities,
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
