import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meeto/core/constants/scene_pricing.dart';
import 'package:meeto/features/chat/data/chat_repository.dart';
import 'package:meeto/features/chat/models/chat_message.dart';
import 'package:meeto/features/chat/models/conversation.dart';
import 'package:meeto/features/partner/data/partner_repository.dart';
import 'package:meeto/features/partner/models/date_post.dart';
import 'package:meeto/features/partner/models/post_author.dart';

void main() {
  group('Candidate -> selection -> escrow deal flow', () {
    test('publishing gathers candidates with a platform-set fee', () async {
      final MockPartnerRepository repository = MockPartnerRepository();

      final DatePost post = await repository.createPost(
        const CreatePostInput(
          sceneTag: 'Dinner',
          title: 'Dinner downtown',
          description: 'Casual dinner',
          timeText: 'Tonight 8:00 PM',
          place: 'BGC',
        ),
      );

      // Pricing is platform-set per scene, not chosen by the poster.
      expect(post.tipAmount, ScenePricing.feeForScene('Dinner'));

      final List<List<PostAuthor>> emissions = <List<PostAuthor>>[];
      final StreamSubscription<List<PostAuthor>> sub =
          repository.watchCandidates(post.id).listen(emissions.add);
      addTearDown(sub.cancel);

      // Simulated male candidates arrive shortly after publishing.
      await Future<void>.delayed(const Duration(milliseconds: 3000));
      expect(emissions.last.length, 2);
      expect(emissions.last.every((PostAuthor c) => c.isVerified), isTrue);
    });

    test('sign-up marks the current user as an applied candidate', () async {
      final MockPartnerRepository repository = MockPartnerRepository();
      final List<DatePost> posts = await repository.fetchPosts();

      final DatePost updated = await repository.signUp(
        posts.first.id,
        'Cafe in Makati, Saturday 3pm',
      );
      expect(updated.hasApplied, isTrue);
      expect(updated.signedCount, posts.first.signedCount + 1);
    });

    test('approving a candidate creates an escrow deal conversation',
        () async {
      final MockPartnerRepository partnerRepository = MockPartnerRepository();
      final MockChatRepository chatRepository = MockChatRepository();

      final DatePost post = await partnerRepository.createPost(
        const CreatePostInput(
          sceneTag: 'Coffee',
          title: 'Coffee and a walk',
          description: 'Easy afternoon',
          timeText: 'Saturday 3:00 PM',
          place: 'Makati',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final List<PostAuthor> candidates =
          await partnerRepository.watchCandidates(post.id).first;
      expect(candidates, isNotEmpty);

      final PostAuthor selected = await partnerRepository.selectCandidate(
        post.id,
        candidates.first.id,
      );
      expect(selected.id, candidates.first.id);

      final List<Conversation> before =
          await chatRepository.fetchConversations();
      final Conversation conversation =
          await chatRepository.createDealConversation(
        post: post,
        payer: selected,
      );
      final List<Conversation> after =
          await chatRepository.fetchConversations();

      expect(after.length, before.length + 1);
      expect(after.first.id, conversation.id);
      expect(conversation.peerName, selected.name);
      expect(conversation.order!.tipAmount, post.tipAmount);
      expect(conversation.order!.isCompleted, isFalse);

      // History opens with the deal card followed by the escrow card.
      final ConversationSnapshot snapshot =
          await chatRepository.watchConversation(conversation.id).first;
      expect(snapshot.messages[0].eventIcon, OrderEventIcon.deal);
      expect(snapshot.messages[1].eventIcon, OrderEventIcon.escrow);

      // Re-approving the same payer must not duplicate the conversation.
      final Conversation duplicate =
          await chatRepository.createDealConversation(
        post: post,
        payer: selected,
      );
      expect(duplicate.id, conversation.id);
      expect(
        (await chatRepository.fetchConversations()).length,
        after.length,
      );
    });

    test('settlement pays out the fee minus the platform commission', () {
      expect(ScenePricing.netEarnings(1000), 900);
      expect(ScenePricing.netEarnings(1400), 1260);
      expect(ScenePricing.netEarnings(650), 585);
    });
  });
}
