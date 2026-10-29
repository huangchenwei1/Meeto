import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../models/date_order.dart';

/// Order progress panel pinned above the message list: stage steps, both
/// participants' statuses, and the next action for the current user.
class OrderSyncPanel extends StatelessWidget {
  const OrderSyncPanel({
    super.key,
    required this.order,
    required this.peerName,
    required this.peerAvatarUrl,
    required this.myAvatarUrl,
    required this.isCompleting,
    required this.onDepart,
    required this.onArrive,
    required this.onComplete,
  });

  final DateOrder order;
  final String peerName;
  final String? peerAvatarUrl;
  final String myAvatarUrl;

  /// True while waiting for the peer to confirm completion.
  final bool isCompleting;

  final VoidCallback onDepart;
  final VoidCallback onArrive;
  final VoidCallback onComplete;

  List<bool> get _stageFlags {
    return <bool>[
      true,
      order.myStage.index >= OrderStage.enRoute.index ||
          order.peerStage.index >= OrderStage.enRoute.index,
      order.bothArrived,
      order.isCompleted,
    ];
  }

  String _personStatus(OrderStage stage) {
    if (order.isCompleted) {
      return AppStrings.personStatusDone;
    }
    return AppStrings.personStages[stage.index];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          _StageSteps(flags: _stageFlags),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          _PersonRow(
            avatarUrl: myAvatarUrl,
            name: AppStrings.meLabel,
            status: _personStatus(order.myStage),
            isWaiting: order.myStage == OrderStage.ready && !order.isCompleted,
            action: _buildAction(),
          ),
          const SizedBox(height: 10),
          _PersonRow(
            avatarUrl: peerAvatarUrl,
            name: peerName,
            status: _personStatus(order.peerStage),
            isWaiting:
                order.peerStage == OrderStage.ready && !order.isCompleted,
          ),
        ],
      ),
    );
  }

  Widget? _buildAction() {
    if (order.isCompleted) {
      return null;
    }
    if (isCompleting) {
      return _ActionButton(
        label: AppStrings.btnAwaitingConfirm,
        onPressed: null,
      );
    }
    switch (order.myStage) {
      case OrderStage.ready:
        return _ActionButton(label: AppStrings.btnDepart, onPressed: onDepart);
      case OrderStage.enRoute:
        return _ActionButton(label: AppStrings.btnArrive, onPressed: onArrive);
      case OrderStage.arrived:
        if (order.peerStage == OrderStage.arrived) {
          return _ActionButton(
            label: AppStrings.btnFinish,
            onPressed: onComplete,
          );
        }
        return _ActionButton(label: AppStrings.btnWaiting, onPressed: null);
    }
  }
}

class _StageSteps extends StatelessWidget {
  const _StageSteps({required this.flags});

  final List<bool> flags;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < AppStrings.orderStages.length; i++) ...<Widget>[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: flags[i] ? AppColors.accent : AppColors.divider,
              ),
            ),
          Column(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: flags[i] ? AppColors.accent : AppColors.divider,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                AppStrings.orderStages[i],
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: flags[i] ? FontWeight.w700 : FontWeight.w500,
                  color:
                      flags[i] ? AppColors.textPrimary : AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.avatarUrl,
    required this.name,
    required this.status,
    required this.isWaiting,
    this.action,
  });

  final String? avatarUrl;
  final String name;
  final String status;
  final bool isWaiting;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        AppAvatar(size: 32, imageUrl: avatarUrl, fallbackLetter: name),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isWaiting ? AppColors.textHint : AppColors.accent,
                  fontWeight: isWaiting ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.onDarkPrimary,
          disabledBackgroundColor: AppColors.surface,
          disabledForegroundColor: AppColors.textHint,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}
