import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'hive/storage_manager.dart';
import 'logger.dart' show log;
import 'notification_service.dart';
import 'proto/pneumacore.pb.dart';
import 'sos_service.dart';
import 'ui_room.dart';
import 'utils.dart';

typedef GeneratePrivateKeyNative = ffi.Pointer<Utf8> Function();
typedef GeneratePrivateKeyDart = ffi.Pointer<Utf8> Function();

typedef InitCoreNative =
    ffi.Void Function(
      ffi.Pointer<Utf8> privateKey64,
      ffi.Pointer<Utf8> username,
    );
typedef InitCoreDart =
    void Function(ffi.Pointer<Utf8> privateKey64, ffi.Pointer<Utf8> username);

typedef StopCoreNative = ffi.Void Function();
typedef StopCoreDart = void Function();

typedef GetMeNative =
    ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<ffi.Int32> outLength);
typedef GetMeDart =
    ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<ffi.Int32> outLength);

typedef GetRoomsNative =
    ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<ffi.Int32> outLength);
typedef GetRoomsDart =
    ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<ffi.Int32> outLength);

// ================== CALLBACKS ==================

// Discovery
typedef DiscoveryCallbackNative =
    ffi.Void Function(ffi.Pointer<ffi.Uint8> data, ffi.Int length);
typedef DiscoveryCallbackDart =
    void Function(ffi.Pointer<ffi.Uint8> data, int length);

// Message
typedef MessageCallbackNative =
    ffi.Void Function(ffi.Pointer<ffi.Uint8> data, ffi.Int length);
typedef MessageCallbackDart =
    void Function(ffi.Pointer<ffi.Uint8> data, int length);

// Sos
typedef SosCallbackNative =
    ffi.Void Function(ffi.Pointer<ffi.Uint8> data, ffi.Int length);
typedef SosCallbackDart =
    void Function(ffi.Pointer<ffi.Uint8> data, int length);

// ================== END CALLBACKS ==================

// ================== REGISTER CALLBACKS ==================

// Discovery
typedef RegisterDiscoveryCallbackNative =
    ffi.Void Function(
      ffi.Pointer<ffi.NativeFunction<DiscoveryCallbackNative>> cb,
    );
typedef RegisterDiscoveryCallbackDart =
    void Function(ffi.Pointer<ffi.NativeFunction<DiscoveryCallbackNative>> cb);

// Message
typedef RegisterMessageCallbackNative =
    ffi.Void Function(
      ffi.Pointer<ffi.NativeFunction<MessageCallbackNative>> cb,
    );
typedef RegisterMessageCallbackDart =
    void Function(ffi.Pointer<ffi.NativeFunction<MessageCallbackNative>> cb);

// Sos
typedef RegisterSosCallbackNative =
    ffi.Void Function(ffi.Pointer<ffi.NativeFunction<SosCallbackNative>> cb);
typedef RegisterSosCallbackDart =
    void Function(ffi.Pointer<ffi.NativeFunction<SosCallbackNative>> cb);

// ================== END REGISTER CALLBACKS ==================

typedef ImportRoomNative =
    ffi.Void Function(ffi.Pointer<Utf8> roomId, ffi.Pointer<Utf8> roomName);
typedef ImportRoomDart =
    void Function(ffi.Pointer<Utf8> roomId, ffi.Pointer<Utf8> roomName);

typedef CreateRoomNative =
    ffi.Pointer<ffi.Uint8> Function(
      ffi.Pointer<Utf8> roomName,
      ffi.Pointer<ffi.Int32> outLength,
    );
typedef CreateRoomDart =
    ffi.Pointer<ffi.Uint8> Function(
      ffi.Pointer<Utf8> roomName,
      ffi.Pointer<ffi.Int32> outLength,
    );

typedef BlockRoomNative = ffi.Void Function(ffi.Pointer<Utf8> roomId);
typedef BlockRoomDart = void Function(ffi.Pointer<Utf8> roomId);

typedef UnblockRoomNative = ffi.Void Function(ffi.Pointer<Utf8> roomId);
typedef UnblockRoomDart = void Function(ffi.Pointer<Utf8> roomId);

// ================== SEND ==================

// Message
typedef SendMessageNative =
    ffi.Void Function(ffi.Pointer<ffi.Uint8> data, ffi.Int length);
typedef SendMessageDart =
    void Function(ffi.Pointer<ffi.Uint8> data, int length);

// Sos
typedef SendSosNative =
    ffi.Void Function(ffi.Pointer<ffi.Uint8> data, ffi.Int length);
typedef SendSosDart = void Function(ffi.Pointer<ffi.Uint8> data, int length);

// ================== END SEND ==================

typedef FreeMemoryNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef FreeMemoryDart = void Function(ffi.Pointer<ffi.Void>);

