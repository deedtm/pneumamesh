import 'proto/pneumacore.pb.dart';
import 'ui_room.dart';

class FallbackValues {
  static Room room = Room(id: ':bad-room', name: 'BAD ROOM');
  static UiRoom uiRoom = UiRoom(room: room);
}
