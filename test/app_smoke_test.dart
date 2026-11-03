import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meeto/app.dart';
import 'package:meeto/core/constants/app_strings.dart';

void main() {
  testWidgets('all user-side tabs render with mock data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MeetoApp());
    await tester.pumpAndSettle();

    // Login first: phone -> fixed demo OTP -> home. The demo persona is a
    // USER-side account, so the shell shows the 4-tab layout.
    await tester.enterText(
      find.byKey(const ValueKey<String>('loginPhoneField')),
      '9170000100',
    );
    await tester.tap(find.byKey(const ValueKey<String>('loginContinueButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('otpCodeField')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey<String>('otpVerifyButton')));
    await tester.pumpAndSettle();

    // Community tab (default): the curated template shelf — the only
    // publish entry — plus the sharing wall behind the second header tab.
    expect(find.text(AppStrings.hotActivitiesTab), findsOneWidget);
    expect(find.text('Salcedo 周末市集咖啡散步'), findsOneWidget);
    expect(find.text(AppStrings.templateLaunchCta), findsWidgets);
    await tester.tap(
      find.byKey(const ValueKey<String>('communityTabShares')),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.bannerCta), findsOneWidget);
    // The WeChat-Moments-style cells are taller, so only the newest recap
    // fits the test viewport: assert its text plus the venue line.
    expect(find.textContaining('hidden inside a bookshop'), findsOneWidget);
    expect(find.textContaining('Solidaridad Bookshop'), findsOneWidget);
    expect(
      find.text('Show me a cafe worth leaving BGC for'),
      findsNothing,
    );

    // Hall tab: the unified board. For a USER persona the host proposals
    // lead with invite pills; demand posts from other users are browse-only.
    await tester.tap(find.byIcon(Iconsax.home_2));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.hallTitle), findsOneWidget);
    expect(find.text(AppStrings.hostInviteCta), findsWidgets);

    // Messages tab: demo orders with status pills (same OrdersPage as API
    // mode). The nav bar is icon-only, so tabs are addressed by icon.
    await tester.tap(find.byIcon(Iconsax.message));
    await tester.pumpAndSettle();
    expect(find.text('Liza'), findsOneWidget);
    expect(find.text(AppStrings.statusActive), findsOneWidget);
    expect(find.text('Bianca'), findsOneWidget);
    expect(find.text(AppStrings.statusCompleted), findsOneWidget);

    // Me tab: menu renders; the wallet is host-side only, so the USER
    // persona must not see it.
    await tester.tap(find.byIcon(Iconsax.user));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.walletLabel), findsNothing);
    expect(find.text(AppStrings.menuMyPosts), findsOneWidget);
  });
}
