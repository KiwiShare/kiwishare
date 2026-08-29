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
  final String status;
  final bool isMine;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isImage => type == 'image' && (imageUrl?.isNotEmpty ?? false);
  bool get isVoice =>
      type == 'voice' &&
      (audioUrl?.isNotEmpty ?? false) &&
      (durationMs ?? 0) > 0;

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
      status: (json['status'] ?? 'sent').toString(),
      isMine: json['isMine'] == true,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      readAt: DateTime.tryParse(json['readAt']?.toString() ?? ''),
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
