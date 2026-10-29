import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';
import '../models/chat_message.dart';
import '../models/date_order.dart';
import 'map_preview.dart';

/// System order event rendered inside the message list (deal confirmed,
/// departed, both arrived, completed...).
class OrderEventCard extends StatelessWidget {
  const OrderEventCard({super.key, required this.message, this.order});

  final ChatMessage message;

  /// Needed when [ChatMessage.showsMap] is true.
  final DateOrder? order;

  static const Map<OrderEventIcon, IconData> _icons =
      <OrderEventIcon, IconData>{
    OrderEventIcon.deal: Iconsax.verify,
    OrderEventIcon.escrow: Iconsax.shield_tick,
    OrderEventIcon.enRoute: Iconsax.send_2,
    OrderEventIcon.arrived: Iconsax.location,
    OrderEventIcon.completed: Iconsax.wallet_3,
  };

  @override
  Widget build(BuildContext context) {
    final bool highlighted = message.isHighlighted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.accentSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                _icons[message.eventIcon]!,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      message.eventTitle ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message.eventSubtitle ?? '',
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (message.showsMap && order != null) ...<Widget>[
            const SizedBox(height: 10),
            MapPreview(order: order!),
          ],
        ],
      ),
    );
  }
}
