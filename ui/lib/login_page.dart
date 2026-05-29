import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pneumamesh/chats_page.dart';

import 'get_it.dart';
import 'hive/storage_manager.dart';
import 'pneuma_core.dart';
import 'update_checker.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.title});

  final String title;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _nameController = TextEditingController();
  var _isCleaningUp = false;

  final List<String> _appBarFrames1 = ['• , •', '- , •', '- , -', '• , -'];
  final List<String> _appBarFrames2 = ['• , •', '• , -', '- , -', '- , •'];
  List<String> _appBarFrames = ['• , •'];
  int _appBarAnimationIndex = 0;

  Timer? _appBarAnimationTimer;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkForUpdates(context);
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
    super.dispose();
  }

  void _login() async {
    final username = _nameController.text.trim();
    if (username.isEmpty) return;

    final storageManager = getIt<StorageManager>();

    Map? account = storageManager.getAccount(username);
    bool isNewUser = account == null;

    String privateKey;
    if (isNewUser) {
      privateKey = PneumaCore().generatePrivateKey();
    } else {
      privateKey = account['privateKey'];
    }

    await PneumaCore().startNode(username, privateKey);
    await PneumaCore().startBleDiscovery();

    String userId = PneumaCore().getMyID();
    storageManager.addAccount(username, privateKey, userId);
    storageManager.setSession(userId);

    if (mounted) {
      final route = MaterialPageRoute(
        builder: (context) => ChatsPage(username: username),
      );

      Navigator.push(context, route).then((_) async {
        setState(() => _isCleaningUp = true);

        PneumaCore().stopNode();
        PneumaCore().stopStatePolling();
        PneumaCore().stopBleDiscovery();

        await Future.delayed(const Duration(seconds: 1));

        getIt<StorageManager>().closeUserSession();
        setState(() => _isCleaningUp = false);
      });
    }
  }

  void _loginAsMuwa() async {
    _nameController.text = 'muwa';
    _login();
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

  Widget _loginAsMuwaButton() {
    return ElevatedButton.icon(
      onPressed: _loginAsMuwa,
      style: ButtonStyle(
        padding: WidgetStatePropertyAll(EdgeInsetsGeometry.all(20)),
      ),
      icon: Icon(Icons.accessible_forward),
      label: Text("muwa"),
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
          // _loginAsMuwaButton(),
          _isCleaningUp
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
