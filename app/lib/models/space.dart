class Space {
  Space({
    required this.id,
    required this.name,
    this.themeKey = 'mint',
    this.focusLimit = 3,
    this.focusCount = 0,
  });

  final String id;
  final String name;
  final String themeKey;
  final int focusLimit;
  final int focusCount;

  bool get focusFull => focusCount >= focusLimit;

  factory Space.fromJson(Map<String, dynamic> json) {
    return Space(
      id: json['id'] as String,
      name: json['name'] as String,
      themeKey: (json['themeKey'] as String?) ?? 'mint',
      focusLimit: (json['focusLimit'] as num?)?.toInt() ?? 3,
      focusCount: (json['focusCount'] as num?)?.toInt() ?? 0,
    );
  }
}
