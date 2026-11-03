import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../community/models/post_author.dart';
import '../data/orders_repository.dart';
import '../models/live_order.dart';
import 'payment_page.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../auth/pages/verification_page.dart';

/// Order room. The flow mirrors the server state machine:
///
/// 1. AWAITING_PAYMENT — the poster escrows the fee; no contact channel.
/// 2. ACTIVE, no plan yet — the planning phase: the host builds the plan
///    alone; there is NO chat until the plan card is sent.
/// 3. Plan proposed — the plan card opens the conversation (it renders as
///    the first element of the chat); the poster confirms the plan. A slim
///    info strip carries place / time / fee, expandable for phone and the
///    fee breakdown.
/// 4. The poster taps "Activity completed" to release the escrow (a
///    confirmed plan also auto-settles server-side after a grace delay).
///
/// Both parties act from their own devices; peer-side changes arrive via
/// short polling (a push/IM channel later replaces the polling without
/// changing this page's structure).
class OrderRoomPage extends StatefulWidget {
  const OrderRoomPage({
    super.key,
    required this.repository,
    required this.orderId,
    this.initialOrder,
  });

  final OrdersRepository repository;
  final String orderId;
  final LiveOrder? initialOrder;

  @override
  State<OrderRoomPage> createState() => _OrderRoomPageState();
}

class _OrderRoomPageState extends State<OrderRoomPage> {
  LiveOrder? _order;
  final List<OrderMessage> _messages = <OrderMessage>[];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;
  bool _busy = false;
  bool _detailsExpanded = false;

