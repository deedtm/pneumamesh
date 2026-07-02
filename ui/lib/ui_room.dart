import 'proto/pneumacore.pb.dart';

class UiRoom {
  final Room room;

  bool isMuted;
  int unreadCount = 0;
  MessagePacket? lastMessage;

  UiRoom({required this.room, this.isMuted = false, this.lastMessage});
}
