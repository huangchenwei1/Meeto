import '../../orders/models/live_order.dart';
import '../models/host_card.dart';
import '../models/proposal_card.dart';

/// Host directory + activity proposals + direct invitations.
abstract interface class HostsRepository {
  /// Directory of hosts, best credentials first.
  Future<List<HostCard>> fetchHosts();

  Future<HostCard> fetchHost(String hostId);

  /// User home feed: hosts' activity pitches, newest first.
  Future<List<ProposalCard>> fetchProposals();

  /// Publishes an activity pitch (host side). [imageUrl] is the optional
  /// cover photo, already uploaded; [area] the optional rough area.
  Future<ProposalCard> createProposal({
    required String title,
    String description = '',
    required String sceneTag,
    String imageUrl = '',
    String area = '',
  });

  /// Sends a direct invitation (user side). The concrete plan still comes
  /// from the host after payment via the standard plan flow.
  Future<InvitationRecord> invite({
    required String hostId,
    required String sceneTag,

    /// Activity budget tier pick (whole pesos).
    required int budget,
    required String note,
  });

  /// The caller's invitations: received ones for hosts, sent ones for users.
  Future<List<InvitationRecord>> fetchInvitations();

  /// Host accepts: the server creates the order awaiting payment.
  /// Returns null in mock mode (no live order flow there).
  Future<LiveOrder?> acceptInvitation(String invitationId);

  Future<InvitationRecord> declineInvitation(String invitationId);
}

/// Self-contained demo directory so mock mode renders a believable page.
class MockHostsRepository implements HostsRepository {
  static final List<HostCard> _hosts = <HostCard>[
    const HostCard(
      id: 'host-201',
      name: 'Bianca',
      avatarUrl: 'https://i.pravatar.cc/150?img=44',
      meta: 'Female \u00b7 26',
      isVerified: true,
      bio: 'Cafe-hopping host with a running list of the best quiet cafes '
          'in Makati and BGC.',
      city: 'Manila',
      tags: <String>['Coffee', 'Dessert cafes', 'Board games'],
      completedActivities: 12,
      recentProposals: <String>[
        'Hidden cafe inside a Legazpi bookshop, Sunday 2pm',
      ],
    ),
    const HostCard(
      id: 'host-202',
      name: 'Kat',
      avatarUrl: 'https://i.pravatar.cc/150?img=31',
      meta: 'Female \u00b7 28',
      isVerified: true,
      bio: 'Food tour host. Ex-restaurant floor manager; I plan dinners '
          'people still talk about a month later.',
      city: 'Manila',
      tags: <String>['Dinner', 'Japanese food', 'Hidden gems'],
      completedActivities: 21,
      recentProposals: <String>[
        'Omakase counter in Little Tokyo, Thursday 7:30pm',
      ],
    ),
    const HostCard(
      id: 'host-203',
      name: 'Liza',
      avatarUrl: 'https://i.pravatar.cc/150?img=25',
      meta: 'Female \u00b7 25',
      isVerified: true,
      bio: 'Movies and after-talk. I pick the screening, the seats, and '
          'the dessert place for the post-movie debrief.',
      city: 'Manila',
      tags: <String>['Movies', 'Tea', 'Long walks'],
      completedActivities: 15,
      recentProposals: <String>[
        'Director\u2019s cut screening at Power Plant, Saturday 4pm',
      ],
    ),
    const HostCard(
      id: 'host-204',
      name: 'James',
      avatarUrl: 'https://i.pravatar.cc/150?img=13',
      meta: 'Male \u00b7 28',
      isVerified: true,
      bio: 'Specialty coffee host and third-wave cafe regular.',
      city: 'Manila',
      tags: <String>['Coffee', 'Basketball', 'Vinyl'],
      completedActivities: 8,
      recentProposals: <String>[
        'Single Origin in Salcedo, Saturday 3pm',
      ],
    ),
    const HostCard(
      id: 'host-205',
      name: 'Noel',
      avatarUrl: 'https://i.pravatar.cc/150?img=53',
      meta: 'Male \u00b7 30',
      isVerified: true,
      bio: 'Bar crawl host in Poblacion. I know which rooftop is quiet on '
          'a Friday and which whiskey list is actually worth it.',
      city: 'Manila',
      tags: <String>['Bars', 'Whiskey', 'Live music'],
      completedActivities: 18,
      recentProposals: <String>[
        'Quiet rooftop in Poblacion, Friday 9pm',
      ],
    ),
  ];

