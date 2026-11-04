import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeto/core/constants/app_strings.dart';
import 'package:meeto/core/session/auth_session.dart';
import 'package:meeto/features/community/data/community_repository.dart';
import 'package:meeto/features/hall/pages/hall_page.dart';
import 'package:meeto/features/hosts/data/hosts_repository.dart';
import 'package:meeto/features/notifications/data/notifications_repository.dart';
import 'package:meeto/features/orders/data/orders_repository.dart';
import 'package:meeto/features/profile/data/profile_repository.dart';

void main() {
  Future<void> pumpHall(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HallPage(
          communityRepository: MockCommunityRepository(),
          profileRepository: MockProfileRepository(),
          hostsRepository: MockHostsRepository(),
          ordersRepository: MockOrdersRepository(),
          notificationsRepository: MockNotificationsRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Dating hall (unified board)', () {
    testWidgets('host view: requests are actionable, proposals read-only',
        (WidgetTester tester) async {
      AuthSession.setUser(
        id: 'host-204',
        name: 'James',
        avatarUrl: '',
        meta: 'Male \u00b7 28',
        gender: 'MALE',
        role: 'HOST',
      );
      await pumpHall(tester);

      // Open demand posts appear with the pitch pill; in-progress
      // activities and moments stay out. The activity budget rides on the
      // request card: it is the host's core take-the-gig signal.
      expect(
        find.text('Show me a cafe worth leaving BGC for'),
        findsOneWidget,
      );
      expect(find.text('\u20b11,500'), findsWidgets);
      expect(find.text(AppStrings.gigPitchCta), findsWidgets);
      expect(find.text('Movie night with an actual plan'), findsNothing);
      expect(find.textContaining('omakase counter'), findsNothing);

      // Host proposals are visible but carry no invite pill for a host.
      await tester.scrollUntilVisible(
        find.textContaining('Poblacion \u5929\u53f0\u9152\u5427'),
        400,
      );
      expect(find.text(AppStrings.hostInviteCta), findsNothing);
    });

    testWidgets('user view: proposals lead and carry the invite pill',
        (WidgetTester tester) async {
      AuthSession.setUser(
        id: 'user-100',
        name: 'Andrea',
        avatarUrl: '',
        meta: 'Female \u00b7 24',
        gender: 'FEMALE',
        role: 'USER',
      );
      await pumpHall(tester);

      // Actionable first for users: proposals on top, with invite pills.
      expect(
        find.textContaining('Poblacion \u5929\u53f0\u9152\u5427'),
        findsOneWidget,
      );
      expect(find.text(AppStrings.hostInviteCta), findsWidgets);
      // Other users' requests are browse-only: no pitch pill anywhere.
      expect(find.text(AppStrings.gigPitchCta), findsNothing);

      // The proposals filter hides demand posts.
      await tester.tap(
        find.byKey(const ValueKey<String>('hallFilterPROPOSALS')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Show me a cafe worth leaving BGC for'),
        findsNothing,
      );
    });
  });
}
