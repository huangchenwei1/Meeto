import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meeto/features/chat/data/chat_repository.dart';
import 'package:meeto/features/chat/models/date_order.dart';

void main() {
  group('MockChatRepository order state machine', () {
    test('depart -> arrive -> complete advances both sides', () async {
      final MockChatRepository repository = MockChatRepository();
      const String id = 'conv-rafael';

      final List<ConversationSnapshot> snapshots = <ConversationSnapshot>[];
      final StreamSubscription<ConversationSnapshot> sub =
          repository.watchConversation(id).listen(snapshots.add);
      addTearDown(sub.cancel);

      // Initial snapshot: both ready.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(snapshots.last.conversation.order!.myStage, OrderStage.ready);
      expect(snapshots.last.conversation.order!.peerStage, OrderStage.ready);

      // Depart: I am en route; the simulated peer follows.
      await repository.departOrder(id);
      await _pumpEvents();
      expect(snapshots.last.conversation.order!.myStage, OrderStage.enRoute);
      await Future<void>.delayed(const Duration(milliseconds: 1700));
      expect(snapshots.last.conversation.order!.peerStage, OrderStage.enRoute);

      // Arrive: I check in; the simulated peer follows.
      await repository.arriveOrder(id);
      await _pumpEvents();
      expect(snapshots.last.conversation.order!.myStage, OrderStage.arrived);
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      expect(snapshots.last.conversation.order!.peerStage, OrderStage.arrived);
      expect(snapshots.last.conversation.order!.bothArrived, isTrue);

      // Complete: settles after the simulated peer confirmation.
      await repository.completeOrder(id);
      await _pumpEvents();
      expect(snapshots.last.conversation.order!.isCompleted, isTrue);

      // Completed event card is appended and highlighted.
      expect(snapshots.last.messages.last.isHighlighted, isTrue);
    });
  });
}

/// Lets queued stream events reach listeners before asserting.
Future<void> _pumpEvents() =>
    Future<void>.delayed(const Duration(milliseconds: 20));
