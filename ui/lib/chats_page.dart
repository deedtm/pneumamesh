import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pneumamesh/pb/message.pb.dart';
import 'package:provider/provider.dart';

import 'daos.dart';
import 'pmdb.dart';
import 'pneuma_core.dart';

class ChatsFallbackValues {
  static const room = 'main-room';
  static const wifiNetwork = 'wifi-fallback';
  static const userId = 'user-id-fallback';
}

class ChatsData {
  static User? user;
  static String currentRoom = ChatsFallbackValues.room;
  static String wifiNetwork = ChatsFallbackValues.wifiNetwork;
}

class ChatsPage extends StatefulWidget {
  final String username;

  const ChatsPage({super.key, required this.username});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  late User user;
  late final Daos daos;
  bool _isFirstStateReady = false;
  StreamSubscription<FullState?>? _initSubscription;

  @override
  void initState() {
    super.initState();
    daos = context.read<Daos>();
    PneumaCore().startStatePolling();
    _initStateData();
  }

  Future<void> _checkAndSaveAccountInfo(User currentUser) async {
    final existingAccount = await daos.accountInfoDao.findAccountByPeerId(
      currentUser.id,
    );
    if (existingAccount == null) {
      await daos.accountInfoDao.createAccount(
        peerId: currentUser.id,
        username: currentUser.name,
        registerTimestamp: currentUser.registerTimestamp.toInt(),
      );
    }
  }

