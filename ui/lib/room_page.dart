import 'dart:async';

import 'package:flutter/material.dart';

import 'fallback_values.dart';
import 'hive/storage_manager.dart';
import 'notification_service.dart';
import 'pneumacore.dart';
import 'proto/pneumacore.pb.dart';
import 'ui_room.dart';
import 'utils.dart';

class RoomPage extends StatefulWidget {
  const RoomPage({super.key});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  late UiRoom _room;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInit) {
      final navigatorArgs = ModalRoute.of(context)?.settings.arguments;

      if (navigatorArgs is UiRoom) {
        _room = navigatorArgs;
      } else {
        _room = FallbackValues.uiRoom;
      }

      PneumaCore().currentRoom = _room;
      PneumaCore().blockRoom(_room.room.id);
      NotificationService().clearMessagesCache(_room.room.id);

      var roomIndex = PneumaCore().rooms.indexOf(_room);
      PneumaCore().rooms[roomIndex].unreadCount = 0;
      StorageManager().updateRoom(PneumaCore().rooms[roomIndex]);

      _isInit = true;
    }
  }

  @override
  void dispose() {
    PneumaCore().currentRoom = null;
    PneumaCore().unblockRoom(_room.room.id);
    var roomIndex = PneumaCore().rooms.indexOf(_room);
    PneumaCore().rooms[roomIndex].unreadCount = 0;
    StorageManager().updateRoom(PneumaCore().rooms[roomIndex]);
    super.dispose();
  }

  void _backHandler(bool didPop, Object? result) async {
    if (didPop) return;
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _backHandler,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 75.0,
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(
            _room.room.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                MessageListArea(room: _room),
                Padding(padding: EdgeInsetsGeometry.only(top: 10.0)),
                InputArea(room: _room),
                Padding(padding: EdgeInsetsGeometry.only(bottom: 10.0)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MessageListArea extends StatefulWidget {
  final UiRoom room;

  const MessageListArea({super.key, required this.room});

  @override
  State<MessageListArea> createState() => _MessageListAreaState();
}

class _MessageListAreaState extends State<MessageListArea>
    with WidgetsBindingObserver {
  final List<MessagePacket> _messages = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<MessagePacket>? _messagesSubscription;

  bool _isDuplicateMessage(MessagePacket message) {
    if (_messages.isEmpty) {
      return false;
    }

    final last = _messages.last;
    return last.sender.id == message.sender.id &&
        last.text == message.text &&
        last.timestamp == message.timestamp;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ensureRoomHistoryLoaded();

    _messagesSubscription = PneumaCore().messagesStream.listen((
      MessagePacket msg,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (!_isDuplicateMessage(msg) && msg.room.id == widget.room.room.id) {
          _messages.add(msg);
        }
      });
      _scrollToBottom();
    });
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    _scrollToBottom();
  }

  Future<void> _ensureRoomHistoryLoaded() async {
    final storageManager = StorageManager();
    final savedMessages = storageManager.getRoomMessages(widget.room.room.id);

    if (!mounted) {
      return;
    }

    setState(() {
      for (final msg in savedMessages) {
        if (!_isDuplicateMessage(msg)) {
          _messages.add(msg);
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
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messagesSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(10, 10, 10, 10 + bottomInset),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          final isMyMessage = msg.sender.id == PneumaCore().user.id;

          return MessageBubble(message: msg, isMe: isMyMessage);
        },
      ),
    );
  }
}

class InputArea extends StatefulWidget {
  final UiRoom room;

  const InputArea({super.key, required this.room});

  @override
  State<InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends State<InputArea> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
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
        PneumaCore().sendAndSaveMessage(widget.room, text);
      } finally {
        _isSending = false;
      }
    }
    _inputFocusNode.requestFocus();
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
          autofocus: true,
          controller: _inputController,
          textAlign: .left,
          focusNode: _inputFocusNode,
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
          Padding(padding: const EdgeInsets.only(left: 5.0)),
          Expanded(child: _buildInputField()),
          const SizedBox(width: 7.5),
          _buildInputEnterButton(),
          Padding(padding: const EdgeInsets.only(right: 5.0)),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final MessagePacket message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  List<Widget> _metadataBody(bool isMe, BuildContext context) {
    return [
      Text(
        formatTimestamp(message.timestamp.toInt()),
        style: TextStyle(
          fontSize: 12.0,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    ];
  }

  Widget _messageBody(BuildContext context) {
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        spacing: 7.5,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              message.sender.name,
              style: TextStyle(
                fontSize: 14.0,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SelectableText(message.text, style: const TextStyle(fontSize: 16.0)),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: _metadataBody(isMe, context),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
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
          child: _messageBody(context),
        ),
      ),
    );
  }
}
