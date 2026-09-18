class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    this.type = 'text',
    required this.text,
    this.imageUrl,
    this.audioUrl,
    this.durationMs,
    this.location,
    this.meetup,
    required this.status,
    required this.isMine,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String type;
  final String text;
  final String? imageUrl;
  final String? audioUrl;
  final int? durationMs;
  final ChatLocationPayload? location;
  final ChatMeetupPayload? meetup;
  final String status;
  final bool isMine;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isImage => type == 'image' && (imageUrl?.isNotEmpty ?? false);
  bool get isVoice =>
      type == 'voice' &&
      (audioUrl?.isNotEmpty ?? false) &&
      (durationMs ?? 0) > 0;
  bool get isLocation => type == 'location' && location != null;
  bool get isMeetup => type == 'meetup' && meetup != null;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: (json['id'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      receiverId: (json['receiverId'] ?? '').toString(),
      type: (json['type'] ?? 'text').toString(),
      text: (json['text'] ?? '').toString(),
      imageUrl: json['imageUrl']?.toString(),
      audioUrl: json['audioUrl']?.toString(),
      durationMs: switch (json['durationMs']) {
        int value => value,
        num value => value.round(),
        _ => int.tryParse(json['durationMs']?.toString() ?? ''),
      },
      location: json['location'] is Map<String, dynamic>
          ? ChatLocationPayload.fromJson(
              json['location'] as Map<String, dynamic>,
            )
          : null,
      meetup: json['meetup'] is Map<String, dynamic>
          ? ChatMeetupPayload.fromJson(json['meetup'] as Map<String, dynamic>)
          : null,
      status: (json['status'] ?? 'sent').toString(),
      isMine: json['isMine'] == true,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      readAt: DateTime.tryParse(json['readAt']?.toString() ?? ''),
    );
  }
}

class ChatLocationPayload {
  const ChatLocationPayload({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;

  factory ChatLocationPayload.fromJson(Map<String, dynamic> json) {
    return ChatLocationPayload(
      name: (json['name'] ?? 'Shared location').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ChatMeetupPayload {
  const ChatMeetupPayload({
    required this.orderId,
    required this.scheduledAt,
    required this.locationName,
    this.latitude,
    this.longitude,
    required this.proposalStatus,
    this.proposedBy,
    this.note,
    this.agreedPriceNzd,
    this.originalPriceNzd,
  });

  final String orderId;
  final DateTime scheduledAt;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final String proposalStatus;
  final String? proposedBy;
  final String? note;
  /// The settled agreed price (special price if negotiated, else item price)
  final String? agreedPriceNzd;
  /// The original listed item price (for strikethrough display)
  final String? originalPriceNzd;

  bool get isProposed => proposalStatus == 'proposed';
  bool get isConfirmed => proposalStatus == 'confirmed';
  bool get isDeclined => proposalStatus == 'declined';
  bool get isCancelled => proposalStatus == 'cancelled';

  factory ChatMeetupPayload.fromJson(Map<String, dynamic> json) {
    return ChatMeetupPayload(
      orderId: (json['orderId'] ?? '').toString(),
      scheduledAt:
          DateTime.tryParse(json['scheduledAt']?.toString() ?? '') ??
          DateTime.now(),
      locationName: (json['locationName'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      proposalStatus: (json['proposalStatus'] ?? 'proposed').toString(),
      proposedBy: json['proposedBy']?.toString(),
      note: json['note']?.toString(),
      agreedPriceNzd: json['agreedPriceNzd']?.toString() ??
          json['itemPriceNzd']?.toString(),
      originalPriceNzd: json['originalPriceNzd']?.toString(),
    );
  }
}

class ChatMessagePage {
  const ChatMessagePage({
    required this.messages,
    required this.hasMore,
    this.nextBefore,
  });

  final List<ChatMessageModel> messages;
  final bool hasMore;
  final DateTime? nextBefore;
}
