import 'package:flutter/foundation.dart';

@immutable
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Map<String, String>>? links;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.links,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'links': links,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'] as String,
    isUser: json['isUser'] as bool,
    timestamp: DateTime.parse(json['timestamp'] as String),
    links: json['links'] != null 
      ? List<Map<String, String>>.from(
          (json['links'] as List).map((e) => Map<String, String>.from(e))
        )
      : null,
  );

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is ChatMessage &&
    runtimeType == other.runtimeType &&
    text == other.text &&
    isUser == other.isUser &&
    timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(text, isUser, timestamp);
} 