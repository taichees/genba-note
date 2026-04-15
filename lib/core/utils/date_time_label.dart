extension DateTimeLabel on DateTime {
  String toShortLabel() {
    final month = this.month.toString().padLeft(2, '0');
    final day = this.day.toString().padLeft(2, '0');
    final hour = this.hour.toString().padLeft(2, '0');
    final minute = this.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }
}
