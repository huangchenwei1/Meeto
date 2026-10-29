import '../../../core/network/api_client.dart';
import '../../partner/models/post_author.dart';

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
    required this.distanceKm,
    required this.payerLat,
    required this.payerLng,
    required this.earnerLat,
    required this.earnerLng,
    required this.postTitle,
    required this.scheduledAt,
    required this.place,
    required this.placeLat,
    required this.placeLng,
    required this.planPlace,
    required this.planLat,
    required this.planLng,
    required this.planAt,
    required this.planProposedAt,
    required this.planConfirmedAt,
    required this.payerMetAt,
    required this.earnerMetAt,
    required this.metAt,
    required this.settleAt,
    required this.disputed,
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
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      payerLat: (json['payerLat'] as num?)?.toDouble(),
      payerLng: (json['payerLng'] as num?)?.toDouble(),
      earnerLat: (json['earnerLat'] as num?)?.toDouble(),
      earnerLng: (json['earnerLng'] as num?)?.toDouble(),
      postTitle: json['postTitle'] as String? ?? '',
      scheduledAt: parseDate(json['scheduledAt']),
      place: json['place'] as String? ?? '',
      placeLat: (json['placeLat'] as num?)?.toDouble() ?? 0,
      placeLng: (json['placeLng'] as num?)?.toDouble() ?? 0,
      planPlace: json['planPlace'] as String? ?? '',
      planLat: (json['planLat'] as num?)?.toDouble() ?? 0,
      planLng: (json['planLng'] as num?)?.toDouble() ?? 0,
      planAt: parseDate(json['planAt']),
      planProposedAt: parseDate(json['planProposedAt']),
      planConfirmedAt: parseDate(json['planConfirmedAt']),
      payerMetAt: parseDate(json['payerMetAt']),
      earnerMetAt: parseDate(json['earnerMetAt']),
      metAt: parseDate(json['metAt']),
      settleAt: parseDate(json['settleAt']),
      disputed: json['disputed'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String postId;
  final PostAuthor payer;
  final PostAuthor earner;

  /// AWAITING_PAYMENT | ACTIVE | MET | COMPLETED | CANCELLED | DISPUTED
  final String status;
  final int feePesos;
  final int commissionPesos;
  final int netPesos;

  /// Disclosed once the fee is escrowed (empty before that).
  final String payerPhone;
  final String earnerPhone;

  /// Distance between the parties' latest location fixes; null until both
  /// sides have reported one.
  final double? distanceKm;

  /// Latest location fixes, shared with both parties for the map readout.
  final double? payerLat;
  final double? payerLng;
  final double? earnerLat;
  final double? earnerLng;

  /// Date context from the post: scene title and scheduled time, so the
  /// order can be presented as a concrete date rather than a bare chat.
  final String postTitle;
  final DateTime? scheduledAt;

  /// EFFECTIVE venue and time: the confirmed plan overrides the post's
  /// rough intent server-side (zeros/empty mean nothing structured yet).
  final String place;
  final double placeLat;
  final double placeLng;

  bool get hasVenueLocation => placeLat != 0 || placeLng != 0;

  /// The host's proposed plan (empty/null until proposed). Confirmed when
  /// [planConfirmedAt] is set; re-proposing clears the confirmation.
  final String planPlace;
  final double planLat;
  final double planLng;
  final DateTime? planAt;
  final DateTime? planProposedAt;
  final DateTime? planConfirmedAt;

  bool get planProposed => planProposedAt != null;
  bool get planConfirmed => planConfirmedAt != null;

  final DateTime? payerMetAt;
  final DateTime? earnerMetAt;
  final DateTime? metAt;

  /// When the escrow auto-settles to the earner (metAt + platform delay).
  final DateTime? settleAt;
  final bool disputed;
  final DateTime createdAt;

  bool isPayer(String userId) => payer.id == userId;

  PostAuthor peerOf(String userId) => isPayer(userId) ? earner : payer;

  String peerPhoneOf(String userId) =>
      isPayer(userId) ? earnerPhone : payerPhone;

  bool metConfirmedBy(String userId) =>
      (isPayer(userId) ? payerMetAt : earnerMetAt) != null;

  bool metConfirmedByPeer(String userId) =>
      (isPayer(userId) ? earnerMetAt : payerMetAt) != null;

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
    required this.text,
    required this.createdAt,
  });

  factory OrderMessage.fromJson(Map<String, dynamic> json) {
    return OrderMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
}
