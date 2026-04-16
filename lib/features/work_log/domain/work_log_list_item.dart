import 'work_log_status.dart';

class WorkLogListItem {
  const WorkLogListItem({
    required this.id,
    required this.datetime,
    required this.status,
    this.latitude,
    this.longitude,
    this.propertyId,
    this.propertyName,
    this.clientId,
    this.clientName,
  });

  final int id;
  final DateTime datetime;
  final WorkLogStatus status;
  final double? latitude;
  final double? longitude;
  final int? propertyId;
  final String? propertyName;
  final int? clientId;
  final String? clientName;

  factory WorkLogListItem.fromMap(Map<String, Object?> map) {
    return WorkLogListItem(
      id: map['id'] as int,
      datetime: DateTime.parse(map['datetime'] as String),
      status: WorkLogStatus.fromValue(map['status'] as String),
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      propertyId: map['property_id'] as int?,
      propertyName: map['property_name'] as String?,
      clientId: map['client_id'] as int?,
      clientName: map['client_name'] as String?,
    );
  }
}
