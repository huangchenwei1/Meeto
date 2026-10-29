import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meeto/core/constants/scene_pricing.dart';
import 'package:meeto/features/orders/data/orders_repository.dart';
import 'package:meeto/features/orders/models/live_order.dart';
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

    test('approving a candidate creates the escrow order', () async {
      final MockOrdersRepository ordersRepository = MockOrdersRepository();
      final MockPartnerRepository partnerRepository =
          MockPartnerRepository(orders: ordersRepository);

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

      // Selection creates the AWAITING_PAYMENT order; paying activates it
      // and the wall post carries the host attribution.
      final LiveOrder? order = await ordersRepository.findByPostId(post.id);
      expect(order, isNotNull);
      expect(order!.status, 'AWAITING_PAYMENT');
      expect(order.earner.id, selected.id);
      expect(order.feePesos, post.tipAmount);
      expect(order.netPesos, ScenePricing.netEarnings(post.tipAmount));

      final LiveOrder paid = await ordersRepository.pay(order.id);
      expect(paid.status, 'ACTIVE');

      final DatePost updated = await partnerRepository.fetchPostById(post.id);
      expect(updated.status, 'MATCHED');
      expect(updated.selectedHost?.id, selected.id);
    });

    test('settlement pays out the fee minus the platform commission', () {
      expect(ScenePricing.netEarnings(1000), 900);
      expect(ScenePricing.netEarnings(1400), 1260);
      expect(ScenePricing.netEarnings(650), 585);
    });
  });
}