class PneumaCore {
  static final PneumaCore _instance = PneumaCore._internal();
  factory PneumaCore() => _instance;
  PneumaCore._internal();

  late ffi.DynamicLibrary nativeLib;

  late GeneratePrivateKeyDart generatePrivateKeyC;
  late InitCoreDart initCoreC;
  late StopCoreDart stopCoreC;
  late GetMeDart getMeC;
  late GetRoomsDart getRoomsC;

  ffi.NativeCallable<DiscoveryCallbackNative>? _discoveryCallback;
  ffi.NativeCallable<MessageCallbackNative>? _messageCallback;
  ffi.NativeCallable<SosCallbackNative>? _sosCallback;

  late RegisterDiscoveryCallbackDart registerDiscoveryCallbackC;
  late RegisterMessageCallbackDart registerMessageCallbackC;
  late RegisterSosCallbackDart registerSosCallbackC;

  late ImportRoomDart importRoomC;
  late CreateRoomDart createRoomC;
  late BlockRoomDart blockRoomC;
  late UnblockRoomDart unblockRoomC;

  late SendMessageDart sendMessageC;
  late SendSosDart sendSosC;

  late FreeMemoryDart freeMemoryC;

  bool _isInitialized = false;
  bool blockSosNotifications = false;

  List<UiRoom> rooms = [];
  UiRoom? currentRoom;
  void Function()? onRoomsUpdated;
  void Function(String, MessagePacket)? toUpdateLastMessage;

  late User user;

  final StreamController<MessagePacket> _msgStream =
      StreamController<MessagePacket>.broadcast();
  Stream<MessagePacket> get messagesStream => _msgStream.stream;

  final StreamController<SosPacket> _sosStream =
      StreamController<SosPacket>.broadcast();
  Stream<SosPacket> get sosStream => _sosStream.stream;

  static const MethodChannel _bleChannel = MethodChannel(
    'com.pneumamesh/broadcaster',
  );

  static void _onDiscoveryFromGo(
    ffi.Pointer<ffi.Uint8> dataPtr,
    int length,
  ) async {
    final bytes = dataPtr.asTypedList(length);
    final packet = DiscoveryPacket.fromBuffer(bytes);

    final core = PneumaCore();
    final storageManager = StorageManager();

    bool hasUpdate = false;

    if (packet.type == DiscoveryPacketType.ACTIVE) {
      // удаляем все комнаты, которых нет в пакете
      core.rooms.removeWhere((uiRoom) {
        int incomingIndex = packet.rooms.indexWhere(
          (c) => c.id == uiRoom.room.id,
        );
        if (incomingIndex == -1) {
          storageManager.deleteRoom(uiRoom);
          hasUpdate = true;
        }
        return incomingIndex == -1;
      });
    } else {
      // тип пакета неопределен или это другой пир поделился => только добавляем
      for (final newRoom in packet.rooms) {
        int existingIndex = core.rooms.indexWhere(
          (c) => c.room.id == newRoom.id,
        );

        if (existingIndex == -1) {
          core.rooms.add(UiRoom(room: newRoom));
          await storageManager.addRoom(UiRoom(room: newRoom));
          hasUpdate = true;
        }
      }
    }
    core.freeMemoryC(dataPtr.cast());
    if (hasUpdate && core.onRoomsUpdated != null) core.onRoomsUpdated!();
  }

  static void _onMessageFromGo(
    ffi.Pointer<ffi.Uint8> dataPtr,
    int length,
  ) async {
    final bytes = dataPtr.asTypedList(length);
    final packet = MessagePacket.fromBuffer(bytes);

    final core = PneumaCore();

    final storageManager = StorageManager();
    await storageManager.addMessage(packet.room.id, packet);

    if (core.toUpdateLastMessage != null) {
      core.toUpdateLastMessage!(packet.room.id, packet);
    }

    if (packet.room.id != core.currentRoom?.room.id &&
        packet.sender.id != core.user.id) {
      await NotificationService().messageNotification(
        roomId: packet.room.id,
        roomName: packet.room.name,
        body: "${packet.sender.name}:  ${packet.text}",
      );
    }

    core._msgStream.add(packet);
    core.freeMemoryC(dataPtr.cast());
  }

  static void _onSosFromGo(ffi.Pointer<ffi.Uint8> dataPtr, int length) async {
    final bytes = dataPtr.asTypedList(length);
    final packet = SosPacket.fromBuffer(bytes);

    final core = PneumaCore();

    log.i(
      'Received SOS from ${packet.sender.name} at ${packet.position.latitude}, ${packet.position.longitude}',
    );
    if (packet.sender.id == core.user.id) {
      return;
    }

    SosService().addPacket(packet);

    if (!core.blockSosNotifications) {
      PositionInfo pos = packet.position;
      await NotificationService().sosNotification(
        userId: packet.sender.id,
        body: "${pos.prettyTime}: ${packet.sender.name} is sending SOS",
      );
    }
    core._sosStream.add(packet);
    core.freeMemoryC(dataPtr.cast());
  }

