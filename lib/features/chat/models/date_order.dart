/// Per-person progress within a confirmed date order.
///
/// Values are ordered; comparing indexes is meaningful.
enum OrderStage {
  ready,
  enRoute,
  arrived;

  static OrderStage fromJson(String value) {
    return OrderStage.values.firstWhere((OrderStage e) => e.name == value);
  }
}

/// A confirmed date bound to a conversation.
///
/// DEMO NOTE: the client drives this state machine locally through the mock
/// repository. In production the server is the single authority; the client
/// only sends intents (depart / check in / complete) and renders pushed state.
class DateOrder {
  const DateOrder({
    required this.id,
    required this.title,
    required this.timeText,
    required this.place,
    required this.distanceKm,
    required this.etaMinutes,
    required this.tipAmount,
    required this.myStage,
    required this.peerStage,
    required this.isCompleted,
    this.postId,
  });

  factory DateOrder.fromJson(Map<String, dynamic> json) {
    return DateOrder(
      id: json['id'] as String,
      title: json['title'] as String,
      timeText: json['timeText'] as String,
      place: json['place'] as String,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      etaMinutes: json['etaMinutes'] as int,
      tipAmount: json['tipAmount'] as int,
      myStage: OrderStage.fromJson(json['myStage'] as String),
      peerStage: OrderStage.fromJson(json['peerStage'] as String),
      isCompleted: json['isCompleted'] as bool,
      postId: json['postId'] as String?,
    );
  }

  final String id;
  final String title;
  final String timeText;
  final String place;
  final double distanceKm;
  final int etaMinutes;
  final int tipAmount;
  final OrderStage myStage;
  final OrderStage peerStage;
  final bool isCompleted;

  /// Source post id; set for orders created through the match flow and used
  /// to sync intents to the backend. Null for seeded demo conversations.
  final String? postId;

  bool get bothArrived =>
      myStage == OrderStage.arrived && peerStage == OrderStage.arrived;

  String get distanceLabel {
    final bool isWhole = distanceKm == distanceKm.roundToDouble();
    return isWhole ? distanceKm.toInt().toString() : distanceKm.toString();
  }

  DateOrder copyWith({
    OrderStage? myStage,
    OrderStage? peerStage,
    bool? isCompleted,
  }) {
    return DateOrder(
      id: id,
      title: title,
      timeText: timeText,
      place: place,
      distanceKm: distanceKm,
      etaMinutes: etaMinutes,
      tipAmount: tipAmount,
      myStage: myStage ?? this.myStage,
      peerStage: peerStage ?? this.peerStage,
      isCompleted: isCompleted ?? this.isCompleted,
      postId: postId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'timeText': timeText,
      'place': place,
      'distanceKm': distanceKm,
      'etaMinutes': etaMinutes,
      'tipAmount': tipAmount,
      'myStage': myStage.name,
      'peerStage': peerStage.name,
      'isCompleted': isCompleted,
      'postId': postId,
    };
  }
}
