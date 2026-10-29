import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax/iconsax.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meeto/app.dart';
import 'package:meeto/core/constants/app_strings.dart';

/// End-to-end walkthrough across all pages, capturing screenshots along the
/// way (saved by the driver in `test_driver/integration_test.dart`).
void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full demo walkthrough', (WidgetTester tester) async {
    await tester.pumpWidget(const MeetoApp());
    await tester.pumpAndSettle();
    await binding.takeScreenshot('00-login');

    // Sign in: Andrea's seeded phone + the fixed demo OTP. Mock mode accepts
    // the same inputs, so one script drives both modes.
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
    await binding.takeScreenshot('00b-login-otp');
    await tester.tap(find.byKey(const ValueKey<String>('otpVerifyButton')));
    await tester.pumpAndSettle();

    await _settleImages(tester);
    await binding.takeScreenshot('01-home-feed');

    // Post detail.
    await tester.tap(find.text('Coffee date at a new cafe'));
    await tester.pumpAndSettle();
    await _settleImages(tester);
    await binding.takeScreenshot('02-post-detail');

    // Sign up for the date.
    await tester.tap(find.text(AppStrings.signUpCta));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.signedUpCta), findsOneWidget);
    await binding.takeScreenshot('03-post-signed-up');

    // Author profile (scroll the author card into view first).
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Miguel'));
    await tester.pumpAndSettle();
    await _settleImages(tester);
    await binding.takeScreenshot('04-user-profile');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Iconsax.arrow_left_2));
    await tester.pumpAndSettle();

    // Publish a new post.
    await tester.tap(find.byIcon(Iconsax.add));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('05-publish-form');
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.publishPhTitle),
      'Sunset walk along the bay',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.publishSubmit));
    await tester.pumpAndSettle();
    expect(find.text('Sunset walk along the bay'), findsOneWidget);
    await _settleImages(tester);
    await binding.takeScreenshot('06-feed-with-published-post');

    // Own post: candidates arrive, approve one -> escrow deal conversation.
    await tester.tap(find.text('Sunset walk along the bay'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await _settleImages(tester);
    expect(find.text(AppStrings.approveCta), findsWidgets);
    await binding.takeScreenshot('06b-own-post-candidates');

    await tester.tap(find.text(AppStrings.approveCta).first);
    await tester.pumpAndSettle();
    await _settleImages(tester);
    expect(find.textContaining('held in escrow'), findsWidgets);
    await binding.takeScreenshot('06c-deal-escrow-chat');

    // Run the matched date to completion (in API mode this settles real
    // money on the server: escrow releases, the wallet receives the net).
    await tester.tap(find.text(AppStrings.btnDepart));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.btnArrive));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.btnFinish));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('Date completed'), findsOneWidget);
    await binding.takeScreenshot('06d-deal-completed-settled');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Iconsax.arrow_left_2));
    await tester.pumpAndSettle();

    // Chats list. The nav bar is icon-only, so tabs are addressed by icon.
    await tester.tap(find.byIcon(Iconsax.message));
    await tester.pumpAndSettle();
    await _settleImages(tester);
    await binding.takeScreenshot('07-chat-list');

    // Completed conversation (Marco).
    await tester.tap(find.text('Marco'));
    await tester.pumpAndSettle();
    await _settleImages(tester);
    await binding.takeScreenshot('08-chat-completed-order');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Interactive order flow (Rafael): depart -> arrive -> complete.
    await tester.tap(find.text('Rafael'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('09-chat-booked-order');

    await tester.tap(find.text(AppStrings.btnDepart));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.peerDepartedMsg), findsOneWidget);
    await binding.takeScreenshot('10-order-en-route');

    await tester.tap(find.text(AppStrings.btnArrive));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.meetTitle), findsOneWidget);
    await binding.takeScreenshot('11-order-both-arrived');

    await tester.tap(find.text(AppStrings.btnFinish));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('Date completed'), findsOneWidget);
    await binding.takeScreenshot('12-order-completed');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Me tab.
    await tester.tap(find.byIcon(Iconsax.user));
    await tester.pumpAndSettle();
    await _settleImages(tester);
    await binding.takeScreenshot('13-me-wallet');
  });
}

/// Gives network images a moment to finish loading before a screenshot.
Future<void> _settleImages(WidgetTester tester) async {
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 600));
  }
  await tester.pumpAndSettle();
}
