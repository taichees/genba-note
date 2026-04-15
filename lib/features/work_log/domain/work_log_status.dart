import '../../../core/constants/app_strings.dart';

enum WorkLogStatus {
  unsorted('unsorted'),
  completed('completed');

  const WorkLogStatus(this.value);

  final String value;

  String get label {
    switch (this) {
      case WorkLogStatus.unsorted:
        return AppStrings.statusUnsorted;
      case WorkLogStatus.completed:
        return AppStrings.statusCompleted;
    }
  }

  static WorkLogStatus fromValue(String value) {
    return WorkLogStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => WorkLogStatus.unsorted,
    );
  }
}
