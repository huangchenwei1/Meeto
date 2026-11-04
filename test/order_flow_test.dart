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
    test('plan -> meet code -> timed settle mirrors the server flow',
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

      // The host re-proposes; the poster confirms. A zero duration makes
      // the started service settle on the very next read (test clock).
      final DateTime at = DateTime.now().add(const Duration(days: 1));
      LiveOrder updated = await repository.proposePlan(
        active.id,
        place: 'Greenbelt Cinema',
        scheduledAt: at,
        note: 'Dinner first, then the 8pm screening',
        durationMinutes: 0,
      );
      expect(updated.planProposed, isTrue);
      expect(updated.planConfirmed, isFalse);
      expect(updated.planNote, 'Dinner first, then the 8pm screening');
      // Each proposal drops a plan card message into the stream.
      final List<OrderMessage> stream = await repository.listMessages(active.id);
      expect(stream.where((OrderMessage m) => m.isPlanCard).length, 2);
      updated = await repository.confirmPlan(active.id);
      expect(updated.planConfirmed, isTrue);
      expect(updated.place, 'Greenbelt Cinema');

      // Messages persist per order.
      await repository.sendMessage(active.id, 'See you there!');
      final List<OrderMessage> messages =
          await repository.listMessages(active.id);
      expect(messages.last.text, 'See you there!');
      expect(messages.last.senderId, 'user-100');

      // A wrong meet code bounces; the right one starts the service.
      await expectLater(
        repository.start(active.id, 'nope'),
        throwsA(isA<ApiException>()),
      );
      updated = await repository.start(active.id, active.meetCode);
      expect(updated.started, isTrue);

      // The planned duration (zero here) runs out: the escrow settles on
      // the next read with nobody tapping anything.
      updated = await repository.getOrder(active.id);
      expect(updated.status, 'COMPLETED');
      expect(updated.completedAt, isNotNull);

      // The conversation dies with the activity: read-only afterwards.
      await expectLater(
        repository.sendMessage(active.id, 'too late'),
        throwsA(isA<ApiException>()),
      );
      final List<OrderMessage> history =
          await repository.listMessages(active.id);
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
