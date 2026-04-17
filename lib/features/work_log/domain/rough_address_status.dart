enum RoughAddressStatus {
  pending('pending'),
  success('success'),
  failed('failed'),
  none('');

  const RoughAddressStatus(this.value);

  final String value;

  static RoughAddressStatus fromValue(String? value) {
    for (final status in values) {
      if (status.value == value) {
        return status;
      }
    }
    return RoughAddressStatus.none;
  }
}
