import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:geolocator/geolocator.dart';

import 'geo.dart';
import 'hive/storage_manager.dart';
import 'pneumacore.dart';
import 'proto/pneumacore.pb.dart';
import 'sos_service.dart';
import 'ui_room.dart';
import 'utils.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  late List<UiRoom> _rooms;

  String _newRoomName = '';
  bool _isSos = false;

  Widget _sosButtonContent = const Icon(Icons.sos_outlined, size: 32.5);
  StreamSubscription<SosPacket>? _sosSubscription;

  @override
  void initState() {
    super.initState();

    _rooms = PneumaCore().rooms;
    PneumaCore().onRoomsUpdated = () {
      setState(() {
        _rooms = PneumaCore().rooms;
      });
    };

    PneumaCore().toUpdateLastMessage = (String roomId, MessagePacket message) {
      setState(() {
        final roomIndex = _rooms.indexWhere((room) => room.room.id == roomId);
        if (roomIndex != -1) {
          _rooms[roomIndex].lastMessage = message;
          if (PneumaCore().currentRoom?.room.id != roomId) {
            _rooms[roomIndex].unreadCount++;
          }
          StorageManager().updateRoom(_rooms[roomIndex]);
          _rooms.sort((a, b) {
            final aTime = a.lastMessage?.timestamp.toInt() ?? 0;
            final bTime = b.lastMessage?.timestamp.toInt() ?? 0;
            return bTime.compareTo(aTime);
          });
        }
      });
    };

    _sosSubscription = PneumaCore().sosStream.listen((packet) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBarBuilder(
          Text('SOS alert from ${packet.sender.name}'),
          const Duration(milliseconds: 1500),
        ),
      );
    });
  }

  @override
  void dispose() {
    _sosSubscription?.cancel();
    super.dispose();
  }

  SnackBar _snackBarBuilder(Text text, Duration duration) {
    return SnackBar(content: text, duration: duration);
  }

  void _sosToggle() async {
    setState(() {
      _isSos = !_isSos;
      _sosButtonContent = Transform.scale(
        scale: 0.6,
        child: const CircularProgressIndicator(),
      );
    });

    var wasError = false;
    var snackBarText = Text('The SOS mode is ${_isSos ? 'ON' : 'OFF'}');
    var snackBarDuration = const Duration(milliseconds: 750);

    if (_isSos) {
      try {
        Position position = await getLocation();
        PneumaCore().sendSos(position);
        SosService().startSendingSos();
      } catch (e) {
        wasError = true;
        snackBarDuration = const Duration(milliseconds: 1500);
        snackBarText = switch (e) {
          GeoException() => Text(e.message),
          TimeoutException() => Text('Failed to get location: Timeout'),
          _ => Text('Failed to get location: $e'),
        };
      }
    } else {
      SosService().stopSendingSos();
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(_snackBarBuilder(snackBarText, snackBarDuration));
    }
    setState(() {
      if (wasError) _isSos = false;
      _sosButtonContent = const Icon(Icons.sos, size: 32.5);
    });
  }

  void _sosButtonCallback() {
    if (_isSos) {
      _sosToggle();
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('SOS mode'),
          content: const Text(
            'Are you sure you want to activate the SOS mode? This will alert nearby users and will share your location.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _sosToggle();
              },
              child: const Text('Activate'),
            ),
          ],
        );
      },
    );
  }

  void _backHandler(bool didPop, Object? result) async {
    if (didPop) return;
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _roomTile(UiRoom room) {
    Text title;
    Text subtitle;

    if (!room.isMuted) {
      title = Text(
        room.room.name,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      title = Text.rich(
        TextSpan(
          children: [
            WidgetSpan(child: Icon(Icons.volume_off, size: 20.0)),
            WidgetSpan(child: SizedBox(width: 5.0)),
            TextSpan(
              text: room.room.name,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (room.lastMessage == null) {
      subtitle = Text(
        "No messages yet",
        style: TextStyle(fontStyle: FontStyle.italic, fontSize: 15.0),
      );
    } else {
      MessagePacket lm = room.lastMessage!;
      subtitle = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: formatTimestamp(lm.timestamp.toInt()),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(70),
              ),
            ),
            WidgetSpan(child: SizedBox(width: 5.0)),
            TextSpan(
              text: "${lm.sender.name}:",
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
            ),
            WidgetSpan(child: SizedBox(width: 5.0)),
            TextSpan(
              text: lm.text,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15.0),
      );
    }
    var trailing = room.unreadCount == 0
        ? null
        : CircleAvatar(
            radius: 12.0,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              room.unreadCount.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 12.0,
              ),
            ),
          );

    return ListTile(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: () {
        if (!_rooms.contains(room)) {
          setState(() {
            _rooms.remove(room);
          });
          return;
        }

        Navigator.pushNamed(context, '/room', arguments: room);
      },
    );
  }

  void _removeRoom(BuildContext context, int index) {
    StorageManager().deleteRoom(_rooms[index]);
    setState(() {
      _rooms.removeAt(index);
    });
  }

  Widget _roomList() {
    return ListView.builder(
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        var room = _rooms[index];

        return Slidable(
          key: Key(room.room.name),

          startActionPane: ActionPane(
            extentRatio: 0.25,
            motion: const BehindMotion(),

            children: [
              CustomSlidableAction(
                onPressed: (context) => setState(() {
                  room.isMuted = !room.isMuted;
                  StorageManager().updateRoom(room);
                }),
                backgroundColor: room.isMuted ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
                child: Icon(
                  room.isMuted ? Icons.volume_up : Icons.volume_off,
                  size: 30.0,
                ),
              ),
            ],
          ),

          endActionPane: ActionPane(
            extentRatio: 0.25,
            motion: const DrawerMotion(),

            dismissible: DismissiblePane(
              onDismissed: () => _removeRoom(context, index),
              confirmDismiss: () async {
                return true;
              },
            ),

            children: [
              CustomSlidableAction(
                onPressed: (context) => _removeRoom(context, index),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                child: Icon(Icons.delete, size: 30.0),
              ),
            ],
          ),

          child: _roomTile(room),
        );
      },
    );
  }

  void _addRoom(String name) {
    final room = PneumaCore().createRoom(name);

    StorageManager().addRoom(UiRoom(room: room));
    setState(() {
      _rooms.add(UiRoom(room: room));
    });
  }

  void _addRoomHandler() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Room'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter room name...'),
            onChanged: (value) {
              setState(() {
                _newRoomName = value;
              });
            },
            onSubmitted: (value) {
              if (value.trim().isEmpty) return;
              _addRoom(value);
              Navigator.of(context).pop();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                if (_newRoomName.trim().isEmpty) return;
                _addRoom(_newRoomName);
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
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
            PneumaCore().user.name,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(opacity: 0.9),
          actionsIconTheme: const IconThemeData(opacity: 0.9),
          centerTitle: true,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () {
              _backHandler(false, null);
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Recent SOS signals',
              onPressed: () {
                Navigator.pushNamed(context, '/sos');
              },
              icon: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sensors, size: 32.5),
                  Icon(Icons.arrow_forward_ios, size: 20.0),
                ],
              ),
            ),
          ],
        ),
        body: _roomList(),
        floatingActionButtonLocation: .centerFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FloatingActionButton(
                tooltip: 'Switch SOS mode',
                heroTag: 'rooms-page-sos-fab',
                onPressed: _sosButtonCallback,
                backgroundColor: _isSos
                    ? Colors.lightGreenAccent.withAlpha(150)
                    : Theme.of(context).colorScheme.primaryContainer,
                child: _sosButtonContent,
              ),
              FloatingActionButton(
                tooltip: 'Create room',
                heroTag: 'rooms-page-add-room-fab',
                onPressed: _addRoomHandler,
                child: const Icon(Icons.group_add_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
