import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:PneumaMesh/ui_room.dart';

import '../proto/pneumacore.pb.dart';

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 0;

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

class MessagePacketAdapter extends TypeAdapter<MessagePacket> {
  @override
  final int typeId = 1;

  @override
  MessagePacket read(BinaryReader reader) {
    final bytes = reader.read() as Uint8List;
    return MessagePacket.fromBuffer(bytes);
  }

  @override
  void write(BinaryWriter writer, MessagePacket obj) {
    writer.write(obj.writeToBuffer());
  }
}

class UiRoomAdapter extends TypeAdapter<UiRoom> {
  @override
  final int typeId = 2;

  @override
  UiRoom read(BinaryReader reader) {
    final roomBytes = reader.readByteList();
    final room = Room.fromBuffer(roomBytes);

    final hasLastMessage = reader.readBool();
    MessagePacket? lastMessage;
    if (hasLastMessage) {
      final lastMessageBytes = reader.readByteList();
      lastMessage = MessagePacket.fromBuffer(lastMessageBytes);
    }

    final isMuted = reader.readBool();

    return UiRoom(room: room, lastMessage: lastMessage, isMuted: isMuted);
  }

  @override
  void write(BinaryWriter writer, UiRoom obj) {
    writer.writeByteList(obj.room.writeToBuffer());

    if (obj.lastMessage != null) {
      writer.writeBool(true);
      writer.writeByteList(obj.lastMessage!.writeToBuffer());
    } else {
      writer.writeBool(false);
    }

    writer.writeBool(obj.isMuted);
  }
}
