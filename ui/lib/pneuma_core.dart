import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:pneumamesh/pb/message.pb.dart';

import 'daos.dart';

typedef GeneratePrivateKeyNative = ffi.Pointer<Utf8> Function();
typedef GeneratePrivateKeyDart = ffi.Pointer<Utf8> Function();

typedef StartNodeNative =
    ffi.Void Function(ffi.Pointer<Utf8> username, ffi.Pointer<Utf8> privKey);
typedef StartNodeDart =
    void Function(ffi.Pointer<Utf8> username, ffi.Pointer<Utf8> privKey);

typedef SendMessageNative = ffi.Void Function(ffi.Pointer<Utf8> msg);
typedef SendMessageDart = void Function(ffi.Pointer<Utf8> msg);

typedef JoinRoomNative = ffi.Void Function(ffi.Pointer<Utf8> roomName);
typedef JoinRoomDart = void Function(ffi.Pointer<Utf8> roomName);

typedef MessageCallbackNative =
    ffi.Void Function(ffi.Pointer<ffi.Uint8> data, ffi.Int32 length);
typedef MessageCallbackDart =
    void Function(ffi.Pointer<ffi.Uint8> data, int length);

typedef RegisterMessageCallbackNative =
    ffi.Void Function(
      ffi.Pointer<ffi.NativeFunction<MessageCallbackNative>> cb,
    );
typedef RegisterMessageCallbackDart =
    void Function(ffi.Pointer<ffi.NativeFunction<MessageCallbackNative>> cb);

typedef StopNodeNative = ffi.Void Function();
typedef StopNodeDart = void Function();

typedef GetFullStateNative =
    ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<ffi.Int32> outLength);
typedef GetFullStateDart =
    ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<ffi.Int32> outLength);

typedef FreeMemoryNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef FreeMemoryDart = void Function(ffi.Pointer<ffi.Void>);

typedef GetMyIDNative = ffi.Pointer<Utf8> Function();
typedef GetMyIDDart = ffi.Pointer<Utf8> Function();

class PneumaCore {
  static final PneumaCore _instance = PneumaCore._internal();
  factory PneumaCore() => _instance;
  PneumaCore._internal();

  Daos? daos;

  late ffi.DynamicLibrary nativeLib;
  late GeneratePrivateKeyDart generatePrivateKeyC;
  late StartNodeDart startNodeC;
  late SendMessageDart sendMessageC;
  late JoinRoomDart joinRoomC;
  late RegisterMessageCallbackDart registerMessageCallbackC;
  ffi.NativeCallable<MessageCallbackNative>? _messageCb;
  late StopNodeDart stopNodeC;
  late GetFullStateDart getFullStateC;
  late FreeMemoryDart freeMemoryC;
  late GetMyIDDart getMyIdC;

  bool _isInitialized = false;

  final StreamController<ChatMessage> _incomingMessagesController =
      StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get incomingMessages =>
      _incomingMessagesController.stream;

  static const MethodChannel _bleChannel = MethodChannel(
    'com.pneumamesh/broadcaster',
  );

  String _resolveStorageNetwork(FullState state) {
    return state.network.trim();
  }

  static void _onMessageFromGo(
    ffi.Pointer<ffi.Uint8> dataPtr,
    int length,
  ) async {
    final bytes = dataPtr.asTypedList(length);
    final message = ChatMessage.fromBuffer(bytes);

    final core = PneumaCore();
    if (core.daos != null) {
      final existingPeer = await core.daos!.peersDao.findPeerById(
        message.sender.id,
      );
      if (existingPeer == null) {
        await core.daos!.peersDao.createPeer(
          peerId: message.sender.id,
          username: message.sender.name,
          registerTimestamp: message.sender.registerTimestamp.toInt(),
          firstSeenTimestamp: DateTime.now().millisecondsSinceEpoch,
        );
      }

      final state = core.getFullState();
      String room = 'main-room';
      String network = '';
      if (state != null) {
        room = state.currentRoom;
        network = core._resolveStorageNetwork(state);
      }

      await core.daos!.messagesDao.createMessage(
        network: network,
        room: room,
        peerId: message.sender.id,
        content: message.text,
        messageTimestamp: message.timestamp.toInt(),
      );
    }

    core._incomingMessagesController.add(message);
    core.freeMemoryC(dataPtr.cast());
  }

