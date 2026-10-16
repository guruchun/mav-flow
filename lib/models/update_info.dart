/// 앱 업데이트 정보를 담는 모델
///
/// GitHub Release API 응답을 파싱하여 최신 버전 정보를 관리합니다.
class UpdateInfo {
  /// 최신 버전 (예: "1.0.1")
  final String latestVersion;

  /// 현재 버전 (예: "1.0.0")
  final String currentVersion;

  /// 다운로드 URL (GitHub Release 페이지)
  final String downloadUrl;

  /// ZIP 파일 직접 다운로드 URL
  final String? zipDownloadUrl;

  /// 릴리즈 노트
  final String releaseNotes;

  /// 릴리즈 발행일
  final DateTime publishedAt;

  UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
    this.zipDownloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
  });

  /// 업데이트가 필요한지 여부 (semantic versioning 비교)
  bool get hasUpdate => _compareVersions(latestVersion, currentVersion) > 0;

  /// GitHub Release API 응답으로부터 UpdateInfo 생성
  ///
  /// [json]은 GitHub API /repos/{owner}/{repo}/releases/latest 응답입니다.
  /// [currentVersion]은 현재 앱 버전입니다.
  factory UpdateInfo.fromGitHubRelease(
    Map<String, dynamic> json,
    String currentVersion,
  ) {
    // tag_name에서 버전 추출 (v1.0.0 → 1.0.0)
    final tagName = json['tag_name'] as String? ?? '';
    final latestVersion = tagName.startsWith('v') 
        ? tagName.substring(1) 
        : tagName;

    // assets에서 Windows ZIP 파일 URL 찾기
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

  /// Semantic versioning 비교
  ///
  /// v1 > v2이면 양수, v1 < v2이면 음수, 같으면 0 반환
  static int _compareVersions(String v1, String v2) {
    // 'v' 접두사 제거
    final clean1 = v1.startsWith('v') ? v1.substring(1) : v1;
    final clean2 = v2.startsWith('v') ? v2.substring(1) : v2;

    final parts1 = clean1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = clean2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    // 3개 부분으로 맞춤 (major.minor.patch)
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
