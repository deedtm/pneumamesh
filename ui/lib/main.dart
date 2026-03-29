import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_multicast_lock/flutter_multicast_lock.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'login_page.dart';
import 'pneuma_core.dart';
import 'daos.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await FlutterMulticastLock().acquireMulticastLock();

  final daos = Daos();
  PneumaCore().init(daos: daos);
  runApp(Provider<Daos>.value(value: daos, child: const PneumaMeshApp()));
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
