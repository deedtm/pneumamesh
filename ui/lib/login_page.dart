import 'package:flutter/material.dart';
import 'package:pneumamesh/chats_page.dart';

import 'global_db.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkForUpdates(context);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _login() async {
    final username = _nameController.text.trim();
    if (username.isEmpty) return;

    final account = await GlobalDb.instance.getAccount(username);

    String privKey;

    if (account == null) {
      privKey = PneumaCore().generatePrivateKey();
      await GlobalDb.instance.createAccount(username, privKey);
    } else {
      privKey = account['private_key'] as String;
    }

    await PneumaCore().startNode(username, privKey);
    await PneumaCore().startBleDiscovery();
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatsPage(username: username)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75.0,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Center(child: Text(widget.title)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            Column(
              children: [
                Text(
                  "Welcome\nto\nPneumaMesh!",
                  style: TextStyle(fontSize: 25.0),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 50),
                Container(
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
                ),
              ],
            ),
            SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: _login,
              style: ButtonStyle(
                padding: WidgetStatePropertyAll(EdgeInsetsGeometry.all(20)),
              ),
              child: Icon(Icons.login),
            ),
          ],
        ),
      ),
    );
  }
}
