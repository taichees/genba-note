class Property {
  const Property({
    required this.id,
    required this.name,
    this.clientId,
  });

  final int id;
  final String name;
  final int? clientId;

  factory Property.fromMap(Map<String, Object?> map) {
    return Property(
      id: map['id'] as int,
      name: map['name'] as String,
      clientId: map['client_id'] as int?,
    );
  }
}
