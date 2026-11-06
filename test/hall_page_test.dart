import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeto/core/constants/app_strings.dart';
import 'package:meeto/core/session/auth_session.dart';
import 'package:meeto/features/community/data/community_repository.dart';
import 'package:meeto/features/hall/pages/hall_page.dart';
import 'package:meeto/features/hosts/data/hosts_repository.dart';
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

      // Demand posts appear with the pitch pill; requests stay listed
      // through their whole life (only cancelled ones drop out), while
      // moments stay out of the hall. The activity budget rides on the
      // request card: it is the host's core take-the-gig signal.
      expect(
        find.text('Show me a cafe worth leaving BGC for'),
        findsOneWidget,
      );
      expect(find.text('\u00a51,500'), findsWidgets);
      expect(find.text(AppStrings.gigPitchCta), findsWidgets);
      expect(find.textContaining('omakase counter'), findsNothing);

      // Role isolation: other hosts' pitches are invisible to a host —
      // no peeking at competitors' copy and pricing.
      expect(
        find.textContaining('Poblacion \u5929\u53f0\u9152\u5427'),
        findsNothing,
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
      // Role isolation: other users' requests are invisible (the hall is
      // not a bulletin board); Andrea still sees her own post, which
      // carries no pitch pill for her.
      expect(
        find.text('Show me a cafe worth leaving BGC for'),
        findsNothing,
      );
      expect(find.text(AppStrings.gigPitchCta), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Slow Sunday: dessert cafe and no agenda'),
        400,
      );

      // The proposals filter hides her own demand post too.
      await tester.tap(
        find.byKey(const ValueKey<String>('hallFilterPROPOSALS')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Slow Sunday: dessert cafe and no agenda'),
        findsNothing,
      );
    });
  });
}
