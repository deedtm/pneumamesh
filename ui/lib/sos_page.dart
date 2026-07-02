import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import 'geo.dart';
import 'notification_service.dart';
import 'pneumacore.dart';
import 'proto/pneumacore.pb.dart';
import 'sos_service.dart';
import 'utils.dart';

class SosPage extends StatefulWidget {
  const SosPage({super.key});

  @override
  State<SosPage> createState() => _SosPageState();
}

// TODO: прокидывание rssi из котлина во флаттер, чтобы помогать определять местоположение сос-сигнала (горячо-холодно)
// !форматирование текста во flutter!

class _SosPageState extends State<SosPage> {
  @override
  void initState() {
    super.initState();
    NotificationService().clearSosCache();
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
            'Recent SOS',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(opacity: 0.9),
          actionsIconTheme: const IconThemeData(opacity: 0.9),
          leading: IconButton(
            tooltip: 'Back',
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
              children: [Expanded(child: SosListArea())],
            ),
          ),
        ),
      ),
    );
  }
}

class SosListArea extends StatefulWidget {
  const SosListArea({super.key});

  @override
  State<SosListArea> createState() => _SosListAreaState();
}

class _SosListAreaState extends State<SosListArea> {
  List<SosPacket> _sosPackets = [];
  StreamSubscription<SosPacket>? _sosSubscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        MyGeoService().startTracking();
      }
    });

    PneumaCore().blockSosNotifications = true;

    _sosPackets = SosService().sosPackets;
    SosService().onSosUpdate = () {
      setState(() {
        _sosPackets = SosService().sosPackets;
      });
    };

    _sosSubscription = PneumaCore().sosStream.listen((SosPacket sosPacket) {
      setState(() {
        _sosPackets = SosService().sosPackets;
      });
    });
  }

  @override
  void dispose() {
    _sosSubscription?.cancel();
    PneumaCore().blockSosNotifications = false;
    MyGeoService().stopTracking();
    SosService().onSosUpdate = null;
    super.dispose();
  }

  Widget _leadingWidget(bool isTracking, double bearing) {
    if (!isTracking) {
      return const Icon(
        Icons.warning_amber_rounded,
        color: Colors.red,
        size: 35,
      );
    }
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('Compass error!');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
            size: 35,
          );
        }
        double heading = snapshot.data?.heading ?? 0;
        double direction = (bearing - heading) * (math.pi / 180);

        return Transform.rotate(
          angle: direction,
          child: Icon(
            Icons.navigation_outlined,
            size: 35,
            color: Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }

  Widget _subtitleWidget(double distance, GeoStatus status, Position? myPos) {
    if (status == GeoStatus.disabled) {
      return Text('Turn on location services');
    }
    if (status == GeoStatus.denied || status == GeoStatus.deniedForever) {
      return Text('Location permissions are denied');
    }
    if (status == GeoStatus.loading || myPos == null) {
      return Text('Calculating distance...');
    }

    return Text('${distance.toStringAsFixed(1)}m away');
  }

  Widget _sosPacketsList(GeoStatus status, Position? myPos) {
    return ListView.builder(
      itemCount: _sosPackets.length,
      itemBuilder: (context, index) {
        SosPacket packet = _sosPackets[index];
        User user = packet.sender;
        PositionInfo pos = packet.position;

        bool isTracking = (status == GeoStatus.tracking && myPos != null);

        final (distance, bearing) = (isTracking)
            ? getDistanceAndBearing(myPos, pos)
            : (double.negativeInfinity, double.negativeInfinity);

        return ExpansionTile(
          leading: _leadingWidget(isTracking, bearing),
          title: Text(
            user.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: _subtitleWidget(distance, status, myPos),
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text:
                          'Coordinates: ${pos.lat}, ${pos.lon}, ${pos.alt}\n'
                          'Accuracy: ${pos.acc}m\n'
                          'Speed: ${pos.spd}m/s\n'
                          'Last update: ${pos.prettyTime}\n',
                    ),
                  ],
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GeoStatus>(
      valueListenable: MyGeoService().status,
      builder: (context, status, child) {
        return ValueListenableBuilder<Position?>(
          valueListenable: MyGeoService().currentPosition,
          builder: (context, myPos, child) {
            return Column(
              children: [
                Text(
                  "Your position accuracy: ${myPos?.accuracy.toStringAsFixed(1) ?? 'N/A'} m (last update: ${myPos != null ? formatTimestamp(myPos.timestamp.millisecondsSinceEpoch ~/ 1000, format: 'HH:mm:ss') : 'N/A'})",
                  // style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                Expanded(child: _sosPacketsList(status, myPos)),
              ],
            );
          },
        );
      },
    );
  }
}
