import 'package:flutter_test/flutter_test.dart';
import 'package:meeto/core/network/api_client.dart';
import 'package:meeto/core/session/auth_session.dart';
import 'package:meeto/features/hosts/data/hosts_repository.dart';
import 'package:meeto/features/hosts/models/host_card.dart';
import 'package:meeto/features/hosts/models/proposal_card.dart';

void main() {
  setUp(() {
    AuthSession.setUser(
      id: 'user-100',
      name: 'Andrea',
      avatarUrl: '',
      meta: 'Female \u00b7 24',
      gender: 'FEMALE',
      role: 'USER',
    );
  });

  group('MockHostsRepository proposal invite machine', () {
    test('inviting queues once per user and marks the card', () async {
      final MockHostsRepository repository = MockHostsRepository();
      final List<ProposalCard> feed = await repository.fetchProposals();
      final ProposalCard pitch = feed.first;
      expect(pitch.isOpen, isTrue);
      expect(pitch.hasInvited, isFalse);

      final InvitationRecord sent = await repository.inviteToProposal(
        pitch.id,
        note: 'Friday works for me',
      );
      expect(sent.isPending, isTrue);
      expect(sent.fromId, 'user-100');

      // The decorated card now carries the queue state.
      final ProposalCard updated = await repository.fetchProposal(pitch.id);
      expect(updated.hasInvited, isTrue);
      expect(updated.inviteCount, 1);

      // One pending invitation per user per pitch.
      await expectLater(
        repository.inviteToProposal(pitch.id),
        throwsA(isA<ApiException>()),
      );
    });

    test('selection takes the pitch off the market', () async {
      final MockHostsRepository repository = MockHostsRepository();
      final ProposalCard pitch = (await repository.fetchProposals()).first;
      final InvitationRecord sent =
          await repository.inviteToProposal(pitch.id, note: 'Pick me');

      await repository.selectInvite(pitch.id, sent.id);

      // The pitch left the hall feed and refuses late invitations.
      final List<ProposalCard> feed = await repository.fetchProposals();
      expect(feed.any((ProposalCard p) => p.id == pitch.id), isFalse);
      await expectLater(
        repository.inviteToProposal(pitch.id, note: 'too late'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
