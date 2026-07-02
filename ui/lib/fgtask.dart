import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'logger.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(PneumaCoreTaskHandler());
}

class PneumaCoreTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    log.i('Foreground service started');
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    log.i('Foreground service destroyed');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      FlutterForegroundTask.stopService();
    }
  }
}
