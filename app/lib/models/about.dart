class AboutInfo {
  const AboutInfo({
    required this.version,
    required this.latest,
    required this.updateAvailable,
    required this.reachable,
    required this.canUpdate,
    required this.phase,
    required this.message,
    required this.target,
  });

  final String version;
  final String? latest;
  final bool updateAvailable;
  final bool reachable;
  final bool canUpdate;

  /// idle、downloading、applying、failed。
  final String phase;
  final String? message;
  final String? target;

  factory AboutInfo.fromJson(Map<String, dynamic> json) {
    return AboutInfo(
      version: json['version'] as String,
      latest: json['latest'] as String?,
      updateAvailable: json['updateAvailable'] as bool? ?? false,
      reachable: json['reachable'] as bool? ?? false,
      canUpdate: json['canUpdate'] as bool? ?? false,
      phase: json['phase'] as String? ?? 'idle',
      message: json['message'] as String?,
      target: json['target'] as String?,
    );
  }
}
