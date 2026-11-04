import 'package:flutter_test/flutter_test.dart';
import 'package:meeto/core/network/api_client.dart';
import 'package:meeto/core/session/auth_session.dart';
import 'package:meeto/features/orders/data/orders_repository.dart';
import 'package:meeto/features/orders/models/live_order.dart';

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

  group('MockOrdersRepository state machine', () {
    test('locked plan -> meet code -> timed settle mirrors the server flow',
        () async {
      final MockOrdersRepository repository = MockOrdersRepository();

      // Seeded demo orders: one in progress, one completed.
      final List<LiveOrder> orders = await repository.listMine();
      expect(orders.length, 2);
      expect(
        orders.map((LiveOrder o) => o.status),
        containsAll(<String>['ACTIVE', 'COMPLETED']),
      );

      final LiveOrder active = orders
          .firstWhere((LiveOrder o) => o.status == 'ACTIVE');
      expect(active.isPayer('user-100'), isTrue);
      expect(active.planConfirmed, isTrue);
      // Phone contact unlocks once escrowed.
      expect(active.earnerPhone, isNotEmpty);

      // The payer (demo user) sees the meet code; it is a 4-digit string.
      expect(active.meetCode, matches(RegExp(r'^\d{4}$')));

      // The plan was locked at the deal moment: the card already carries
      // the effective place and time, and the stream opens with the one
      // frozen plan card.
      expect(active.place, isNotEmpty);
      expect(active.scheduledAt, isNotNull);
      final List<OrderMessage> stream =
          await repository.listMessages(active.id);
      expect(stream.where((OrderMessage m) => m.isPlanCard).length, 1);

      // Messages persist per order.
      await repository.sendMessage(active.id, 'See you there!');
      final List<OrderMessage> messages =
          await repository.listMessages(active.id);
      expect(messages.last.text, 'See you there!');
      expect(messages.last.senderId, 'user-100');

      // A wrong meet code bounces; the right one starts the service,
      // which then settles by itself once the planned duration (3 hours
      // here) runs out — nothing left for the test clock to observe yet.
      await expectLater(
        repository.start(active.id, 'nope'),
        throwsA(isA<ApiException>()),
      );
      LiveOrder updated = await repository.start(active.id, active.meetCode);
      expect(updated.started, isTrue);
      expect(updated.status, 'ACTIVE');

      // The conversation dies with the activity: the seeded settled order
      // is read-only while its history stays readable.
      final LiveOrder completed = orders
          .firstWhere((LiveOrder o) => o.status == 'COMPLETED');
      await expectLater(
        repository.sendMessage(completed.id, 'too late'),
        throwsA(isA<ApiException>()),
      );
      final List<OrderMessage> history =
          await repository.listMessages(completed.id);
      expect(history, isNotEmpty);
    });

    test('the cancel window and the started lock guard the escrow',
        () async {
      final MockOrdersRepository repository = MockOrdersRepository();
      final List<LiveOrder> orders = await repository.listMine();
      final LiveOrder active =
          orders.firstWhere((LiveOrder o) => o.status == 'ACTIVE');

      // The demo order was paid 19 hours ago: the 30-minute cancel window
      // is long shut for both sides.
      expect(active.cancellableNow, isFalse);
      await expectLater(
        repository.cancel(active.id),
        throwsA(isA<ApiException>()),
      );

      // Once the meet code is in, cancelling is impossible forever.
      await repository.start(active.id, active.meetCode);
      await expectLater(
        repository.cancel(active.id),
        throwsA(isA<ApiException>()),
      );

      final LiveOrder completed =
          orders.firstWhere((LiveOrder o) => o.status == 'COMPLETED');
      expect(completed.completedAt, isNotNull);
    });
  });
}
