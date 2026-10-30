import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeto/core/constants/app_strings.dart';
import 'package:meeto/core/session/auth_session.dart';
import 'package:meeto/features/community/data/community_repository.dart';
import 'package:meeto/features/gigs/pages/gigs_page.dart';
import 'package:meeto/features/hosts/data/hosts_repository.dart';
import 'package:meeto/features/orders/data/orders_repository.dart';
import 'package:meeto/features/profile/data/profile_repository.dart';

void main() {
  group('Gig hall (host work surface)', () {
    setUp(() {
      AuthSession.setUser(
        id: 'host-204',
        name: 'James',
        avatarUrl: '',
        meta: 'Male \u00b7 28',
        gender: 'MALE',
        role: 'HOST',
      );
    });

    Future<void> pumpGigs(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GigsPage(
            communityRepository: MockCommunityRepository(),
            profileRepository: MockProfileRepository(),
            hostsRepository: MockHostsRepository(),
            ordersRepository: MockOrdersRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists only OPEN requests with net earnings',
        (WidgetTester tester) async {
      await pumpGigs(tester);

      // OPEN demand posts appear as gigs, newest first.
      expect(
        find.text('Show me a cafe worth leaving BGC for'),
        findsOneWidget,
      );
      expect(
        find.text('Plan me a Japanese dinner I cannot find on my own'),
        findsOneWidget,
      );

      // The host sees the net payout, not the poster's budget: Coffee is
      // PHP 600 minus the 10% commission.
      expect(find.text(AppStrings.gigEarnLine('\u20b1540')), findsOneWidget);
      expect(find.text(AppStrings.gigPitchCta), findsWidgets);

      // In-progress activities and moments stay on the community wall only.
      expect(find.text('Movie night with an actual plan'), findsNothing);
      expect(find.textContaining('omakase counter'), findsNothing);
    });
  });
}
