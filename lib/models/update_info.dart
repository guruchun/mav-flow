/// Model containing app update information
///
/// Parses GitHub Release API response to manage latest version info.
class UpdateInfo {
  /// Latest version (e.g., "1.0.1")
  final String latestVersion;

  /// Current version (e.g., "1.0.0")
  final String currentVersion;

  /// Download URL (GitHub Release page)
  final String downloadUrl;

  /// Direct ZIP file download URL
  final String? zipDownloadUrl;

  /// Release notes
  final String releaseNotes;

  /// Release publish date
  final DateTime publishedAt;

  UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
    this.zipDownloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
  });

  /// Whether an update is available (semantic versioning comparison)
  bool get hasUpdate => _compareVersions(latestVersion, currentVersion) > 0;

  /// Creates UpdateInfo from GitHub Release API response
  ///
  /// [json] is the GitHub API /repos/{owner}/{repo}/releases/latest response.
  /// [currentVersion] is the current app version.
  factory UpdateInfo.fromGitHubRelease(
    Map<String, dynamic> json,
    String currentVersion,
  ) {
    // Extract version from tag_name (v1.0.0 → 1.0.0)
    final tagName = json['tag_name'] as String? ?? '';
    final latestVersion = tagName.startsWith('v') 
        ? tagName.substring(1) 
        : tagName;

    // Find Windows ZIP file URL from assets
    String? zipUrl;
    final assets = json['assets'] as List<dynamic>?;
    if (assets != null) {
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.contains('windows') && name.endsWith('.zip')) {
          zipUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
    }

    return UpdateInfo(
      latestVersion: latestVersion,
      currentVersion: currentVersion,
      downloadUrl: json['html_url'] as String? ?? '',
      zipDownloadUrl: zipUrl,
      releaseNotes: json['body'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Semantic versioning comparison
  ///
  /// Returns positive if v1 > v2, negative if v1 < v2, 0 if equal
  static int _compareVersions(String v1, String v2) {
    // Remove 'v' prefix
    final clean1 = v1.startsWith('v') ? v1.substring(1) : v1;
    final clean2 = v2.startsWith('v') ? v2.substring(1) : v2;

    final parts1 = clean1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = clean2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    // Pad to 3 parts (major.minor.patch)
    while (parts1.length < 3) {
      parts1.add(0);
    }
    while (parts2.length < 3) {
      parts2.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (parts1[i] > parts2[i]) return 1;
      if (parts1[i] < parts2[i]) return -1;
    }

    return 0;
  }

  @override
  String toString() {
    return 'UpdateInfo(latest: $latestVersion, current: $currentVersion, hasUpdate: $hasUpdate)';
  }
}
