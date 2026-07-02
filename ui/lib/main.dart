import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

import 'hive/storage_manager.dart';
import 'login_page.dart';
import 'notification_service.dart';
import 'pneumacore.dart';
import 'room_page.dart';
import 'rooms_page.dart';
import 'sos_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await requestAppPermissions();

  await StorageManager().init();
  await NotificationService().init();
  PneumaCore().init();
  FlutterForegroundTask.initCommunicationPort();

  if (await FlutterForegroundTask.isRunningService) {
    FlutterForegroundTask.stopService();
  }

  runApp(const PneumaMeshApp());
}

Future<void> requestAppPermissions() async {
  final androidInfo = await DeviceInfoPlugin().androidInfo;
  final sdkInt = androidInfo.version.sdkInt;

  final NotificationPermission notificationPermission =
      await FlutterForegroundTask.checkNotificationPermission();
  if (notificationPermission != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }
  if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
    await FlutterForegroundTask.requestIgnoreBatteryOptimization();
  }
  // if (!await FlutterForegroundTask.canScheduleExactAlarms) {
  //   await FlutterForegroundTask.openAlarmsAndRemindersSettings();
  // }

  if (sdkInt >= 33) {
    // android >13
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();
  } else if (sdkInt >= 31) {
    // android 12
    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();
  } else {
    // android <11
    await [Permission.location].request();
  }
}

class PneumaMeshApp extends StatelessWidget {
  const PneumaMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'PneumaMesh',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(212, 204, 0, 0),
          brightness: Brightness.dark,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(),
        '/rooms': (context) => RoomsPage(),
        '/room': (context) => RoomPage(),
        '/sos': (context) => SosPage(),
      },
    );
  }
}
