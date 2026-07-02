import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'hive/storage_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final Map<String, List<String>> _messagesCache = {};
  final Map<String, List<String>> _sosCache = {};

  Future<void> init() async {
    // Иконка для Android (должна лежать в android/app/src/main/res/drawable)
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notificationsPlugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    final String payload = response.payload ?? '';
    if (payload.startsWith('msg:')) {
      final String roomId = payload.split(':')[1];
      navigatorKey.currentState?.pushNamed(
        '/room',
        arguments: StorageManager().getRoomById(roomId),
      );
    } else if (payload == 'sos') {
      navigatorKey.currentState?.pushNamed('/sos');
    }
  }

  Future<void> sosNotification({
    required String userId,
    required String body,
  }) async {
    updateCache(_sosCache, "sos", body, 5, addToEnd: false);
    await _inboxNotification(
      cache: _sosCache['sos'] ?? [],
      maxNotificationsCount: 5,
      title: "⚠️ SOS",
      channelId: 'sos',
      channelName: 'Sos',
      notificationId: "sos".hashCode,
      body: body,
      payload: "sos",
    );
  }

  Future<void> messageNotification({
    required String roomId,
    required String roomName,
    required String body,
  }) async {
    updateCache(_messagesCache, roomId, body, 5);
    await _inboxNotification(
      cache: _messagesCache[roomId] ?? [],
      maxNotificationsCount: 5,
      title: roomName,
      channelId: 'messages',
      channelName: 'Messages',
      notificationId: roomId.hashCode,
      body: body,
      payload: "msg:$roomId",
    );
  }

  void updateCache(
    Map<String, List<String>> cache,
    String cacheKey,
    String body,
    int maxNotificationsCount, {
    bool addToEnd = true,
  }) {
    if (!cache.containsKey(cacheKey)) cache[cacheKey] = [];
    bool isCacheFull = cache[cacheKey]!.length >= maxNotificationsCount;
    if (addToEnd) {
      cache[cacheKey]!.add(body);
      if (isCacheFull) cache[cacheKey]!.removeAt(0);
    } else {
      cache[cacheKey]!.insert(0, body);
      if (isCacheFull) cache[cacheKey]!.removeLast();
    }
  }

  Future<void> _inboxNotification({
    required List<String> cache,
    required int maxNotificationsCount,
    required String title,
    required String channelId,
    required String channelName,
    required int notificationId,
    required String body,
    required String payload,
  }) async {
    final InboxStyleInformation inboxStyle = InboxStyleInformation(
      cache,
      contentTitle: title,
      summaryText: 'Unread: ${cache.length}',
    );

    final AndroidNotificationDetails details = AndroidNotificationDetails(
      channelId,
      channelName,
      styleInformation: inboxStyle,
      importance: Importance.high,
      priority: Priority.high,
    );
    await _notificationsPlugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: details),
      payload: payload,
    );
  }

  void clearMessagesCache(String roomId) {
    _messagesCache.remove(roomId);
    _notificationsPlugin.cancel(id: roomId.hashCode);
  }

  void clearSosCache() {
    _sosCache.clear();
    _notificationsPlugin.cancel(id: "sos".hashCode);
  }
}
