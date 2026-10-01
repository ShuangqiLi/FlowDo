class Space {
  Space({required this.id, required this.name});

  final String id;
  final String name;

  factory Space.fromJson(Map<String, dynamic> json) {
    return Space(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}
