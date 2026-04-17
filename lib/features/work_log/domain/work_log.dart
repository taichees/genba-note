import 'work_log_status.dart';
import 'rough_address_status.dart';

class WorkLog {
  const WorkLog({
    required this.id,
    required this.datetime,
    this.latitude,
    this.longitude,
    this.roughAddress,
    required this.roughAddressStatus,
    this.roughAddressUpdatedAt,
    this.propertyId,
    this.clientId,
    this.memo,
    required this.status,
  });

  final int id;
  final DateTime datetime;
  final double? latitude;
  final double? longitude;
  final String? roughAddress;
  final RoughAddressStatus roughAddressStatus;
  final DateTime? roughAddressUpdatedAt;
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
      roughAddress: map['rough_address'] as String?,
      roughAddressStatus: RoughAddressStatus.fromValue(
        map['rough_address_status'] as String?,
      ),
      roughAddressUpdatedAt: map['rough_address_updated_at'] == null
          ? null
          : DateTime.parse(map['rough_address_updated_at'] as String),
      propertyId: map['property_id'] as int?,
      clientId: map['client_id'] as int?,
      memo: map['memo'] as String?,
      status: WorkLogStatus.fromValue(map['status'] as String),
    );
  }
}
