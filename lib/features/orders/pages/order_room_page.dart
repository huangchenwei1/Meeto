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
import '../../../shared/widgets/app_avatar.dart';
import '../../auth/pages/verification_page.dart';

/// Order room. The flow mirrors the server state machine:
///
/// 1. AWAITING_PAYMENT — no conversation exists (bare fallback only).
/// 2. ACTIVE — the chat is open under ONE read-only pinned plan card.
///    The plan was locked at the deal moment (sign-up plan card or the
///    host's selection plan card), so the room carries no plan
///    negotiation: just the meet-code exchange and the cancel window.
/// 3. The started service settles itself after the planned duration; the
///    card goes read-only with the settlement summary.
///
/// The locked plan is also recorded as a PLAN message server-side (the
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

/// The one pinned plan card above the chat: born with the order and
/// read-only — the plan was locked at the deal moment. The payer's card
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
    required this.onCopyPhone,
    required this.onCancel,
    required this.onStart,
  });

  final LiveOrder order;
  final String myId;
  final bool busy;
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
    // The plan was locked at the deal moment: an unstarted active order
    // is simply a confirmed plan waiting for the meet code.
    return const _PlanBadge(
      label: AppStrings.planConfirmedBadge,
      background: AppColors.accentSoft,
      foreground: AppColors.accent,
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
          ...<Widget>[
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
    // Active but not started: the meet-code exchange (the plan itself was
    // locked before payment, so there is nothing left to negotiate).
    if (_active && !order.started) {
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
    // A closed cancelled order: just the cancel window if it is still open.
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
