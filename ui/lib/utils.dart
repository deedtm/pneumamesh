import 'proto/pneumacore.pb.dart';
import 'package:intl/intl.dart';

String formatTimestamp(int timestampInSeconds, {String format = 'HH:mm'}) {
  DateTime date = DateTime.fromMillisecondsSinceEpoch(timestampInSeconds * 1000);
  return DateFormat(format).format(date);
}

extension PrettyPositionExt on PositionInfo {
  String get lat => latitude.toStringAsFixed(6);
  String get lon => longitude.toStringAsFixed(6);
  String get alt => altitude.toStringAsFixed(3);
  String get acc => accuracy.toStringAsFixed(1);
  String get spd => speed.toStringAsFixed(1);
  String get prettyTime => formatTimestamp(timestamp.toInt() ~/ 1000, format: 'HH:mm:ss');
}