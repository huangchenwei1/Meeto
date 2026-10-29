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
    test('pay -> plan -> meet -> settle mirrors the server flow', () async {
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

      // Meet: I confirm, the simulated peer follows, escrow starts settling.
      updated = await repository.confirmMeet(active.id, lat: 14.55, lng: 121);
      expect(updated.metConfirmedBy('user-100'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 1700));
      updated = await repository.getOrder(active.id);
      expect(updated.status, 'MET');
      expect(updated.metAt, isNotNull);
      expect(updated.settleAt, isNotNull);

      // Messages persist per order.
      await repository.sendMessage(active.id, 'See you there!');
      final List<OrderMessage> messages =
          await repository.listMessages(active.id);
      expect(messages.last.text, 'See you there!');
      expect(messages.last.senderId, 'user-100');
    });

    test('cancel and dispute are terminal side exits', () async {
      final MockOrdersRepository repository = MockOrdersRepository();
      final List<LiveOrder> orders = await repository.listMine();
      final LiveOrder active =
          orders.firstWhere((LiveOrder o) => o.status == 'ACTIVE');

      final LiveOrder disputed = await repository.dispute(active.id);
      expect(disputed.status, 'DISPUTED');
      expect(disputed.disputed, isTrue);

      final LiveOrder completed =
          orders.firstWhere((LiveOrder o) => o.status == 'COMPLETED');
      expect(completed.settleAt, isNotNull);
    });
  });
}