  ffi.DynamicLibrary _openLibrary() {
    if (Platform.isAndroid) {
      return ffi.DynamicLibrary.open('libpneumamesh.so');
    }
    throw UnsupportedError('This platform is not supported');
  }

  void init() {
    if (_isInitialized) {
      return;
    }

    nativeLib = _openLibrary();

    generatePrivateKeyC = nativeLib
        .lookup<ffi.NativeFunction<GeneratePrivateKeyNative>>(
          'GeneratePrivateKey',
        )
        .asFunction<GeneratePrivateKeyDart>();
    initCoreC = nativeLib
        .lookup<ffi.NativeFunction<InitCoreNative>>('InitCore')
        .asFunction<InitCoreDart>();
    stopCoreC = nativeLib
        .lookup<ffi.NativeFunction<StopCoreNative>>('StopCore')
        .asFunction<StopCoreDart>();

    getMeC = nativeLib
        .lookup<ffi.NativeFunction<GetMeNative>>('GetMe')
        .asFunction<GetMeDart>();
    getRoomsC = nativeLib
        .lookup<ffi.NativeFunction<GetRoomsNative>>('GetRooms')
        .asFunction<GetRoomsDart>();

    _discoveryCallback = ffi.NativeCallable<DiscoveryCallbackNative>.listener(
      _onDiscoveryFromGo,
    );
    _messageCallback = ffi.NativeCallable<MessageCallbackNative>.listener(
      _onMessageFromGo,
    );
    _sosCallback = ffi.NativeCallable<SosCallbackNative>.listener(_onSosFromGo);

    registerDiscoveryCallbackC = nativeLib
        .lookup<ffi.NativeFunction<RegisterMessageCallbackNative>>(
          'RegisterDiscoveryCallback',
        )
        .asFunction<RegisterMessageCallbackDart>();
    registerMessageCallbackC = nativeLib
        .lookup<ffi.NativeFunction<RegisterMessageCallbackNative>>(
          'RegisterMessageCallback',
        )
        .asFunction<RegisterMessageCallbackDart>();
    registerSosCallbackC = nativeLib
        .lookup<ffi.NativeFunction<RegisterSosCallbackNative>>(
          'RegisterSosCallback',
        )
        .asFunction<RegisterSosCallbackDart>();

    importRoomC = nativeLib
        .lookup<ffi.NativeFunction<ImportRoomNative>>('ImportRoom')
        .asFunction<ImportRoomDart>();
    createRoomC = nativeLib
        .lookup<ffi.NativeFunction<CreateRoomNative>>('CreateRoom')
        .asFunction<CreateRoomDart>();
    blockRoomC = nativeLib
        .lookup<ffi.NativeFunction<BlockRoomNative>>('BlockRoom')
        .asFunction<BlockRoomDart>();
    unblockRoomC = nativeLib
        .lookup<ffi.NativeFunction<UnblockRoomNative>>('UnblockRoom')
        .asFunction<UnblockRoomDart>();

    sendMessageC = nativeLib
        .lookup<ffi.NativeFunction<SendMessageNative>>('SendMessage')
        .asFunction<SendMessageDart>();
    sendSosC = nativeLib
        .lookup<ffi.NativeFunction<SendSosNative>>('SendSos')
        .asFunction<SendSosDart>();

    freeMemoryC = nativeLib
        .lookup<ffi.NativeFunction<FreeMemoryNative>>('FreeMemory')
        .asFunction<FreeMemoryDart>();

    _isInitialized = true;
  }

  String generatePrivateKey() {
    final ptr = generatePrivateKeyC();
    final str = ptr.toDartString();
    freeMemoryC(ptr.cast());
    return str;
  }

  Future<void> initCore(String privateKeyBase64, String username) async {
    final name = username.toNativeUtf8();
    final key = privateKeyBase64.toNativeUtf8();
    initCoreC(key, name);
    calloc.free(name);
    calloc.free(key);

    registerDiscoveryCallbackC(_discoveryCallback!.nativeFunction);
    registerMessageCallbackC(_messageCallback!.nativeFunction);
    registerSosCallbackC(_sosCallback!.nativeFunction);
  }

  void stopCore() {
    stopCoreC();
  }

  Future<void> initUser() async {
    final lengthPtr = calloc<ffi.Int32>();

    try {
      final dataPtr = getMeC(lengthPtr);

      if (dataPtr == ffi.nullptr) {
        return;
      }

      final length = lengthPtr.value;
      final bytes = dataPtr.asTypedList(length);

      final packet = User.fromBuffer(bytes);

      freeMemoryC(dataPtr.cast());

      user = packet;
    } finally {
      calloc.free(lengthPtr);
    }
  }

