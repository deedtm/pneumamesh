import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'geo.dart';
import 'logger.dart';
import 'pneumacore.dart';
import 'proto/pneumacore.pb.dart';

class SosService {
  static final SosService _instance = SosService._internal();
  factory SosService() => _instance;
  SosService._internal();

  Timer? _removalTimer;
  Timer? _sosSendingTimer;

  Function? onSosUpdate;

  final List<SosPacket> _sosPackets = [];
  List<SosPacket> get sosPackets => List.unmodifiable(_sosPackets);

  void init() {
    _removalTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      int lengthBefore = _sosPackets.length;
      _sosPackets.removeWhere((packet) {
        final now = DateTime.now().toUtc();
        final packetTime = DateTime.fromMillisecondsSinceEpoch(
          packet.position.timestamp.toInt(),
        );
        return now.difference(packetTime).inMinutes >= 5;
      });
      if (lengthBefore > _sosPackets.length && onSosUpdate != null) {
        onSosUpdate!();
      }
    });
  }

  void dispose() {
    _removalTimer?.cancel();
    _sosSendingTimer?.cancel();
  }

  void addPacket(SosPacket sosPacket) {
    _sosPackets.removeWhere(
      (packet) => packet.sender.id == sosPacket.sender.id,
    );
    _sosPackets.insert(0, sosPacket);
  }

  void startSendingSos() {
    _sosSendingTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      try {
        Position position = await getLocation();
        PneumaCore().sendSos(position);
      } catch (e) {
        log.e('Failed to send SOS packet: $e');
      }
    });
  }

  void stopSendingSos() {
    _sosSendingTimer?.cancel();
  }
}
