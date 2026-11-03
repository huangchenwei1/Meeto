import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meeto/core/constants/scene_pricing.dart';
import 'package:meeto/features/orders/data/orders_repository.dart';
import 'package:meeto/features/orders/models/live_order.dart';
import 'package:meeto/features/community/data/community_repository.dart';
import 'package:meeto/features/community/models/activity_post.dart';
import 'package:meeto/features/community/models/post_author.dart';

void main() {
  group('Candidate -> selection -> escrow deal flow', () {
    test('publishing gathers candidates with a platform-set fee', () async {
      final MockCommunityRepository repository = MockCommunityRepository();

      final ActivityPost post = await repository.createPost(
        const CreatePostInput(
          sceneTag: 'Dinner',
          title: 'Dinner downtown',
          description: 'Casual dinner',
        ),
      );

      // Pricing is platform-set per scene, not chosen by the poster.
      expect(post.budgetAmount, ScenePricing.defaultBudgetForScene('Dinner'));

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
      final MockCommunityRepository repository = MockCommunityRepository();
      final List<ActivityPost> posts = await repository.fetchOpenRequests();

      final ActivityPost updated = await repository.signUp(
        posts.first.id,
        'Cafe in Makati, Saturday 3pm',
      );
      expect(updated.hasApplied, isTrue);
      expect(updated.signedCount, posts.first.signedCount + 1);
    });

    test('approving a candidate creates the escrow order', () async {
      final MockOrdersRepository ordersRepository = MockOrdersRepository();
      final MockCommunityRepository communityRepository =
          MockCommunityRepository(orders: ordersRepository);

      final ActivityPost post = await communityRepository.createPost(
        const CreatePostInput(
          sceneTag: 'Coffee',
          title: 'Coffee and a walk',
          description: 'Easy afternoon',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final List<PostAuthor> candidates =
          await communityRepository.watchCandidates(post.id).first;
      expect(candidates, isNotEmpty);

      final PostAuthor selected = await communityRepository.selectCandidate(
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
      expect(order.feePesos, post.budgetAmount);
      expect(order.netPesos, ScenePricing.netEarnings(post.budgetAmount));

      final LiveOrder paid = await ordersRepository.pay(order.id);
      expect(paid.status, 'ACTIVE');

      final ActivityPost updated = await communityRepository.fetchPostById(post.id);
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
