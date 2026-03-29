import 'pmdb.dart';

class Daos {
  final accountInfoDao = AccountInfoDao();
  final peersDao = PeersDao();
  final messagesDao = MessagesDao();
  final roomsDao = RoomsDao();
  final cascadesDao = CascadesDao();
}