  Future<void> _initStateData() async {
    final firstState = PneumaCore().getFullState();
    if (firstState != null) {
      user = firstState.user;
      ChatsData.user = user;
      _isFirstStateReady = true;
      await openAccountDatabase(user.id);
      await _checkAndSaveAccountInfo(user);
    } else {
      _initSubscription = PneumaCore().stateStream.listen((state) async {
        if (state != null && !_isFirstStateReady) {
          final nextUser = state.user;
          await openAccountDatabase(nextUser.id);
          await _checkAndSaveAccountInfo(nextUser);
          setState(() {
            user = nextUser;
            ChatsData.user = user;
            _isFirstStateReady = true;
          });
          _initSubscription?.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _initSubscription?.cancel();
    super.dispose();
  }

  void _backHandler(bool didPop, Object? result) async {
    if (didPop) return;

    PneumaCore().stopNode();
    PneumaCore().stopStatePolling();
    await Future.delayed(const Duration(milliseconds: 100));
    closeCurrentAccountDatabase();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isFirstStateReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _backHandler,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 75.0,
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(user.name),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _backHandler(false, null);
            },
          ),
        ),
        body: Center(
          child: Container(
            alignment: Alignment.center,
            width: 670,
            child: Column(
              mainAxisAlignment: .center,
              crossAxisAlignment: .center,
              children: [
                const RoomInfoBanner(),
                MessageListArea(currentUserId: user.id),
                const ChatInputArea(),
                UserIdText(initialUserId: user.id),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RoomInfoBanner extends StatelessWidget {
  const RoomInfoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FullState?>(
      stream: PneumaCore().stateStream,
      builder: (context, snapshot) {
        final roomName = snapshot.data?.currentRoom ?? "Connecting...";
        return Text(
          "[$roomName]",
          style: const TextStyle(fontWeight: FontWeight.bold),
        );
      },
    );
  }
}

class UserIdText extends StatelessWidget {
  final String initialUserId;

  const UserIdText({super.key, required this.initialUserId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: StreamBuilder<FullState?>(
        stream: PneumaCore().stateStream,
        builder: (context, snapshot) {
          final id = snapshot.data?.user.id ?? initialUserId;
          return Text(id, style: const TextStyle(fontSize: 10.0));
        },
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final ChatMessage chatMessage;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.chatMessage,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? .centerRight : .centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSecondary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15.0),
            topRight: const Radius.circular(15.0),
            bottomLeft: Radius.circular(isMe ? 15.0 : 0.0),
            bottomRight: Radius.circular(isMe ? 0.0 : 15.0),
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 5.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              chatMessage.sender.name,
              style: TextStyle(
                fontSize: 13.0,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5.0),
            Text(chatMessage.text, style: const TextStyle(fontSize: 16.0)),
          ],
        ),
      ),
    );
  }
}

class MessageListArea extends StatefulWidget {
  final String currentUserId;

  const MessageListArea({super.key, required this.currentUserId});

  @override
  State<MessageListArea> createState() => _MessageListAreaState();
}

class _MessageListAreaState extends State<MessageListArea> {
  late final Daos daos;
  final Map<String, List<ChatMessage>> _messages = {};
  final ScrollController _scrollController = ScrollController();
  final Set<String> _loadedRoomKeys = <String>{};

  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<FullState?>? _stateSubscription;
  String? _currentRoom;
  String? _currentWifiNetwork;

  String _resolveStorageNetwork(FullState state) {
    final wifiNetwork = '${state.wifiBssid}${state.wifiSsid}'.trim();
    if (wifiNetwork.isNotEmpty) {
      return wifiNetwork;
    }

    final protocolNetwork = state.network.trim();
    if (protocolNetwork.isNotEmpty) {
      return protocolNetwork;
    }

    return ChatsFallbackValues.wifiNetwork;
  }

  bool _isDuplicateMessage(String roomKey, ChatMessage message) {
    final roomMessages = _messages[roomKey];
    if (roomMessages == null || roomMessages.isEmpty) {
      return false;
    }

    final last = roomMessages.last;
    return last.sender.id == message.sender.id &&
        last.text == message.text &&
        last.timestamp == message.timestamp;
  }

  @override
  void initState() {
    super.initState();
    daos = context.read<Daos>();

    final initialState = PneumaCore().getFullState();
    if (initialState != null) {
      _currentRoom = initialState.currentRoom;
      _currentWifiNetwork = _resolveStorageNetwork(initialState);
    } else {
      _currentRoom = ChatsFallbackValues.room;
      _currentWifiNetwork = ChatsFallbackValues.wifiNetwork;
    }

    ChatsData.currentRoom = _currentRoom ?? ChatsFallbackValues.room;
    ChatsData.wifiNetwork =
        _currentWifiNetwork ?? ChatsFallbackValues.wifiNetwork;
    _ensureRoomHistoryLoaded();

    _messageSubscription = PneumaCore().incomingMessages.listen((
      ChatMessage newMessage,
    ) {
      if (mounted) {
        final roomKey = _currentRoom ?? ChatsFallbackValues.room;
        setState(() {
          if (!_isDuplicateMessage(roomKey, newMessage)) {
            _messages.putIfAbsent(roomKey, () => []).add(newMessage);
          }
        });
        _scrollToBottom();
      }
    });
    _stateSubscription = PneumaCore().stateStream.listen((FullState? state) {
      if (state != null && mounted) {
        final nextNetwork = _resolveStorageNetwork(state);
        final nextRoom = state.currentRoom;

        if (_currentRoom != nextRoom || _currentWifiNetwork != nextNetwork) {
          setState(() {
            _currentRoom = nextRoom;
            _currentWifiNetwork = nextNetwork;
            ChatsData.currentRoom = nextRoom;
            ChatsData.wifiNetwork = nextNetwork;
          });
          _ensureRoomHistoryLoaded();
        }
      }
    });
  }

  String _currentRoomKey() {
    final network = _currentWifiNetwork ?? ChatsFallbackValues.wifiNetwork;
    final room = _currentRoom ?? ChatsFallbackValues.room;
    return '$network::$room';
  }

  Future<void> _ensureRoomHistoryLoaded() async {
    final roomCacheKey = _currentRoomKey();
    if (_loadedRoomKeys.contains(roomCacheKey)) {
      return;
    }

    _loadedRoomKeys.add(roomCacheKey);

    final roomKey = _currentRoom ?? ChatsFallbackValues.room;
    final savedMessages = await daos.messagesDao.readLatestMessages(
      network: _currentWifiNetwork ?? ChatsFallbackValues.wifiNetwork,
      room: roomKey,
      limit: 50,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      for (final msg in savedMessages) {
        if (!_isDuplicateMessage(roomKey, msg)) {
          _messages.putIfAbsent(roomKey, () => []).add(msg);
        }
      }
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _stateSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomMessages =
        _messages[_currentRoom ?? ChatsFallbackValues.room] ?? [];

    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(10.0),
        itemCount: roomMessages.length,
        itemBuilder: (context, index) {
          final msg = roomMessages[index];
          final isMyMessage = msg.sender.id == widget.currentUserId;

          return MessageBubble(chatMessage: msg, isMe: isMyMessage);
        },
      ),
    );
  }
}

class ChatInputArea extends StatefulWidget {
  const ChatInputArea({super.key});

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  final TextEditingController _inputController = TextEditingController();
  late final Daos daos;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    daos = context.read<Daos>();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_isSending) {
      return;
    }

    final text = _inputController.text.trim();
    if (text.isNotEmpty) {
      _isSending = true;
      _inputController.clear();
      if (mounted) setState(() {});

      try {
        if (text.startsWith('/join')) {
          final parts = text.split(' ');
          if (parts.length > 1) {
            final roomName = parts.sublist(1).join(' ');
            PneumaCore().joinRoom(roomName);
          }
        } else {
          await PneumaCore().sendAndSaveMessage(text);
        }
      } finally {
        _isSending = false;
      }
    }
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(5.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSecondary,
        borderRadius: BorderRadius.circular(25.0),
      ),
      child: Center(
        child: TextField(
          controller: _inputController,
          textAlign: .left,
          onSubmitted: (value) {
            _sendMessage();
          },
          textInputAction: TextInputAction.send,
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(15.0),
            isCollapsed: true,
            hintText: 'Type a message...',
          ),
        ),
      ),
    );
  }

  Widget _buildInputAttachmentsButton() {
    return SizedBox(
      width: 50,
      height: 50,
      child: ElevatedButton(
        onPressed: _sendMessage,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        child: const Icon(Icons.attach_file),
      ),
    );
  }

  Widget _buildInputEnterButton() {
    return SizedBox(
      width: 50,
      height: 50,
      child: ElevatedButton(
        onPressed: _sendMessage,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        child: const Icon(Icons.send),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 670,
      child: Row(
        children: [
          _buildInputAttachmentsButton(),
          const SizedBox(width: 10),
          Expanded(child: _buildInputField()),
          const SizedBox(width: 10),
          _buildInputEnterButton(),
        ],
      ),
    );
  }
}
