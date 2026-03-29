import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const updateManifestUrl =
    'https://raw.githubusercontent.com/deedtm/pneumamesh/main/update.json';

Future<void> checkForUpdates(BuildContext context) async {
  try {
    final response = await http.get(Uri.parse(updateManifestUrl));
    if (response.statusCode != 200) return;

    final data = json.decode(response.body);
    final String latestVersion = data['version'] ?? '1.0.0';
    final String url = data['url'] ?? '';
    final String changelog = data['changelog'] ?? 'New version available.';

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (_isNewerVersion(currentVersion, latestVersion)) {
      if (context.mounted) {
        _showUpdateDialog(context, latestVersion, changelog, url);
      }
    }
  } catch (e) {
    debugPrint('Error checking for updates: $e');
  }
}

bool _isNewerVersion(String current, String latest) {
  try {
    final currentParts = current.split('.');
    final latestParts = latest.split('.');

    for (var i = 0; i < currentParts.length && i < latestParts.length; i++) {
      final cLine = int.tryParse(currentParts[i]) ?? 0;
      final lLine = int.tryParse(latestParts[i]) ?? 0;
      if (lLine > cLine) return true;
      if (lLine < cLine) return false;
    }
    return latestParts.length > currentParts.length;
  } catch (e) {
    return false;
  }
}

void _showUpdateDialog(
  BuildContext context,
  String version,
  String changelog,
  String url,
) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Update available: v$version'),
      content: SingleChildScrollView(child: Text(changelog)),
      actionsAlignment: MainAxisAlignment.end,
      actionsOverflowButtonSpacing: 8.0,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        if (url.isNotEmpty)
          ElevatedButton(
            onPressed: () => launchUrl(Uri.parse(url)),
            child: const Text('Download'),
          ),
      ],
    ),
  );
}
