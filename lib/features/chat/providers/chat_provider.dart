import 'package:flutter_riverpod/flutter_riverpod.dart';

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? imageUrl;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageUrl,
  });
}

class ChatHistory extends Notifier<List<Message>> {
  @override
  List<Message> build() {
    return [];
  }

  void addMessage(String text, bool isUser, {String? imageUrl}) {
    state = [...state, Message(
      text: text, 
      isUser: isUser, 
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
    )];
  }

  void updateLastMessage(String token) {
    if (state.isEmpty) return;
    final last = state.last;
    final updated = Message(
      text: last.text + token,
      isUser: last.isUser,
      timestamp: last.timestamp,
      imageUrl: last.imageUrl,
    );
    state = [...state.sublist(0, state.length - 1), updated];
  }

  void replaceLastMessage(String fullText, {String? imageUrl}) {
    if (state.isEmpty) return;
    final last = state.last;
    final updated = Message(
      text: fullText,
      isUser: last.isUser,
      timestamp: last.timestamp,
      imageUrl: imageUrl ?? last.imageUrl,
    );
    state = [...state.sublist(0, state.length - 1), updated];
  }

  void removeLastMessage() {
    if (state.isEmpty) return;
    state = state.sublist(0, state.length - 1);
  }

  void clear() {
    state = [];
  }
}

final chatHistoryProvider = NotifierProvider<ChatHistory, List<Message>>(() {
  return ChatHistory();
});
