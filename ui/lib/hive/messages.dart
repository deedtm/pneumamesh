import 'package:hive/hive.dart';

import '../pb/message.pb.dart';

Box<List> getMessagesBox() {
  return Hive.box<List>('messages');
}

void addMessage(String roomKey, ChatMessage message) async {
  final box = getMessagesBox();
  final rawData = box.get(roomKey);

  List<ChatMessage> messages = [];
  if (rawData != null) {
    messages = List<ChatMessage>.from(rawData).cast<ChatMessage>();
  }

  messages.add(message);
  await box.put(roomKey, messages);
}

List<ChatMessage> getMessages(String roomKey) {
  final box = getMessagesBox();
  final rawData = box.get(roomKey);
  if (rawData != null) {
    return List<ChatMessage>.from(rawData).cast<ChatMessage>();
  }
  return [];
}

void deleteMessage(String roomKey, ChatMessage message) async {
  final box = getMessagesBox();
  final rawData = box.get(roomKey);

  if (rawData != null) {
    List<ChatMessage> messages = List<ChatMessage>.from(
      rawData,
    ).cast<ChatMessage>();
    messages.remove(message);
    await box.put(roomKey, messages);
  }
}
