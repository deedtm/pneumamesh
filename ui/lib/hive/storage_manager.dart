import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:PneumaMesh/ui_room.dart';

import '../proto/pneumacore.pb.dart';
import 'adapters.dart';

class StorageManager {
  static final StorageManager _instance = StorageManager._internal();
  factory StorageManager() => _instance;
  StorageManager._internal();

  late final Directory _dir;

  Box<List<dynamic>>? _userMessagesBox;
  Box<UiRoom>? _userRoomsBox;

  Future<void> init() async {
    _dir = await getApplicationDocumentsDirectory();
    Hive.init(_dir.path);

    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(MessagePacketAdapter());
    Hive.registerAdapter(UiRoomAdapter());

    await Hive.openBox<Map>('accounts');
    await Hive.openBox<String>('last_login');
  }

  // ================== ACCOUNTS ==================

  Box<Map> getAccountsBox() => Hive.box<Map>('accounts');
  Box<String> getLastLoginBox() => Hive.box<String>('last_login');

  Future<void> addAccount(String name, String privateKey, String userId) async {
    final box = getAccountsBox();
    await box.put(name, {"privateKey": privateKey, "userId": userId});
  }

  Map? getAccount(String name) {
    final box = getAccountsBox();
    return box.get(name);
  }

  Future<void> removeAccount(String name) async {
    final box = getAccountsBox();
    await box.delete(name);
  }

  Future<void> setLastLogin(String name) async {
    final box = getLastLoginBox();
    await box.put('name', name);
  }

  String? getLastLogin() {
    final box = getLastLoginBox();
    return box.get('name');
  }

  // ================== USER SESSION ==================

  Future<void> setSession(String userId) async {
    if (_userMessagesBox != null && _userMessagesBox!.isOpen) {
      await _userMessagesBox!.close();
    }

    final userPath = '${_dir.path}/users/$userId';

    _userMessagesBox = await Hive.openBox<List<dynamic>>(
      'messages',
      path: userPath,
    );
    _userRoomsBox = await Hive.openBox<UiRoom>('rooms', path: userPath);
  }

  Future<void> closeUserSession() async {
    if (_userMessagesBox != null && _userMessagesBox!.isOpen) {
      await _userMessagesBox!.close();
      _userMessagesBox = null;
    }
    if (_userRoomsBox != null && _userRoomsBox!.isOpen) {
      await _userRoomsBox!.close();
      _userRoomsBox = null;
    }
  }

  bool isUserSessionActive() {
    return _userMessagesBox != null &&
        _userMessagesBox!.isOpen &&
        _userRoomsBox != null &&
        _userRoomsBox!.isOpen;
  }

  // ================== ROOMS ==================

  bool doesRoomExist(String roomId) {
    if (!isUserSessionActive()) {
      return false;
    }
    return _userRoomsBox!.keys.any((id) => id == roomId);
  }

  Future<void> addRoom(UiRoom room) async {
    if (!doesRoomExist(room.room.id)) {
      await _userRoomsBox!.put(room.room.id, room);
      await _userMessagesBox!.put(room.room.id, []);
    }
  }

  Future<void> deleteRoom(UiRoom room) async {
    await _userRoomsBox!.delete(room.room.id);
    await _userMessagesBox!.delete(room.room.id);
  }

  Future<void> updateRoom(UiRoom room) async {
    if (doesRoomExist(room.room.id)) {
      await _userRoomsBox!.put(room.room.id, room);
    }
  }

  UiRoom? getRoomById(String roomId) {
    if (!isUserSessionActive()) {
      return null;
    }
    return _userRoomsBox!.get(roomId);
  }

  List<UiRoom> getAllRooms() {
    if (!isUserSessionActive()) {
      return [];
    }
    return _userRoomsBox!.values.toList();
  }

  // ================== MESSAGES ==================

  Future<void> addMessage(String roomId, MessagePacket message) async {
    if (getRoomById(roomId) == null) {
      await addRoom(UiRoom(room: message.room, lastMessage: message));
    }

    final rawData = _userMessagesBox!.get(roomId);

    List<MessagePacket> messages = [];
    if (rawData != null) {
      messages = List<MessagePacket>.from(rawData).cast<MessagePacket>();
    }

    messages.add(message);
    await _userMessagesBox!.put(roomId, messages);
  }

  List<MessagePacket> getRoomMessages(String roomId) {
    final rawData = _userMessagesBox!.get(roomId);
    final messages = rawData == null
        ? <MessagePacket>[]
        : rawData.cast<MessagePacket>();
    return messages;
  }

  MessagePacket? getLastMessage(String roomId) {
    final messages = getRoomMessages(roomId);
    if (messages.isNotEmpty) {
      return messages.last;
    }
    return null;
  }

  Future<void> deleteMessage(String roomId, MessagePacket message) async {
    final rawData = _userMessagesBox!.get(roomId);

    if (rawData != null) {
      List<MessagePacket> messages = List<MessagePacket>.from(
        rawData,
      ).cast<MessagePacket>();
      messages.remove(message);
      await _userMessagesBox!.put(roomId, messages);
    }
  }

  Map<String, List<MessagePacket>> getAllMessages() {
    if (!isUserSessionActive()) {
      return {};
    }
    return _userMessagesBox!.toMap().map(
      (key, value) => MapEntry(key, List<MessagePacket>.from(value)),
    );
  }
}