  ffi.DynamicLibrary _openLibrary() {
    if (Platform.isAndroid || Platform.isLinux) {
      return ffi.DynamicLibrary.open('libpneumamesh.so');
    }
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('pneumamesh.dll');
    }
    throw UnsupportedError('This platform is not supported');
  }

  void init({Daos? daos}) {
    if (_isInitialized) {
      return;
    }

    this.daos = daos;

    nativeLib = _openLibrary();

    generatePrivateKeyC = nativeLib
        .lookup<ffi.NativeFunction<GeneratePrivateKeyNative>>(
          'GeneratePrivateKey',
        )
        .asFunction<GeneratePrivateKeyDart>();

    startNodeC = nativeLib
        .lookup<ffi.NativeFunction<StartNodeNative>>('StartNode')
        .asFunction<StartNodeDart>();

    sendMessageC = nativeLib
        .lookup<ffi.NativeFunction<SendMessageNative>>('SendMessage')
        .asFunction<SendMessageDart>();

    joinRoomC = nativeLib
        .lookup<ffi.NativeFunction<JoinRoomNative>>('JoinRoom')
        .asFunction<JoinRoomDart>();

    registerMessageCallbackC = nativeLib
        .lookup<ffi.NativeFunction<RegisterMessageCallbackNative>>(
          'RegisterMessageCallback',
        )
        .asFunction<RegisterMessageCallbackDart>();

    _messageCb = ffi.NativeCallable<MessageCallbackNative>.listener(
      _onMessageFromGo,
    );

    registerMessageCallbackC(_messageCb!.nativeFunction);

    stopNodeC = nativeLib
        .lookup<ffi.NativeFunction<StopNodeNative>>('StopNode')
        .asFunction<StopNodeDart>();

    getFullStateC = nativeLib
        .lookup<ffi.NativeFunction<GetFullStateNative>>('GetFullState')
        .asFunction<GetFullStateDart>();

    freeMemoryC = nativeLib
        .lookup<ffi.NativeFunction<FreeMemoryNative>>('FreeMemory')
        .asFunction<FreeMemoryDart>();

    getMyIdC = nativeLib
        .lookup<ffi.NativeFunction<GetMyIDNative>>('GetMyID')
        .asFunction<GetMyIDDart>();

    _isInitialized = true;
  }

  String generatePrivateKey() {
    final ptr = generatePrivateKeyC();
    final str = ptr.toDartString();
    freeMemoryC(ptr.cast());
    return str;
  }

  Future<void> startNode(String username, String privateKeyBase64) async {
    final un = username.toNativeUtf8();
    final pk = privateKeyBase64.toNativeUtf8();
    startNodeC(un, pk);
    calloc.free(un);
    calloc.free(pk);
  }

  void sendMessage(String text) {
    final p = text.toNativeUtf8();
    sendMessageC(p);
    calloc.free(p);
  }

  Future<void> sendAndSaveMessage(String text) async {
    final state = getFullState();
    if (state != null && daos != null) {
      final currentUser = state.user;
      final room = state.currentRoom;
      final network = _resolveStorageNetwork(state);

      final existingPeer = await daos!.peersDao.findPeerById(currentUser.id);
      if (existingPeer == null) {
        await daos!.peersDao.createPeer(
          peerId: currentUser.id,
          username: currentUser.name,
          registerTimestamp: currentUser.registerTimestamp.toInt(),
          firstSeenTimestamp: DateTime.now().millisecondsSinceEpoch,
        );
      }

      final tsSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await daos!.messagesDao.createMessage(
        network: network,
        room: room,
        peerId: currentUser.id,
        content: text,
        messageTimestamp: tsSeconds,
      );

      sendMessage(text);

      final localMsg = ChatMessage(
        sender: currentUser,
        text: text,
        timestamp: Int64(tsSeconds),
      );
      _incomingMessagesController.add(localMsg);
    } else {
      sendMessage(text);
    }
  }

  void joinRoom(String roomName) {
    final p = roomName.toNativeUtf8();
    joinRoomC(p);
    calloc.free(p);
  }

  void stopNode() {
    stopNodeC();
  }

  FullState? getFullState() {
    final lengthPtr = calloc<ffi.Int32>();

    try {
      final dataPtr = getFullStateC(lengthPtr);

      if (dataPtr == ffi.nullptr) {
        return null;
      }

      final length = lengthPtr.value;
      final bytes = dataPtr.asTypedList(length);

      final state = FullState.fromBuffer(bytes);

      freeMemoryC(dataPtr.cast());

      return state;
    } finally {
      calloc.free(lengthPtr);
    }
  }

  void dispose() {
    stopStatePolling();
    _messageCb?.close();
    _messageCb = null;
    _isInitialized = false;
  }

  final StreamController<FullState?> _stateController =
      StreamController<FullState?>.broadcast();
  Stream<FullState?> get stateStream => _stateController.stream;
  Timer? _stateTimer;

  void startStatePolling() {
    _stateTimer?.cancel();
    _stateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final state = getFullState();
      _stateController.add(state);
    });
  }

  void stopStatePolling() {
    _stateTimer?.cancel();
  }

  String getMyID() {
    final ptr = getMyIdC();
    if (ptr == ffi.nullptr) {
      return '';
    }
    final str = ptr.toDartString();
    freeMemoryC(ptr.cast());
    return str;
  }

  Future<void> startBleDiscovery() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      // Ждём, пока Go core создаст PeerID. Нода стартует в goroutine — не мгновенно.
      String peerId = '';
      for (var i = 0; i < 20; i++) {
        peerId = getMyID();
        if (peerId.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (peerId.isNotEmpty) {
        await _bleChannel.invokeMethod('setPeerId', {'peerId': peerId});
      }
      await _bleChannel.invokeMethod('startAdvertising');
      await _bleChannel.invokeMethod('startScanning');
    } catch (e) {
      print('BLE discovery error: $e');
    }
  }

  Future<void> stopBleDiscovery() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _bleChannel.invokeMethod('stopScanning');
      await _bleChannel.invokeMethod('stopAdvertising');
    } catch (_) {
      // No-op: permissions or platform channel might be unavailable.
    }
  }
}
