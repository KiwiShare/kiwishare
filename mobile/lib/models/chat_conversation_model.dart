enum ChatDirection { buying, selling }

class ChatConversationModel {
  const ChatConversationModel({
    required this.id,
    required this.itemId,
    required this.itemTitle,
    required this.itemImageUrl,
    required this.participantId,
    required this.participantName,
    this.participantAvatarUrl,
    required this.direction,
    required this.status,
    required this.lastMessage,
    this.lastMessageAt,
    required this.unreadCount,
  });

  final String id;
  final String itemId;
  final String itemTitle;
  final String itemImageUrl;
  final String participantId;
  final String participantName;
  final String? participantAvatarUrl;
  final ChatDirection direction;
  final String status;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  bool get isActive => status == 'active';

  ChatConversationModel copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) {
    return ChatConversationModel(
      id: id,
      itemId: itemId,
      itemTitle: itemTitle,
      itemImageUrl: itemImageUrl,
      participantId: participantId,
      participantName: participantName,
      participantAvatarUrl: participantAvatarUrl,
      direction: direction,
      status: status,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  factory ChatConversationModel.fromJson(Map<String, dynamic> json) {
    final item = _stringMap(json['item']);
    final participant = _stringMap(json['participant']);
    return ChatConversationModel(
      id: (json['id'] ?? '').toString(),
      itemId: (item['id'] ?? '').toString(),
      itemTitle: (item['title'] ?? 'Unavailable item').toString(),
      itemImageUrl: (item['imageUrl'] ?? '').toString(),
      participantId: (participant['id'] ?? '').toString(),
      participantName: (participant['displayName'] ?? 'Kiwi member').toString(),
      participantAvatarUrl: participant['avatarUrl']?.toString(),
      direction: json['direction'] == 'selling'
          ? ChatDirection.selling
          : ChatDirection.buying,
      status: (json['status'] ?? 'active').toString(),
      lastMessage: (json['lastMessageText'] ?? '').toString(),
      lastMessageAt: DateTime.tryParse(json['lastMessageAt']?.toString() ?? ''),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}

Map<String, dynamic> _stringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}
