import 'work_log_status.dart';

class WorkLog {
  const WorkLog({
    required this.id,
    required this.datetime,
    this.latitude,
    this.longitude,
    this.propertyId,
    this.clientId,
    this.memo,
    required this.status,
  });

  final int id;
  final DateTime datetime;
  final double? latitude;
  final double? longitude;
  final int? propertyId;
  final int? clientId;
  final String? memo;
  final WorkLogStatus status;

  factory WorkLog.fromMap(Map<String, Object?> map) {
    return WorkLog(
      id: map['id'] as int,
      datetime: DateTime.parse(map['datetime'] as String),
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      propertyId: map['property_id'] as int?,
      clientId: map['client_id'] as int?,
      memo: map['memo'] as String?,
      status: WorkLogStatus.fromValue(map['status'] as String),
    );
  }
}
