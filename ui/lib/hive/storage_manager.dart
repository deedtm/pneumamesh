import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../pb/message.pb.dart';
import 'adapters.dart';

class StorageManager {
  // общая папка приложения
  late final Directory _dir;

  // личный бокс текущего юзера
  Box<List>? _msgBox;

  Future<void> init() async {
    _dir = await getApplicationDocumentsDirectory();
    Hive.init(_dir.path);

    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(ChatMessageAdapter());

    await Hive.openBox<Map>('accounts');
  }

  Future<void> setSession(String userId) async {
    if (_msgBox != null && _msgBox!.isOpen) {
      await _msgBox!.close();
    }

    final userPath = '${_dir.path}/users/$userId';

    _msgBox = await Hive.openBox<List>('messages', path: userPath);
  }

  Future<void> closeUserSession() async {
    if (_msgBox != null && _msgBox!.isOpen) {
      await _msgBox!.close();
      _msgBox = null;
    }
  }

  Box<Map> getAccountsBox() => Hive.box<Map>('accounts');

  void addAccount(String name, String privateKey, String userId) async {
    final box = getAccountsBox();
    await box.put(name, {"privateKey": privateKey, "userId": userId});
  }

  Map? getAccount(String name) {
    final box = getAccountsBox();
    return box.get(name);
  }

  void removeAccount(String name) async {
    final box = getAccountsBox();
    await box.delete(name);
  }

  void addMessage(String roomKey, ChatMessage message) async {
    final rawData = _msgBox!.get(roomKey);

    List<ChatMessage> messages = [];
    if (rawData != null) {
      messages = List<ChatMessage>.from(rawData).cast<ChatMessage>();
    }

    messages.add(message);
    await _msgBox!.put(roomKey, messages);
  }

  List<ChatMessage> getMessages(String roomKey) {
    final rawData = _msgBox!.get(roomKey);
    if (rawData != null) {
      return List<ChatMessage>.from(rawData).cast<ChatMessage>();
    }
    return [];
  }

  void deleteMessage(String roomKey, ChatMessage message) async {
    final rawData = _msgBox!.get(roomKey);

    if (rawData != null) {
      List<ChatMessage> messages = List<ChatMessage>.from(
        rawData,
      ).cast<ChatMessage>();
      messages.remove(message);
      await _msgBox!.put(roomKey, messages);
    }
  }
}
