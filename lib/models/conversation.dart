import 'message.dart';

class Conversation {
  final String id;
  String title;
  final DateTime createdAt;
  final List<Message> messages;
  String instructions;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
    this.instructions = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'instructions': instructions,
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'],
        title: json['title'],
        createdAt: DateTime.parse(json['createdAt']),
        messages:
            (json['messages'] as List).map((m) => Message.fromJson(m)).toList(),
        instructions: json['instructions'] ?? '',
      );
}
