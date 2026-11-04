import '../../../core/network/api_client.dart';
import '../../community/models/post_author.dart';

/// Server-authoritative order as returned by the API. All money fields are
/// whole pesos (converted from minor units at the boundary).
class LiveOrder {
  const LiveOrder({
    required this.id,
    required this.postId,
    required this.payer,
    required this.earner,
    required this.status,
    required this.feePesos,
    required this.commissionPesos,
    required this.netPesos,
    required this.payerPhone,
    required this.earnerPhone,
    required this.postTitle,
    required this.scheduledAt,
    required this.place,
    required this.placeLat,
    required this.placeLng,
    required this.planPlace,
    required this.planLat,
    required this.planLng,
    required this.planAt,
    this.planNote = '',
    this.planDurationMinutes = 0,
    required this.planProposedAt,
    required this.planConfirmedAt,
    this.meetCode = '',
    this.startedAt,
    this.cancellableUntil,
    required this.completedAt,
    required this.createdAt,
  });

  factory LiveOrder.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) =>
        value == null ? null : DateTime.parse(value as String);
    return LiveOrder(
      id: json['id'] as String,
      postId: json['postId'] as String,
      payer: _party(json['payer'] as Map<String, dynamic>),
      earner: _party(json['earner'] as Map<String, dynamic>),
      status: json['status'] as String,
      feePesos: minorToPesos(json['feeMinor'] as int),
      commissionPesos: minorToPesos(json['commissionMinor'] as int),
      netPesos: minorToPesos(json['netMinor'] as int),
      payerPhone: json['payerPhone'] as String? ?? '',
      earnerPhone: json['earnerPhone'] as String? ?? '',
      postTitle: json['postTitle'] as String? ?? '',
      scheduledAt: parseDate(json['scheduledAt']),
      place: json['place'] as String? ?? '',
      placeLat: (json['placeLat'] as num?)?.toDouble() ?? 0,
      placeLng: (json['placeLng'] as num?)?.toDouble() ?? 0,
      planPlace: json['planPlace'] as String? ?? '',
      planLat: (json['planLat'] as num?)?.toDouble() ?? 0,
      planLng: (json['planLng'] as num?)?.toDouble() ?? 0,
      planAt: parseDate(json['planAt']),
      planNote: json['planNote'] as String? ?? '',
      planDurationMinutes: (json['planDurationMinutes'] as num?)?.toInt() ?? 0,
      planProposedAt: parseDate(json['planProposedAt']),
      planConfirmedAt: parseDate(json['planConfirmedAt']),
      meetCode: json['meetCode'] as String? ?? '',
      startedAt: parseDate(json['startedAt']),
      cancellableUntil: parseDate(json['cancellableUntil']),
      completedAt: parseDate(json['completedAt']),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String postId;
  final PostAuthor payer;
  final PostAuthor earner;

  /// AWAITING_PAYMENT | ACTIVE | COMPLETED | CANCELLED | FORFEITED
  final String status;
  final int feePesos;
  final int commissionPesos;
  final int netPesos;

  /// Disclosed once the fee is escrowed (empty before that).
  final String payerPhone;
  final String earnerPhone;

  /// Date context from the post so the order can be presented as a
  /// concrete activity rather than a bare chat.
  final String postTitle;

  /// EFFECTIVE venue and time: set once the plan is confirmed
  /// (zeros/empty/null mean nothing structured yet).
  final DateTime? scheduledAt;
  final String place;
  final double placeLat;
  final double placeLng;

  /// The host's proposed plan (empty/null until proposed). The first
  /// proposal opens the chat; confirmed when [planConfirmedAt] is set;
  /// re-proposing clears the confirmation.
  final String planPlace;
  final double planLat;
  final double planLng;
  final DateTime? planAt;

  /// The itinerary: what the activity actually covers.
  final String planNote;

  /// How long the activity is planned to run, in minutes.
  final int planDurationMinutes;
  final DateTime? planProposedAt;
  final DateTime? planConfirmedAt;

  bool get planProposed => planProposedAt != null;
  bool get planConfirmed => planConfirmedAt != null;

  /// Proof-of-meeting code, served ONLY to the payer (empty for the
  /// host): shown on the plan card, told to the host in person.
  final String meetCode;

  /// Set when the host submitted the correct meet code: the service runs
  /// and auto-settles after its planned duration.
  final DateTime? startedAt;

  bool get started => startedAt != null;

  /// Until when either side may still cancel with a full refund; null
  /// before payment or once the service started.
  final DateTime? cancellableUntil;

  bool get cancellableNow =>
      status == 'ACTIVE' &&
      !started &&
      cancellableUntil != null &&
      DateTime.now().isBefore(cancellableUntil!);

  /// Set when the order closed (settled or forfeited).
  final DateTime? completedAt;
  final DateTime createdAt;

  bool isPayer(String userId) => payer.id == userId;

  PostAuthor peerOf(String userId) => isPayer(userId) ? earner : payer;

  String peerPhoneOf(String userId) =>
      isPayer(userId) ? earnerPhone : payerPhone;

  static PostAuthor _party(Map<String, dynamic> json) {
    return PostAuthor(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: resolveMediaUrl(json['avatarUrl'] as String? ?? ''),
      meta: json['meta'] as String,
      isVerified: json['isVerified'] as bool,
    );
  }
}

class OrderMessage {
  const OrderMessage({
    required this.id,
    required this.senderId,
    this.kind = 'TEXT',
    required this.text,
    required this.createdAt,
  });

  factory OrderMessage.fromJson(Map<String, dynamic> json) {
    return OrderMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      kind: json['kind'] as String? ?? 'TEXT',
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String senderId;

  /// TEXT for plain chat; PLAN for a plan card ([text] then carries the
  /// JSON snapshot {place, scheduledAt, note} frozen at send time).
  final String kind;
  final String text;
  final DateTime createdAt;

  bool get isPlanCard => kind == 'PLAN';
}
