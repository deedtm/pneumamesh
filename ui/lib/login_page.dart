import 'dart:async';
import 'dart:math' as math;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'fgtask.dart';
import 'hive/storage_manager.dart';
import 'pneumacore.dart';
import 'sos_service.dart';
import 'ui_room.dart';
import 'update_checker.dart';

Future<void> _initForegroundTask() async {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'foreground_task',
      channelName: 'Foreground Task',
      channelDescription: 'PneumaMesh foreground task',
      onlyAlertOnce: true,
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  final androidInfo = await DeviceInfoPlugin().androidInfo;
  final sdkInt = androidInfo.version.sdkInt;
  final notificationText = sdkInt > 33
      ? '🫸 keeping mesh connection... 🫷'
      : '🫱 keeping mesh connection... 🫲';
  await FlutterForegroundTask.startService(
    callback: startCallback,
    notificationTitle: 'PneumaMesh is running',
    notificationText: notificationText,
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _nameController = TextEditingController();
  var _isCleaningUp = false;
  var _isLoggingIn = false;

  final List<String> _appBarFrames1 = ['• O •', '- O •', '- O -', '• O -'];
  final List<String> _appBarFrames2 = ['• O •', '• O -', '- O -', '- O •'];
  List<String> _appBarFrames = ['• O •'];
  int _appBarAnimationIndex = 0;

  Timer? _appBarAnimationTimer;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkForUpdates(context);
      if (mounted) {
        final lastLogin = StorageManager().getLastLogin();
        if (lastLogin != null) {
          _nameController.text = lastLogin;
          _login();
        }
      }
    });
    _appBarNextFrame();
  }

  void _appBarNextFrame() {
    int nextDelay;

    if (_appBarAnimationIndex == 0) {
      _appBarFrames = _random.nextBool() ? _appBarFrames1 : _appBarFrames2;
    }

    if (_appBarAnimationIndex == 0) {
      nextDelay = 1500 + _random.nextInt(2500);
    } else {
      nextDelay = 150 + _random.nextInt(250);
    }
    _appBarAnimationTimer = Timer(Duration(milliseconds: nextDelay), () {
      if (!mounted) return;

      setState(() {
        _appBarAnimationIndex =
            (_appBarAnimationIndex + 1) % _appBarFrames.length;
      });

      _appBarNextFrame();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _appBarAnimationTimer?.cancel();
    FlutterForegroundTask.stopService();
    super.dispose();
  }

  void _login() async {
    final username = _nameController.text.trim();
    if (username.isEmpty) return;

    setState(() => _isLoggingIn = true);

    final storageManager = StorageManager();

    Map? account = storageManager.getAccount(username);
    bool isNewUser = account == null;

    String privateKey;
    if (isNewUser) {
      privateKey = PneumaCore().generatePrivateKey();
    } else {
      privateKey = account['privateKey'];
    }

    await PneumaCore().initCore(privateKey, username);
    await PneumaCore().initUser();
    await PneumaCore().startBleDiscovery();

    String userId = PneumaCore().user.id;
    await storageManager.addAccount(username, privateKey, userId);
    await storageManager.setSession(userId);
    await storageManager.setLastLogin(username);

    List<UiRoom> savedRooms = storageManager.getAllRooms();
    await PneumaCore().initRooms(savedRooms);

    SosService().init();

    await _initForegroundTask();

    if (mounted) {
      Navigator.pushNamed(context, '/rooms').then((_) async {
        _isLoggingIn = false;
        setState(() => _isCleaningUp = true);

        await FlutterForegroundTask.stopService();

        PneumaCore().stopAll();
        SosService().dispose();
        await StorageManager().closeUserSession();

        await Future.delayed(const Duration(milliseconds: 1500));
        setState(() => _isCleaningUp = false);
      });
    }
  }

  Widget _usernameField() {
    return Container(
      width: 250,
      height: 60,
      alignment: Alignment.topCenter,
      padding: EdgeInsets.all(5.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSecondary,
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Center(
        child: TextField(
          controller: _nameController,
          autofocus: true,
          textAlign: TextAlign.center,
          maxLength: 16,
          onSubmitted: (value) => _login(),
          textInputAction: TextInputAction.send,
          decoration: InputDecoration(
            hintText: "Enter your username...",
            hintStyle: TextStyle(fontSize: 14.0),
            border: InputBorder.none,
            contentPadding: EdgeInsets.only(top: 10.0),
            isCollapsed: true,
            counterText: null,
          ),
        ),
      ),
    );
  }

  Widget _loginButton() {
    return ElevatedButton(
      onPressed: _login,
      style: ButtonStyle(
        padding: WidgetStatePropertyAll(EdgeInsetsGeometry.all(20)),
      ),
      child: Icon(Icons.login),
    );
  }

  Widget _bodyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: .center,
        spacing: 20.0,
        children: [
          Text.rich(
            textAlign: TextAlign.center,
            TextSpan(
              text: "Welcome to\n",
              style: TextStyle(fontSize: 25.0),
              children: [
                TextSpan(
                  text: "PneumaMesh!",
                  style: TextStyle(fontSize: 30.0, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          SizedBox(height: 30),
          _usernameField(),
          (_isCleaningUp || _isLoggingIn)
              ? Center(child: CircularProgressIndicator())
              : _loginButton(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75.0,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Center(child: Text(_appBarFrames[_appBarAnimationIndex])),
      ),
      body: _bodyWidget(),
    );
  }
}
