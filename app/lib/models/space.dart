class Space {
  Space({
    required this.id,
    required this.name,
    this.themeKey = 'mint',
  });

  final String id;
  final String name;
  final String themeKey;

  factory Space.fromJson(Map<String, dynamic> json) {
    return Space(
      id: json['id'] as String,
      name: json['name'] as String,
      themeKey: (json['themeKey'] as String?) ?? 'mint',
    );
  }
}