  static final List<ProposalCard> _proposals = <ProposalCard>[
    ProposalCard(
      id: 'proposal-101',
      title: '\u5468\u4e94\u665a Poblacion \u5929\u53f0\u9152\u5427\uff0c\u5e26\u4f60\u559d\u61c2\u672c\u5730\u7cbe\u917f',
      description: '认识几家本地精酿厂牌，从酒单讲到酿法，微醺收尾',
      sceneTag: 'Bar',
      imageUrl:
          'https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=800&h=800&q=80',
      area: 'Poblacion',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      hostId: 'host-205',
      hostName: 'Noel',
      hostAvatarUrl: 'https://i.pravatar.cc/150?img=53',
      hostMeta: '\u7537 \u00b7 30',
      hostCity: 'Manila',
      hostIsVerified: true,
      hostCompletedActivities: 18,
    ),
    ProposalCard(
      id: 'proposal-102',
      title: '\u53bb Legazpi \u4e66\u5e97\u91cc\u7684\u9690\u85cf\u5496\u5561\u9986\uff0c\u5750\u4e00\u4e2a\u5b89\u9759\u7684\u4e0b\u5348',
      description: '书店里的隐藏咖啡吧台，豆子好，人少安静，适合聊天',
      sceneTag: 'Coffee',
      imageUrl:
          'https://images.unsplash.com/photo-1481833761820-0509d3217039?auto=format&fit=crop&w=800&h=800&q=80',
      area: 'Legazpi Village',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      hostId: 'host-201',
      hostName: 'Bianca',
      hostAvatarUrl: 'https://i.pravatar.cc/150?img=44',
      hostMeta: '\u5973 \u00b7 26',
      hostCity: 'Manila',
      hostIsVerified: true,
      hostCompletedActivities: 12,
    ),
    ProposalCard(
      id: 'proposal-103',
      title: '\u5c0f\u4e1c\u4eac 12 \u5ea7\u677f\u524d\u65e5\u6599\uff0c\u6211\u77e5\u9053\u6d77\u80c6\u54ea\u5929\u6700\u65b0\u9c9c',
      description: '板前只有 12 个座位，主厨是老朋友，当天最新鲜的交给他',
      sceneTag: 'Dinner',
      imageUrl:
          'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=800&h=800&q=80',
      area: 'Little Tokyo',
      createdAt: DateTime.now().subtract(const Duration(hours: 9)),
      hostId: 'host-202',
      hostName: 'Kat',
      hostAvatarUrl: 'https://i.pravatar.cc/150?img=31',
      hostMeta: '\u5973 \u00b7 28',
      hostCity: 'Manila',
      hostIsVerified: true,
      hostCompletedActivities: 21,
    ),
    ProposalCard(
      id: 'proposal-104',
      title: '\u53bb\u770b\u4e00\u573a\u5bfc\u6f14\u526a\u8f91\u7248\uff0c\u6563\u573a\u540e\u627e\u5bb6\u751c\u54c1\u5e97\u804a\u5230\u6253\u70ca',
      description: '选片选座我来，散场后的甜品店也订好，只管来',
      sceneTag: 'Movie',
      imageUrl:
          'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&h=800&q=80',
      area: 'Rockwell',
      createdAt: DateTime.now().subtract(const Duration(hours: 20)),
      hostId: 'host-203',
      hostName: 'Liza',
      hostAvatarUrl: 'https://i.pravatar.cc/150?img=25',
      hostMeta: '\u5973 \u00b7 25',
      hostCity: 'Manila',
      hostIsVerified: true,
      hostCompletedActivities: 15,
    ),
  ];

  final List<InvitationRecord> _sent = <InvitationRecord>[];
  int _sequence = 0;

  @override
  Future<List<HostCard>> fetchHosts() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List<HostCard>.of(_hosts);
  }

  @override
  Future<List<ProposalCard>> fetchProposals() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List<ProposalCard>.of(_proposals);
  }

  @override
  Future<ProposalCard> createProposal({
    required String title,
    String description = '',
    required String sceneTag,
    String imageUrl = '',
    String area = '',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _sequence += 1;
    final ProposalCard created = ProposalCard(
      id: 'proposal-new-$_sequence',
      title: title,
      description: description,
      sceneTag: sceneTag,
      imageUrl: imageUrl,
      area: area,
      createdAt: DateTime.now(),
      hostId: 'host-you',
      hostName: 'You',
      hostAvatarUrl: '',
      hostMeta: '',
      hostIsVerified: true,
      hostCompletedActivities: 0,
    );
    _proposals.insert(0, created);
    return created;
  }

  @override
  Future<HostCard> fetchHost(String hostId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _hosts.firstWhere((HostCard h) => h.id == hostId);
  }

  @override
  Future<InvitationRecord> invite({
    required String hostId,
    required String sceneTag,
    required int budget,
    required String note,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final HostCard host = await fetchHost(hostId);
    _sequence += 1;
    final InvitationRecord record = InvitationRecord(
      id: 'invitation-$_sequence',
      sceneTag: sceneTag,
      note: note,
      status: 'PENDING',
      fromName: 'You',
      fromAvatarUrl: '',
      fromMeta: '',
      hostName: host.name,
      orderId: '',
      createdAt: DateTime.now(),
    );
    _sent.insert(0, record);
    return record;
  }

  @override
  Future<List<InvitationRecord>> fetchInvitations() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return List<InvitationRecord>.of(_sent);
  }

  @override
  Future<LiveOrder?> acceptInvitation(String invitationId) async {
    return null;
  }

  @override
  Future<InvitationRecord> declineInvitation(String invitationId) async {
    return _sent.firstWhere((InvitationRecord i) => i.id == invitationId);
  }
}
