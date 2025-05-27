import 'package:flutter/foundation.dart';

@immutable
class ChatResponse {
  final String message;
  final List<Map<String, String>> links;
  final List<Map<String, String>> buttons;
  final bool isAppInfo;

  const ChatResponse({
    required this.message,
    this.links = const [],
    this.buttons = const [],
    this.isAppInfo = false,
  });

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is ChatResponse &&
    runtimeType == other.runtimeType &&
    message == other.message &&
    listEquals(links, other.links) &&
    listEquals(buttons, other.buttons) &&
    isAppInfo == other.isAppInfo;

  @override
  int get hashCode => Object.hash(
    message,
    Object.hashAll(links),
    Object.hashAll(buttons),
    isAppInfo,
  );
} 