class AppUpdateInfo {
  final bool updateAvailable;
  final bool isMandatory;
  final int currentBuild;
  final String currentVersion;
  final int latestBuild;
  final String latestVersion;
  final int minSupportedBuild;
  final String title;
  final String? releaseNotes;
  final int fileSize;
  final String formattedSize;
  final String? sha256Checksum;
  final String? downloadUrl;
  final String? publishedAt;
  final String? message;

  const AppUpdateInfo({
    required this.updateAvailable,
    this.isMandatory = false,
    required this.currentBuild,
    this.currentVersion = '',
    this.latestBuild = 0,
    this.latestVersion = '',
    this.minSupportedBuild = 0,
    this.title = 'Update Aplikasi Tersedia',
    this.releaseNotes,
    this.fileSize = 0,
    this.formattedSize = '',
    this.sha256Checksum,
    this.downloadUrl,
    this.publishedAt,
    this.message,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final bool available = (json['update_available'] as bool?) ??
        (json['has_update'] as bool?) ??
        false;
    final int size = (json['file_size'] as num?)?.toInt() ?? 0;
    String formatted = json['formatted_size'] as String? ?? '';
    if (formatted.isEmpty && size > 0) {
      formatted = '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    return AppUpdateInfo(
      updateAvailable: available,
      isMandatory: json['is_mandatory'] as bool? ?? false,
      currentBuild: (json['current_build'] as num?)?.toInt() ?? 0,
      currentVersion: json['current_version'] as String? ?? '',
      latestBuild: (json['latest_build'] as num?)?.toInt() ?? 0,
      latestVersion: json['latest_version'] as String? ?? '',
      minSupportedBuild: (json['min_supported_build'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ??
          ((json['is_mandatory'] as bool? ?? false)
              ? 'Update Aplikasi Wajib'
              : 'Update Aplikasi Tersedia'),
      releaseNotes: json['release_notes'] as String?,
      fileSize: size,
      formattedSize: formatted,
      sha256Checksum: (json['sha256_checksum'] ?? json['checksum_sha256']) as String?,
      downloadUrl: json['download_url'] as String?,
      publishedAt: json['published_at'] as String?,
      message: json['message'] as String?,
    );
  }
}