  String get _myId => AuthSession.currentUserId;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final LiveOrder order = await widget.repository.getOrder(widget.orderId);
      // Chat opens the moment the payment lands: escrowed money is the
      // anti-bypass mechanism, so no plan gate on the conversation.
      final List<OrderMessage> fresh = order.status == 'AWAITING_PAYMENT'
          ? const <OrderMessage>[]
          : await widget.repository.listMessages(
              widget.orderId,
              afterId: _messages.isEmpty ? null : _messages.last.id,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _order = order;
        if (fresh.isNotEmpty) {
          _messages.addAll(fresh);
        }
      });
      if (fresh.isNotEmpty) {
        _scrollToBottom();
      }
    } on Exception {
      // Transient network/poll failure; the next tick retries.
    }
  }

  /// The host proposes (or edits) the concrete plan via a bottom sheet.
  Future<void> _proposePlan() async {
    final LiveOrder? order = _order;
    if (order == null) {
      return;
    }
    // The sheet owns its text controller (its own State disposes it after
    // the route fully unmounts); disposing here right after the await
    // crashes the exit animation ('_dependents.isEmpty').
    final (String, DateTime)? plan =
        await showModalBottomSheet<(String, DateTime)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PlanSheet(
        initialPlace: order.planPlace,
        initialAt: order.planAt,
      ),
    );
    if (plan == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final LiveOrder updated = await widget.repository.proposePlan(
        widget.orderId,
        place: plan.$1,
        scheduledAt: plan.$2,
      );
      if (mounted) {
        setState(() => _order = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.planProposedSnack)),
        );
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _confirmPlan() async {
    setState(() => _busy = true);
    try {
      final LiveOrder updated =
          await widget.repository.confirmPlan(widget.orderId);
      if (mounted) {
        setState(() => _order = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.planConfirmedSnack)),
        );
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openPayment() async {
    final LiveOrder? current = _order;
    if (current == null) {
      return;
    }
    final LiveOrder? paid = await Navigator.of(context).push<LiveOrder>(
      MaterialPageRoute<LiveOrder>(
        builder: (_) => PaymentPage(
          repository: widget.repository,
          order: current,
        ),
      ),
    );
    if (paid != null && mounted) {
      setState(() => _order = paid);
    }
  }

  /// Poster-only: marks the activity done and releases the escrow.
  Future<void> _confirmComplete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(AppStrings.completeConfirmTitle),
        content: const Text(AppStrings.completeConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.completeConfirmNo),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.completeConfirmYes),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _runAction(widget.repository.complete);
    }
  }

  Future<void> _runAction(
    Future<LiveOrder> Function(String orderId) action,
  ) async {
    setState(() => _busy = true);
    try {
      final LiveOrder order = await action(widget.orderId);
      if (mounted) {
        setState(() => _order = order);
      }
    } on ApiException catch (e) {
      if (e.verificationRequired && mounted) {
        final bool verified = await promptVerification(context);
        if (verified && mounted) {
          setState(() => _busy = false);
          return _runAction(action);
        }
      } else {
        _showError(e.message);
      }
    } on Exception {
      _showError(AppStrings.errorNetwork);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _send() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _inputController.clear();
    try {
      final OrderMessage message = await widget.repository.sendMessage(
        widget.orderId,
        text,
      );
      if (mounted) {
        setState(() => _messages.add(message));
        _scrollToBottom();
      }
    } on Exception {
      _showError(AppStrings.errorMessageNotSent);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _copyPhone(String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.phoneCopied)),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final LiveOrder? order = _order;
    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final PostAuthor peer = order.peerOf(_myId);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            AppAvatar(
              size: 36,
              imageUrl: peer.avatarUrl,
              fallbackLetter: peer.name.isEmpty ? '?' : peer.name[0],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                peer.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      body: _body(order),
    );
  }

  Widget _body(LiveOrder order) {
    switch (order.status) {
      case 'AWAITING_PAYMENT':
        return _paymentPhase(order);
      case 'CANCELLED':
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              AppStrings.cancelledNote,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
        );
      default:
        // Paid orders chat freely; the plan card (confirmed at selection
        // for hall orders, proposed post-payment for invitations) leads
        // the conversation and gates the meet code only.
        return _chatPhase(order);
    }
  }

  /// AWAITING_PAYMENT: the poster escrows; no contact channel exists yet.
  Widget _paymentPhase(LiveOrder order) {
    final bool iAmPayer = order.isPayer(_myId);
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                AppStrings.statusAwaitingPayment,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                iAmPayer
                    ? AppStrings.tipPayNote
                    : AppStrings.waitingForPayment,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (iAmPayer) ...<Widget>[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.darkCard,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _busy ? null : _openPayment,
                    child: Text(
                      AppStrings.payCta('\u20b1${order.feePesos}'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Expanded(
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.lock_outline, size: 15, color: AppColors.textHint),
                SizedBox(width: 6),
                Text(
                  AppStrings.chatLockedNote,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Paid: the chat is open, the plan card leads the conversation.
  Widget _chatPhase(LiveOrder order) {
    final bool chatOpen = order.status == 'ACTIVE';
    return Column(
      children: <Widget>[
        _InfoStrip(
          order: order,
          myId: _myId,
          busy: _busy,
          expanded: _detailsExpanded,
          onToggle: () =>
              setState(() => _detailsExpanded = !_detailsExpanded),
          onCopyPhone: _copyPhone,
          onComplete: _confirmComplete,
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + 1,
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return _PlanCard(
                  order: order,
                  myId: _myId,
                  busy: _busy,
                  onPropose: _proposePlan,
                  onConfirm: _confirmPlan,
                );
              }
              final OrderMessage message = _messages[index - 1];
              return _MessageBubble(
                text: message.text,
                isMine: message.senderId == _myId,
              );
            },
          ),
        ),
        if (chatOpen || order.status == 'COMPLETED')
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: AppStrings.messageInputHint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.darkCard,
                    ),
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _formatPlanDateTime(BuildContext context, DateTime at) {
  final MaterialLocalizations loc = MaterialLocalizations.of(context);
  final DateTime local = at.toLocal();
  return '${loc.formatShortDate(local)} \u00b7 '
      '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

/// Plan proposal sheet. A proper StatefulWidget (not a closure over the
/// caller's controller) so the text controller is disposed by the sheet's
/// own State after the route fully unmounts. Pops `(place, scheduledAt)`.
class _PlanSheet extends StatefulWidget {
  const _PlanSheet({required this.initialPlace, required this.initialAt});

  final String initialPlace;
  final DateTime? initialAt;

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  late final TextEditingController _placeController;
  DateTime? _scheduledAt;

  @override
  void initState() {
    super.initState();
    _placeController = TextEditingController(text: widget.initialPlace);
    _scheduledAt = widget.initialAt;
  }

  @override
  void dispose() {
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _scheduledAt != null
          ? TimeOfDay.fromDateTime(_scheduledAt!)
          : const TimeOfDay(hour: 19, minute: 0),
    );
    if (time == null) {
      return;
    }
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submit() {
    final String place = _placeController.text.trim();
    final DateTime? at = _scheduledAt;
    if (place.isEmpty || at == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.planRequiredHint)),
      );
      return;
    }
    Navigator.of(context).pop((place, at));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            AppStrings.planSheetTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey<String>('planPlaceField'),
            controller: _placeController,
            maxLength: 160,
            decoration: const InputDecoration(
              hintText: AppStrings.planPlaceHint,
              prefixIcon: Icon(Icons.place_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey<String>('planTimeButton'),
            onPressed: _pickTime,
            icon: const Icon(Icons.schedule, size: 18),
            label: Text(
              _scheduledAt == null
                  ? AppStrings.publishPickTime
                  : _formatPlanDateTime(context, _scheduledAt!),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey<String>('planSubmitButton'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.darkCard,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _submit,
              child: const Text(AppStrings.planProposeCta),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slim header: place · time · fee in one line, expandable to lightweight
/// details (peer phone, fee breakdown, and the poster's complete action).
class _InfoStrip extends StatelessWidget {
  const _InfoStrip({
    required this.order,
    required this.myId,
    required this.busy,
    required this.expanded,
    required this.onToggle,
    required this.onCopyPhone,
    required this.onComplete,
  });

  final LiveOrder order;
  final String myId;
  final bool busy;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onCopyPhone;
  final VoidCallback onComplete;

  bool get _iAmPayer => order.isPayer(myId);

  String _summaryLine(BuildContext context) {
    final List<String> parts = <String>[
      if (order.planPlace.isNotEmpty) order.planPlace,
      if (order.planAt != null) _formatPlanDateTime(context, order.planAt!),
      '\u20b1${order.feePesos}',
    ];
    return parts.join('  \u00b7  ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            key: const ValueKey<String>('orderDetailsToggle'),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: <Widget>[
                  Icon(
                    order.status == 'COMPLETED'
                        ? Icons.check_circle_outline
                        : Icons.event_outlined,
                    size: 16,
                    color: order.status == 'COMPLETED'
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.status == 'COMPLETED'
                          ? (_iAmPayer
                              ? AppStrings.settledPayerNote(
                                  '\u20b1${order.feePesos}')
                              : AppStrings.settledEarnerNote(
                                  '\u20b1${order.netPesos}'))
                          : _summaryLine(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) _details(context),
        ],
      ),
    );
  }

  Widget _details(BuildContext context) {
    final String phone = order.peerPhoneOf(myId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _detailRow(
            AppStrings.orderFeeLabel,
            '\u20b1${order.feePesos}',
          ),
          _detailRow(
            AppStrings.orderPayoutLabel,
            '\u20b1${order.netPesos}',
          ),
          if (phone.isNotEmpty)
            InkWell(
              key: const ValueKey<String>('peerPhoneRow'),
              onTap: () => onCopyPhone(phone),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: <Widget>[
                    const SizedBox(
                      width: 110,
                      child: Text(
                        AppStrings.peerPhoneLabel,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.copy_rounded,
                      size: 13,
                      color: AppColors.textHint,
                    ),
                  ],
                ),
              ),
            ),
          if (_iAmPayer && order.status == 'ACTIVE') ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey<String>('completeButton'),
                onPressed: busy ? null : onComplete,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkCard,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text(AppStrings.completeCta),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The plan card: the first element of the conversation. The host edits,
/// the poster confirms; read-only once the order completes.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.order,
    required this.myId,
    required this.busy,
    required this.onPropose,
    required this.onConfirm,
  });

  final LiveOrder order;
  final String myId;
  final bool busy;
  final VoidCallback onPropose;
  final VoidCallback onConfirm;

  bool get _iAmHost => !order.isPayer(myId);

  bool get _editable => order.status == 'ACTIVE';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.map_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 7),
              const Text(
                AppStrings.planCardTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (order.planConfirmed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    AppStrings.planConfirmedBadge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!order.planProposed) ...<Widget>[
            // Invitation orders: no plan yet after payment. The chat is
            // already open; the host sends the plan card to unlock the
            // meet code later.
            Text(
              _iAmHost
                  ? AppStrings.planHostPrompt
                  : AppStrings.planWaitingHost,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            if (_editable && _iAmHost) ...<Widget>[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey<String>('planProposeButton'),
                  onPressed: busy ? null : onPropose,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.darkCard,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text(AppStrings.planProposeCta),
                ),
              ),
            ],
          ] else ...<Widget>[
          Text(
            order.planPlace,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (order.planAt != null) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              _formatPlanDateTime(context, order.planAt!),
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          ],
          if (order.planProposed && _editable && !order.planConfirmed)
            ...<Widget>[
            const SizedBox(height: 10),
            if (_iAmHost)
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      AppStrings.planAwaitingConfirm,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey<String>('planEditButton'),
                    onPressed: busy ? null : onPropose,
                    child: const Text(AppStrings.planEditCta),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey<String>('planConfirmButton'),
                  onPressed: busy ? null : onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.onDarkPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text(AppStrings.planConfirmCta),
                ),
              ),
          ] else if (_editable && order.planConfirmed && _iAmHost) ...<Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey<String>('planEditButton'),
                onPressed: busy ? null : onPropose,
                child: const Text(AppStrings.planEditCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, required this.isMine});

  final String text;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMine
              ? AppColors.myMessageBubble
              : AppColors.otherMessageBubble,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            color: isMine ? AppColors.myMessageText : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
