class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    this.type = 'text',
    required this.text,
    this.imageUrl,
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
  final String status;
  final bool isMine;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isImage => type == 'image' && (imageUrl?.isNotEmpty ?? false);

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: (json['id'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      receiverId: (json['receiverId'] ?? '').toString(),
      type: (json['type'] ?? 'text').toString(),
      text: (json['text'] ?? '').toString(),
      imageUrl: json['imageUrl']?.toString(),
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
