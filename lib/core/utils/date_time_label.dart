import 'package:intl/intl.dart';

extension DateTimeLabel on DateTime {
  String toShortLabel() {
    return DateFormat('yyyy/MM/dd HH:mm').format(this);
  }
}
