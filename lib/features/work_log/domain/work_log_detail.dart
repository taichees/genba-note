import 'work_log.dart';

class WorkLogDetail {
  const WorkLogDetail({
    required this.workLog,
    this.propertyName,
    this.clientName,
  });

  final WorkLog workLog;
  final String? propertyName;
  final String? clientName;
}
