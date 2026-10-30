import '../../orders/models/live_order.dart';
import '../models/host_card.dart';

/// Host directory + direct invitations.
abstract interface class HostsRepository {
  /// Directory of hosts, best credentials first.
  Future<List<HostCard>> fetchHosts();

  Future<HostCard> fetchHost(String hostId);

  /// Sends a direct invitation (user side). The concrete plan still comes
  /// from the host after payment via the standard plan flow.
  Future<InvitationRecord> invite({
    required String hostId,
    required String sceneTag,
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
      hostScenes: <String>['Coffee', 'Tea'],
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
      hostScenes: <String>['Dinner'],
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
      hostScenes: <String>['Movie', 'Tea'],
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
      hostScenes: <String>['Coffee'],
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
      hostScenes: <String>['Bar'],
      completedActivities: 18,
      recentProposals: <String>[
        'Quiet rooftop in Poblacion, Friday 9pm',
      ],
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
  Future<HostCard> fetchHost(String hostId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _hosts.firstWhere((HostCard h) => h.id == hostId);
  }

  @override
  Future<InvitationRecord> invite({
    required String hostId,
    required String sceneTag,
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
