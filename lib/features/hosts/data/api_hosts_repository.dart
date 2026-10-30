import '../../../core/network/api_client.dart';
import '../../orders/models/live_order.dart';
import '../models/host_card.dart';
import '../models/proposal_card.dart';
import 'hosts_repository.dart';

class ApiHostsRepository implements HostsRepository {
  ApiHostsRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<HostCard>> fetchHosts() async {
    final List<dynamic> json = await _client.get('/hosts') as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(HostCard.fromJson)
        .toList(growable: false);
  }

  @override
  Future<HostCard> fetchHost(String hostId) async {
    return HostCard.fromJson(
      await _client.get('/hosts/$hostId') as Map<String, dynamic>,
    );
  }

  @override
  Future<List<ProposalCard>> fetchProposals() async {
    final List<dynamic> json =
        await _client.get('/proposals') as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(ProposalCard.fromJson)
        .toList(growable: false);
  }

  @override
  Future<ProposalCard> createProposal({
    required String title,
    required String sceneTag,
    String imageUrl = '',
    String area = '',
  }) async {
    return ProposalCard.fromJson(
      await _client.post(
        '/proposals',
        body: <String, dynamic>{
          'title': title,
          'sceneTag': sceneTag,
          if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
          if (area.isNotEmpty) 'area': area,
        },
      ) as Map<String, dynamic>,
    );
  }

  @override
  Future<InvitationRecord> invite({
    required String hostId,
    required String sceneTag,
    required String note,
  }) async {
    return InvitationRecord.fromJson(
      await _client.post(
        '/invitations',
        body: <String, dynamic>{
          'hostId': hostId,
          'sceneTag': sceneTag,
          'note': note,
        },
      ) as Map<String, dynamic>,
    );
  }

  @override
  Future<List<InvitationRecord>> fetchInvitations() async {
    final List<dynamic> json =
        await _client.get('/invitations') as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(InvitationRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<LiveOrder?> acceptInvitation(String invitationId) async {
    return LiveOrder.fromJson(
      await _client.post('/invitations/$invitationId/accept')
          as Map<String, dynamic>,
    );
  }

  @override
  Future<InvitationRecord> declineInvitation(String invitationId) async {
    return InvitationRecord.fromJson(
      await _client.post('/invitations/$invitationId/decline')
          as Map<String, dynamic>,
    );
  }
}
