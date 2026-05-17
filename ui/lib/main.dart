import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'daos.dart';
import 'login_page.dart';
import 'pneuma_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Запрашиваем разрешения только для Android и iOS
  if (Platform.isAndroid || Platform.isIOS) {
    await requestAppPermissions();
  }

  final daos = Daos();
  PneumaCore().init(daos: daos);

  runApp(Provider<Daos>.value(value: daos, child: const PneumaMeshApp()));
}

Future<void> requestAppPermissions() async {
  if (!Platform.isAndroid) return;

  final androidInfo = await DeviceInfoPlugin().androidInfo;
  final sdkInt = androidInfo.version.sdkInt;

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
      title: 'PneumaMesh',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(95, 255, 0, 0),
          brightness: Brightness.dark,
        ),
      ),
      initialRoute: '/',
      routes: {'/': (context) => LoginPage(title: 'PneumaMesh')},
    );
  }
}
