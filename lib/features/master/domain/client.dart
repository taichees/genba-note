class Client {
  const Client({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory Client.fromMap(Map<String, Object?> map) {
    return Client(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }
}
