import 'package:flutter_test/flutter_test.dart';
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
    test('pay -> plan -> complete mirrors the server flow', () async {
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

      // The host re-proposes; the poster confirms.
      final DateTime at = DateTime.now().add(const Duration(days: 1));
      LiveOrder updated = await repository.proposePlan(
        active.id,
        place: 'Greenbelt Cinema',
        scheduledAt: at,
      );
      expect(updated.planProposed, isTrue);
      expect(updated.planConfirmed, isFalse);
      updated = await repository.confirmPlan(active.id);
      expect(updated.planConfirmed, isTrue);
      expect(updated.place, 'Greenbelt Cinema');

      // Messages persist per order.
      await repository.sendMessage(active.id, 'See you there!');
      final List<OrderMessage> messages =
          await repository.listMessages(active.id);
      expect(messages.last.text, 'See you there!');
      expect(messages.last.senderId, 'user-100');

      // The poster completes single-sidedly; the escrow settles.
      updated = await repository.complete(active.id);
      expect(updated.status, 'COMPLETED');
      expect(updated.completedAt, isNotNull);
    });

    test('cancel is a terminal side exit; seeds carry completedAt', () async {
      final MockOrdersRepository repository = MockOrdersRepository();
      final List<LiveOrder> orders = await repository.listMine();
      final LiveOrder active =
          orders.firstWhere((LiveOrder o) => o.status == 'ACTIVE');

      final LiveOrder cancelled = await repository.cancel(active.id);
      expect(cancelled.status, 'CANCELLED');

      final LiveOrder completed =
          orders.firstWhere((LiveOrder o) => o.status == 'COMPLETED');
      expect(completed.completedAt, isNotNull);
    });
  });
}
