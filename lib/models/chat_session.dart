/// A single message within a chat session.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        text: j['text'] as String,
        isUser: j['isUser'] as bool,
        timestamp: DateTime.parse(j['timestamp'] as String),
      );
}

/// One chat session tied to a specific plant identification.
class ChatSession {
  final String id;
  final String plantCommonName;
  final String plantScientificName;
  final String plantFamily;
  final String? plantImageUrl;
  final String? userPhotoPath; // user's own camera photo (optional)
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;
  final bool isPinned;

  const ChatSession({
    required this.id,
    required this.plantCommonName,
    required this.plantScientificName,
    required this.plantFamily,
    this.plantImageUrl,
    this.userPhotoPath,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.isPinned = false,
  });

  ChatSession copyWith({
    List<ChatMessage>? messages,
    DateTime? updatedAt,
    bool? isPinned,
  }) {
    return ChatSession(
      id: id,
      plantCommonName: plantCommonName,
      plantScientificName: plantScientificName,
      plantFamily: plantFamily,
      plantImageUrl: plantImageUrl,
      userPhotoPath: userPhotoPath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantCommonName': plantCommonName,
        'plantScientificName': plantScientificName,
        'plantFamily': plantFamily,
        'plantImageUrl': plantImageUrl,
        'userPhotoPath': userPhotoPath,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'isPinned': isPinned,
      };

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: j['id'] as String,
        plantCommonName: j['plantCommonName'] as String,
        plantScientificName: j['plantScientificName'] as String,
        plantFamily: j['plantFamily'] as String,
        plantImageUrl: j['plantImageUrl'] as String?,
        userPhotoPath: j['userPhotoPath'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        messages: (j['messages'] as List)
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        isPinned: (j['isPinned'] as bool?) ?? false,
      );
}
