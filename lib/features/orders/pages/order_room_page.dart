import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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

/// Order room: server-authoritative date status plus order-scoped chat.
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
  int _pollTick = 0;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  /// Best-effort GPS fix; returns null when permission is denied or the
  /// fix fails (callers decide whether that blocks the action).
  Future<Position?> _getPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition();
    } on Exception {
      return null;
    }
  }

  /// Shares the caller's location while coordination matters (ACTIVE/MET),
  /// roughly every 4th poll tick (~12s).
  Future<void> _shareLocationIfDue() async {
    final LiveOrder? order = _order;
    if (order == null ||
        (order.status != 'ACTIVE' && order.status != 'MET') ||
        _pollTick % 4 != 1) {
      return;
    }
    final Position? position = await _getPosition();
    if (position == null) {
      return;
    }
    try {
      final LiveOrder updated = await widget.repository.updateLocation(
        widget.orderId,
        lat: position.latitude,
        lng: position.longitude,
      );
      if (mounted) {
        setState(() => _order = updated);
      }
    } on Exception {
      // Best effort; the next due tick retries.
    }
  }

  /// The host proposes (or edits) the concrete plan via a bottom sheet.
  Future<void> _proposePlan() async {
    final LiveOrder? order = _order;
    if (order == null) {
      return;
    }
    final TextEditingController placeController =
        TextEditingController(text: order.planPlace);
    DateTime? scheduledAt = order.planAt;
    final bool? submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            Future<void> pickTime() async {
              final DateTime now = DateTime.now();
              final DateTime? date = await showDatePicker(
                context: context,
                initialDate: scheduledAt ?? now,
                firstDate: now,
                lastDate: now.add(const Duration(days: 60)),
              );
              if (date == null || !context.mounted) {
                return;
              }
              final TimeOfDay? time = await showTimePicker(
                context: context,
                initialTime: scheduledAt != null
                    ? TimeOfDay.fromDateTime(scheduledAt!)
                    : const TimeOfDay(hour: 19, minute: 0),
              );
              if (time == null) {
                return;
              }
              setSheetState(() {
                scheduledAt = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
              });
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
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
                    controller: placeController,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      hintText: AppStrings.planPlaceHint,
                      prefixIcon: Icon(Icons.place_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey<String>('planTimeButton'),
                    onPressed: pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(
                      scheduledAt == null
                          ? AppStrings.publishPickTime
                          : _formatPlanTime(scheduledAt!),
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
                      onPressed: () {
                        if (placeController.text.trim().isEmpty ||
                            scheduledAt == null) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text(AppStrings.planRequiredHint),
                            ),
                          );
                          return;
                        }
                        Navigator.of(sheetContext).pop(true);
                      },
                      child: const Text(AppStrings.planProposeCta),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (submitted != true || !mounted || scheduledAt == null) {
      placeController.dispose();
      return;
    }
    final String place = placeController.text.trim();
    placeController.dispose();
    setState(() => _busy = true);
    try {
      final LiveOrder updated = await widget.repository.proposePlan(
        widget.orderId,
        place: place,
        scheduledAt: scheduledAt!,
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

  String _formatPlanTime(DateTime at) => _formatPlanDateTime(context, at);

  Future<void> _confirmMeet() async {
    setState(() => _busy = true);
    try {
      final Position? position = await _getPosition();
      if (position == null) {
        _showError(AppStrings.locationNeededHint);
        return;
      }
      final LiveOrder order = await widget.repository.confirmMeet(
        widget.orderId,
        lat: position.latitude,
        lng: position.longitude,
      );
      if (mounted) {
        setState(() => _order = order);
      }
    } on ApiException catch (e) {
      if (e.message.contains('NOT_TOGETHER')) {
        _showError(AppStrings.notTogetherHint);
      } else {
        _showError(e.message);
      }
    } on Exception {
      _showError('Network error, try again');
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

  Future<void> _confirmDispute() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(AppStrings.disputeConfirmTitle),
        content: const Text(AppStrings.disputeConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.disputeConfirmNo),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              AppStrings.disputeConfirmYes,
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _runAction(widget.repository.dispute);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    _pollTick += 1;
    unawaited(_shareLocationIfDue());
    try {
      final LiveOrder order = await widget.repository.getOrder(widget.orderId);
      final List<OrderMessage> fresh = await widget.repository.listMessages(
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
      _showError('Network error, try again');
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
      _showError('Message not sent, try again');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  bool _showMap(LiveOrder order) {
    final bool coordinating =
        order.status == 'ACTIVE' || order.status == 'MET';
    final bool hasAnyLocation =
        (order.payerLat != null && order.payerLng != null) ||
        (order.earnerLat != null && order.earnerLng != null) ||
        order.hasVenueLocation;
    return coordinating && hasAnyLocation;
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
      body: Column(
        children: <Widget>[
          _StatusCard(
            order: order,
            myId: _myId,
            busy: _busy,
            onPay: _openPayment,
            onConfirmMeet: _confirmMeet,
            onDispute: _confirmDispute,
            onCopyPhone: (String phone) {
              Clipboard.setData(ClipboardData(text: phone));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text(AppStrings.phoneCopied)),
              );
            },
          ),
          if (order.status == 'ACTIVE' ||
              order.status == 'MET' ||
              order.status == 'COMPLETED')
            _PlanCard(
              order: order,
              myId: _myId,
              busy: _busy,
              onPropose: _proposePlan,
              onConfirm: _confirmPlan,
            ),
          if (_showMap(order))
            _OrderMap(order: order, myId: _myId),
          const Divider(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (BuildContext context, int index) {
                final OrderMessage message = _messages[index];
                return _MessageBubble(
                  text: message.text,
                  isMine: message.senderId == _myId,
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: order.status == 'AWAITING_PAYMENT'
                // The paywall: no contact channel before the fee is escrowed
                // (the server enforces the same rule).
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.lock_outline,
                            size: 15, color: AppColors.textHint),
                        SizedBox(width: 6),
                        Text(
                          AppStrings.chatLockedNote,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
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
      ),
    );
  }
}

String _formatPlanDateTime(BuildContext context, DateTime at) {
  final MaterialLocalizations loc = MaterialLocalizations.of(context);
  final DateTime local = at.toLocal();
  return '${loc.formatShortDate(local)} \u00b7 '
      '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

/// The concrete plan: the host proposes place + time, the poster confirms.
/// Shown while the order is active (and read-only afterwards).
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
          if (!order.planProposed)
            _buildEmptyState()
          else
            _buildPlanBody(context),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_iAmHost && _editable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            AppStrings.planHostPrompt,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            key: const ValueKey<String>('planProposeButton'),
            onPressed: busy ? null : onPropose,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.onDarkPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text(AppStrings.planProposeCta),
          ),
        ],
      );
    }
    return const Text(
      AppStrings.planWaitingHost,
      style: TextStyle(fontSize: 12.5, color: AppColors.textHint),
    );
  }

  Widget _buildPlanBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
        if (_editable && !order.planConfirmed) ...<Widget>[
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
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.order,
    required this.myId,
    required this.busy,
    required this.onPay,
    required this.onConfirmMeet,
    required this.onDispute,
    required this.onCopyPhone,
  });

  final LiveOrder order;
  final String myId;
  final bool busy;
  final VoidCallback onPay;
  final VoidCallback onConfirmMeet;
  final VoidCallback onDispute;
  final ValueChanged<String> onCopyPhone;

  bool get _iAmPayer => order.isPayer(myId);

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            _headline(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _subline(),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (_showContactRow()) _contactRow(),
          ..._actions(),
        ],
      ),
    );
  }

  String _headline() {
    switch (order.status) {
      case 'AWAITING_PAYMENT':
        return AppStrings.statusAwaitingPayment;
      case 'ACTIVE':
        return AppStrings.escrowHeldNote('\u20b1${order.feePesos}');
      case 'MET':
        return AppStrings.metHeadline;
      case 'DISPUTED':
        return AppStrings.disputedHeadline;
      case 'COMPLETED':
        return _iAmPayer
            ? AppStrings.settledPayerNote('\u20b1${order.feePesos}')
            : AppStrings.settledEarnerNote('\u20b1${order.netPesos}');
      default:
        return AppStrings.cancelledNote;
    }
  }

  String _subline() {
    switch (order.status) {
      case 'AWAITING_PAYMENT':
        return _iAmPayer
            ? AppStrings.tipPayNote
            : AppStrings.waitingForPayment;
      case 'ACTIVE':
        final double? km = order.distanceKm;
        return km == null
            ? AppStrings.distanceWaiting
            : AppStrings.distanceApart(km.toStringAsFixed(1));
      case 'MET':
        final String time = _settleTimeLabel();
        return _iAmPayer
            ? AppStrings.metSettlePayerSub(time)
            : AppStrings.metSettleEarnerSub(time, '\u20b1${order.netPesos}');
      case 'DISPUTED':
        return AppStrings.disputedSub;
      default:
        return AppStrings.escrowSub;
    }
  }

  String _settleTimeLabel() {
    final DateTime? settleAt = order.settleAt;
    if (settleAt == null) {
      return '';
    }
    final DateTime local = settleAt.toLocal();
    final String hh = local.hour.toString().padLeft(2, '0');
    final String mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  bool _showContactRow() {
    final String phone = order.peerPhoneOf(myId);
    return phone.isNotEmpty &&
        (order.status == 'ACTIVE' || order.status == 'MET');
  }

  Widget _contactRow() {
    final String phone = order.peerPhoneOf(myId);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        key: const ValueKey<String>('peerPhoneRow'),
        onTap: () => onCopyPhone(phone),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.call_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                '${AppStrings.peerPhoneLabel} $phone',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              const Icon(Icons.copy_rounded,
                  size: 15, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _actions() {
    final List<Widget> actions = <Widget>[];
    final Widget? primary = _primaryAction();
    if (primary != null) {
      actions
        ..add(const SizedBox(height: 12))
        ..add(primary);
    }
    if (order.status == 'ACTIVE' && order.metConfirmedBy(myId)) {
      actions
        ..add(const SizedBox(height: 8))
        ..add(
          const Text(
            AppStrings.meetWaitingPeer,
            style: TextStyle(fontSize: 12.5, color: AppColors.textHint),
          ),
        );
    }
    // Cancellation is intentionally not exposed in the client for now; the
    // cancellation policy is still being designed. The server endpoint stays
    // available for internal cleanup.
    if (order.status == 'MET') {
      actions
        ..add(const SizedBox(height: 4))
        ..add(
          Center(
            child: TextButton(
              key: const ValueKey<String>('disputeButton'),
              onPressed: busy ? null : onDispute,
              child: const Text(
                AppStrings.disputeCta,
                style: TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          ),
        );
    }
    return actions;
  }

  Widget? _primaryAction() {
    final (String, VoidCallback)? spec = _primarySpec();
    if (spec == null) {
      return null;
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.darkCard,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: busy ? null : spec.$2,
        child: Text(
          spec.$1,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  (String, VoidCallback)? _primarySpec() {
    if (order.status == 'AWAITING_PAYMENT' && _iAmPayer) {
      return (AppStrings.payCta('\u20b1${order.feePesos}'), onPay);
    }
    if (order.status == 'ACTIVE' && !order.metConfirmedBy(myId)) {
      return (AppStrings.confirmMeetCta, onConfirmMeet);
    }
    return null;
  }
}

/// Live positions of both parties on an OpenStreetMap view. Rebuilt (and the
/// camera re-fitted) whenever either side's fix moves meaningfully; a map
/// vendor swap later only touches this widget.
class _OrderMap extends StatelessWidget {
  const _OrderMap({required this.order, required this.myId});

  final LiveOrder order;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final LatLng? payerPoint =
        order.payerLat != null && order.payerLng != null
            ? LatLng(order.payerLat!, order.payerLng!)
            : null;
    final LatLng? earnerPoint =
        order.earnerLat != null && order.earnerLng != null
            ? LatLng(order.earnerLat!, order.earnerLng!)
            : null;
    final LatLng? venuePoint = order.hasVenueLocation
        ? LatLng(order.placeLat, order.placeLng)
        : null;
    final List<LatLng> points = <LatLng>[
      ?payerPoint,
      ?earnerPoint,
      ?venuePoint,
    ];
    final String cameraKey = points
        .map((LatLng p) =>
            '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}')
        .join('|');
    return Container(
      height: 170,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: FlutterMap(
        key: ValueKey<String>(cameraKey),
        options: MapOptions(
          initialCameraFit: points.length == 2
              ? CameraFit.coordinates(
                  coordinates: points,
                  padding: const EdgeInsets.all(44),
                  maxZoom: 16,
                )
              : CameraFit.coordinates(
                  coordinates: points,
                  maxZoom: 15,
                ),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: <Widget>[
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.meeto',
          ),
          MarkerLayer(
            markers: <Marker>[
              if (venuePoint != null) _venueMarker(venuePoint),
              if (payerPoint != null)
                _marker(payerPoint, order.payer, order.payer.id == myId),
              if (earnerPoint != null)
                _marker(earnerPoint, order.earner, order.earner.id == myId),
            ],
          ),
        ],
      ),
    );
  }

  /// Date venue pin (anchored at its bottom tip like a classic map pin).
  Marker _venueMarker(LatLng point) {
    return Marker(
      point: point,
      width: 34,
      height: 34,
      alignment: Alignment.topCenter,
      child: const Icon(
        Icons.location_pin,
        size: 34,
        color: Colors.redAccent,
        shadows: <Shadow>[Shadow(color: Colors.black38, blurRadius: 4)],
      ),
    );
  }

  Marker _marker(LatLng point, PostAuthor party, bool isMe) {
    return Marker(
      point: point,
      width: 42,
      height: 42,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isMe ? AppColors.darkCard : Colors.white,
            width: 2.5,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black26, blurRadius: 6),
          ],
        ),
        child: AppAvatar(
          size: 37,
          imageUrl: party.avatarUrl,
          fallbackLetter: party.name.isEmpty ? '?' : party.name[0],
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
