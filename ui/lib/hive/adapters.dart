import 'dart:typed_data';
import 'package:hive/hive.dart';
import '../pb/message.pb.dart'; 

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 0; // любой свободный id от 0 до 223

  @override
  User read(BinaryReader reader) {
    final bytes = reader.read() as Uint8List;
    return User.fromBuffer(bytes);
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer.write(obj.writeToBuffer());
  }
}

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 1; // любой свободный id от 0 до 223

  @override
  ChatMessage read(BinaryReader reader) {
    final bytes = reader.read() as Uint8List;
    return ChatMessage.fromBuffer(bytes);
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer.write(obj.writeToBuffer());
  }
}