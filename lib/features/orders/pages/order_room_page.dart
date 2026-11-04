import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../community/models/post_author.dart';
import '../data/orders_repository.dart';
import '../models/live_order.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../auth/pages/verification_page.dart';

/// Order room. The flow mirrors the server state machine:
///
/// 1. AWAITING_PAYMENT — the poster escrows the fee; no contact channel.
/// 2. ACTIVE — the chat is open; ONE plan card is pinned above it and
///    always mirrors the order's current plan: placeholder while the host
///    still owes the plan (invitation orders), then awaiting the poster's
///    confirmation, then confirmed — which reveals the peer phone and the
///    poster's "Activity completed" action right on the card.
/// 3. Completing releases the escrow (a confirmed plan also auto-settles
///    server-side after a grace delay); the card goes read-only with the
///    settlement summary.
///
/// Plan proposals are still recorded as PLAN messages server-side (the
/// audit trail for disputes), but the room renders only the pinned card
/// and filters those records out of the stream.
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
    final (String, DateTime, String, int)? plan =
        await showModalBottomSheet<(String, DateTime, String, int)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PlanSheet(
        initialPlace: order.planPlace,
        initialAt: order.planAt,
        initialNote: order.planNote,
        initialDurationMinutes: order.planDurationMinutes,
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
        note: plan.$3,
        durationMinutes: plan.$4,
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

  /// Either side backs out within the cancel window: full refund, order
  /// closed.
  Future<void> _confirmCancel() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(AppStrings.cancelConfirmTitle),
        content: const Text(AppStrings.cancelConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancelConfirmNo),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.cancelConfirmYes),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _runAction(widget.repository.cancel);
      if (mounted && _order?.status == 'CANCELLED') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.cancelledSnack)),
        );
      }
    }
  }

  /// Host-only: submits the payer's meet code; a correct code starts the
  /// service clock (it settles itself after the planned duration).
  Future<void> _startMeet(String code) async {
    await _runAction(
      (String orderId) => widget.repository.start(orderId, code),
    );
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
      final String friendly = message == 'WRONG_MEET_CODE'
          ? AppStrings.wrongMeetCodeSnack
          : message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendly)));
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
        // Unpaid orders have no conversation and no entry points into
        // this room; this is a bare fallback for stale deep links.
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              AppStrings.chatLockedNote,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
        );
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
        // the conversation. Once the order settles or cancels, the thread
        // turns read-only.
        return _chatPhase(order);
    }
  }

  /// Paid: the chat is open under the one pinned plan card, which always
  /// mirrors the order's current plan and carries the lifecycle actions.
  Widget _chatPhase(LiveOrder order) {
    final bool chatOpen = order.status == 'ACTIVE';
    // PLAN records stay server-side as the audit trail; the room renders
    // the pinned card instead.
    final List<OrderMessage> chat = _messages
        .where((OrderMessage m) => !m.isPlanCard)
        .toList(growable: false);
    return Column(
      children: <Widget>[
        _PinnedPlanCard(
          order: order,
          myId: _myId,
          busy: _busy,
          onPropose: _proposePlan,
          onConfirm: _confirmPlan,
          onCopyPhone: _copyPhone,
          onCancel: _confirmCancel,
          onStart: _startMeet,
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: chat.length,
            itemBuilder: (BuildContext context, int index) {
              final OrderMessage message = chat[index];
              return _MessageBubble(
                text: message.text,
                isMine: message.senderId == _myId,
              );
            },
          ),
        ),
        if (chatOpen)
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
          )
        else
          // The conversation died with the activity: history stays
          // readable, the composer is gone.
          const SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.lock_outline, size: 14, color: AppColors.textHint),
                  SizedBox(width: 6),
                  Text(
                    AppStrings.chatReadOnlyNote,
                    style:
                        TextStyle(fontSize: 12.5, color: AppColors.textHint),
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

/// Plan composer sheet: place, time and the itinerary, in a tall neutral
/// modal. A proper StatefulWidget (not a closure over the caller's
/// controllers) so the controllers are disposed by the sheet's own State
/// after the route fully unmounts. Pops `(place, scheduledAt, note)`.
class _PlanSheet extends StatefulWidget {
  const _PlanSheet({
    required this.initialPlace,
    required this.initialAt,
    required this.initialNote,
    required this.initialDurationMinutes,
  });

  final String initialPlace;
  final DateTime? initialAt;
  final String initialNote;
  final int initialDurationMinutes;

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  late final TextEditingController _placeController;
  late final TextEditingController _noteController;
  DateTime? _scheduledAt;
  late int _durationMinutes;

  @override
  void initState() {
    super.initState();
    _placeController = TextEditingController(text: widget.initialPlace);
    _noteController = TextEditingController(text: widget.initialNote);
    _scheduledAt = widget.initialAt;
    _durationMinutes = widget.initialDurationMinutes > 0
        ? widget.initialDurationMinutes
        : planDurationOptions[1];
  }

  @override
  void dispose() {
    _placeController.dispose();
    _noteController.dispose();
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
    final String note = _noteController.text.trim();
    if (place.isEmpty || at == null || note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.planRequiredHint)),
      );
      return;
    }
    Navigator.of(context).pop((place, at, note, _durationMinutes));
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height * 0.72;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      AppStrings.planSheetTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      AppStrings.planSheetSub,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionLabel(AppStrings.planPlaceLabel),
                    TextField(
                      key: const ValueKey<String>('planPlaceField'),
                      controller: _placeController,
                      maxLength: 160,
                      decoration: const InputDecoration(
                        hintText: AppStrings.planPlaceHint,
                        prefixIcon: Icon(Icons.place_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _sectionLabel(AppStrings.planTimeLabel),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey<String>('planTimeButton'),
                        onPressed: _pickTime,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.schedule, size: 18),
                        label: Text(
                          _scheduledAt == null
                              ? AppStrings.publishPickTime
                              : _formatPlanDateTime(context, _scheduledAt!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _sectionLabel(AppStrings.planDurationLabel),
                    DurationChips(
                      selected: _durationMinutes,
                      onSelect: (int minutes) =>
                          setState(() => _durationMinutes = minutes),
                      keyPrefix: 'planDuration',
                    ),
                    const SizedBox(height: 18),
                    _sectionLabel(AppStrings.planNoteLabel),
                    TextField(
                      key: const ValueKey<String>('planNoteField'),
                      controller: _noteController,
                      maxLength: 500,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: AppStrings.planNoteHint,
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey<String>('planSubmitButton'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: AppColors.onDarkPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: _submit,
                    child: const Text(AppStrings.planProposeCta),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one pinned plan card above the chat: born with the order, it
/// always mirrors the current plan fields and walks the lifecycle —
/// placeholder while the host owes the plan (invitation orders), then
/// awaiting the poster's confirmation, then confirmed: the payer's card
/// shows the 4-digit meet code (told to the host in person), the host's
/// card takes the code to start the service. A started service settles
/// itself after the planned duration; a never-started one forfeits.
/// Within the 30-minute window after payment either side can still back
/// out with a full refund, right from the card.
class _PinnedPlanCard extends StatefulWidget {
  const _PinnedPlanCard({
    required this.order,
    required this.myId,
    required this.busy,
    required this.onPropose,
    required this.onConfirm,
    required this.onCopyPhone,
    required this.onCancel,
    required this.onStart,
  });

  final LiveOrder order;
  final String myId;
  final bool busy;
  final VoidCallback onPropose;
  final VoidCallback onConfirm;
  final ValueChanged<String> onCopyPhone;
  final VoidCallback onCancel;
  final ValueChanged<String> onStart;

  @override
  State<_PinnedPlanCard> createState() => _PinnedPlanCardState();
}

class _PinnedPlanCardState extends State<_PinnedPlanCard> {
  final TextEditingController _codeController = TextEditingController();

  LiveOrder get order => widget.order;
  bool get _iAmPayer => order.isPayer(widget.myId);
  bool get _active => order.status == 'ACTIVE';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Widget _badge() {
    if (order.status == 'FORFEITED') {
      return const _PlanBadge(
        label: AppStrings.forfeitedBadge,
        background: AppColors.otherMessageBubble,
        foreground: AppColors.textHint,
      );
    }
    if (order.status == 'COMPLETED' || order.status == 'CANCELLED') {
      return const _PlanBadge(
        label: AppStrings.chatEndedBadge,
        background: AppColors.otherMessageBubble,
        foreground: AppColors.textHint,
      );
    }
    if (order.started) {
      return const _PlanBadge(
        label: AppStrings.startedBadge,
        background: AppColors.accentSoft,
        foreground: AppColors.accent,
      );
    }
    if (!order.planProposed) {
      return const _PlanBadge(
        label: AppStrings.planMissingBadge,
        background: AppColors.otherMessageBubble,
        foreground: AppColors.textSecondary,
      );
    }
    if (order.planConfirmed) {
      return const _PlanBadge(
        label: AppStrings.planConfirmedBadge,
        background: AppColors.accentSoft,
        foreground: AppColors.accent,
      );
    }
    return const _PlanBadge(
      label: AppStrings.planAwaitingBadge,
      background: AppColors.otherMessageBubble,
      foreground: AppColors.textSecondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String phone = order.peerPhoneOf(widget.myId);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              _badge(),
            ],
          ),
          if (!order.planProposed)
            // Invitation orders arrive without a plan: the host still owes
            // it; the poster waits.
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _iAmPayer
                          ? AppStrings.planWaitingHost
                          : AppStrings.planHostPrompt,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (!_iAmPayer && _active) ...<Widget>[
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const ValueKey<String>('planProposeButton'),
                      onPressed: widget.busy ? null : widget.onPropose,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        foregroundColor: AppColors.onDarkPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text(AppStrings.planProposeCta),
                    ),
                  ],
                ],
              ),
            )
          else ...<Widget>[
            const SizedBox(height: 10),
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
                order.planDurationMinutes > 0
                    ? '${_formatPlanDateTime(context, order.planAt!)} \u00b7 '
                        '${AppStrings.durationAbout(order.planDurationMinutes)}'
                    : _formatPlanDateTime(context, order.planAt!),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (order.planNote.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text(
                order.planNote,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ],
          // The peer phone belongs to the meeting logistics, so it lives
          // on the card (the server reveals it once the escrow is in).
          if (phone.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            InkWell(
              key: const ValueKey<String>('peerPhoneRow'),
              onTap: () => widget.onCopyPhone(phone),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.phone_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 7),
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
          ],
          ..._lifecycleSection(context),
        ],
      ),
    );
  }

  /// The action area under the plan: exactly one stage is live at a time.
  List<Widget> _lifecycleSection(BuildContext context) {
    // Plan proposed, awaiting the poster's confirmation.
    if (_active && order.planProposed && !order.planConfirmed) {
      return <Widget>[
        const SizedBox(height: 12),
        if (_iAmPayer)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey<String>('planConfirmButton'),
              onPressed: widget.busy ? null : widget.onConfirm,
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
          )
        else
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
                onPressed: widget.busy ? null : widget.onPropose,
                child: const Text(AppStrings.planEditCta),
              ),
            ],
          ),
        ..._cancelRow(),
      ];
    }
    // Confirmed but not started: the meet-code exchange.
    if (_active && order.planConfirmed && !order.started) {
      return <Widget>[
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        if (_iAmPayer) ...<Widget>[
          // The payer owns the code: tell it to the host in person.
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      AppStrings.meetCodeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.meetCode,
                      key: const ValueKey<String>('meetCodeText'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 8,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            AppStrings.meetCodeHintPayer,
            style: TextStyle(fontSize: 11.5, color: AppColors.textHint),
          ),
        ] else ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('meetCodeField'),
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    hintText: AppStrings.meetCodeInputHint,
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                key: const ValueKey<String>('startMeetButton'),
                onPressed: widget.busy
                    ? null
                    : () => widget.onStart(_codeController.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkCard,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text(AppStrings.startMeetCta),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey<String>('planEditButton'),
              onPressed: widget.busy ? null : widget.onPropose,
              child: const Text(AppStrings.planEditCta),
            ),
          ),
        ],
        ..._cancelRow(),
      ];
    }
    // Service running: hands off — it settles itself.
    if (_active && order.started) {
      final DateTime endsAt = order.startedAt!
          .add(Duration(minutes: order.planDurationMinutes));
      return <Widget>[
        const SizedBox(height: 10),
        Text(
          AppStrings.settlesAtNote(
            MaterialLocalizations.of(context)
                .formatTimeOfDay(TimeOfDay.fromDateTime(endsAt)),
          ),
          style: const TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
      ];
    }
    if (order.status == 'COMPLETED') {
      return <Widget>[
        const SizedBox(height: 10),
        Text(
          _iAmPayer
              ? AppStrings.settledPayerNote('\u20b1${order.feePesos}')
              : AppStrings.settledEarnerNote('\u20b1${order.netPesos}'),
          style: const TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
      ];
    }
    if (order.status == 'FORFEITED') {
      return <Widget>[
        const SizedBox(height: 10),
        const Text(
          AppStrings.forfeitedNote,
          style: TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
      ];
    }
    // Awaiting the plan (placeholder head already shows the prompt) or a
    // closed cancelled order: just the cancel window if it is still open.
    return _cancelRow();
  }

  /// The windowed escape hatch: both sides can back out with a full
  /// refund within 30 minutes of payment, never after, never once the
  /// service started.
  List<Widget> _cancelRow() {
    if (!order.cancellableNow) {
      return const <Widget>[];
    }
    return <Widget>[
      const SizedBox(height: 2),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const ValueKey<String>('cancelOrderButton'),
          onPressed: widget.busy ? null : widget.onCancel,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textHint,
            padding: EdgeInsets.zero,
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: Text(
            _iAmPayer ? AppStrings.cancelCtaPayer : AppStrings.cancelCtaHost,
          ),
        ),
      ),
    ];
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
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