  Future<void> initRooms(List<UiRoom> savedRooms) async {
    DiscoveryPacket? currentRooms = PneumaCore().getRooms();
    if (currentRooms == null) {
      return;
    }
    for (final room in savedRooms) {
      importRoom(room.room.id, room.room.name);
      bool doesExist = rooms.any((r) => r.room.id == room.room.id);
      if (doesExist) continue;
      rooms.add(room);
    }
    for (final room in currentRooms.rooms) {
      bool doesExist = rooms.any((r) => r.room.id == room.id);
      if (doesExist) continue;
      rooms.add(UiRoom(room: room));
    }
  }

  DiscoveryPacket? getRooms() {
    final lengthPtr = calloc<ffi.Int32>();

    try {
      final dataPtr = getRoomsC(lengthPtr);

      if (dataPtr == ffi.nullptr) {
        return null;
      }

      final length = lengthPtr.value;
      final bytes = dataPtr.asTypedList(length);

      final packet = DiscoveryPacket.fromBuffer(bytes);

      freeMemoryC(dataPtr.cast());

      return packet;
    } finally {
      calloc.free(lengthPtr);
    }
  }

  void importRoom(String roomId, String roomName) {
    final idPtr = roomId.toNativeUtf8();
    final namePtr = roomName.toNativeUtf8();

    try {
      importRoomC(idPtr, namePtr);
    } finally {
      calloc.free(idPtr);
      calloc.free(namePtr);
    }
  }

  Room createRoom(String roomName) {
    final lengthPtr = calloc<ffi.Int32>();

    try {
      final p = roomName.toNativeUtf8();

      final dataPtr = createRoomC(p, lengthPtr);

      if (dataPtr == ffi.nullptr) {
        throw Exception('Failed to create room');
      }
      final length = lengthPtr.value;
      final bytes = dataPtr.asTypedList(length);

      final room = Room.fromBuffer(bytes);

      freeMemoryC(dataPtr.cast());
      freeMemoryC(p.cast());

      return room;
    } finally {
      calloc.free(lengthPtr);
    }
  }

  void blockRoom(String roomId) {
    final idPtr = roomId.toNativeUtf8();

    try {
      blockRoomC(idPtr);
    } finally {
      calloc.free(idPtr);
    }
  }

  void unblockRoom(String roomId) {
    final idPtr = roomId.toNativeUtf8();

    try {
      unblockRoomC(idPtr);
    } finally {
      calloc.free(idPtr);
    }
  }

  void sendMessage(MessagePacket msg) {
    final bytes = msg.writeToBuffer();

    final p = calloc<ffi.Uint8>(bytes.length);

    try {
      p.asTypedList(bytes.length).setAll(0, bytes);
      sendMessageC(p, bytes.length);
    } finally {
      calloc.free(p);
    }
  }

  void sendSos(Position position) {
    final bytes = PositionInfo(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speed: position.speed,
      accuracy: position.accuracy,
      timestamp: Int64(position.timestamp.millisecondsSinceEpoch),
    ).writeToBuffer();

    final p = calloc<ffi.Uint8>(bytes.length);

    try {
      p.asTypedList(bytes.length).setAll(0, bytes);
      sendSosC(p, bytes.length);
    } finally {
      calloc.free(p);
    }
  }

  Future<void> sendAndSaveMessage(UiRoom uiRoom, String text) async {
    final tsSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final room = uiRoom.room;

    final msg = MessagePacket(
      sender: user,
      room: Room(id: room.id, name: room.name),
      text: text,
      timestamp: Int64(tsSeconds),
    );

    final storageManager = StorageManager();
    await storageManager.addMessage(uiRoom.room.id, msg);

    _msgStream.add(msg);

    sendMessage(msg);
  }

  Future<void> stopAll() async {
    stopCore();
    stopBleDiscovery();
  }

  void dispose() {
    _msgStream.close();
    _sosStream.close();

    _messageCallback?.close();
    _messageCallback = null;
    _discoveryCallback?.close();
    _discoveryCallback = null;
    _sosCallback?.close();
    _sosCallback = null;
    _isInitialized = false;
  }

  Future<void> startBleDiscovery() async {
    try {
      await _bleChannel.invokeMethod('setPeerId', {'peerId': user.id});
      await _bleChannel.invokeMethod('startAdvertising');
      await _bleChannel.invokeMethod('startScanning');
    } catch (e) {
      log.e('BLE discovery start error: $e');
    }
  }

  Future<void> stopBleDiscovery() async {
    try {
      await _bleChannel.invokeMethod('stopScanning');
      await _bleChannel.invokeMethod('stopAdvertising');
    } catch (e) {
      log.e('BLE discovery stop error: $e');
    }
  }
}
