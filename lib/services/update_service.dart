import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/update_info.dart';

/// GitHub Release를 통한 업데이트 확인 서비스
///
/// 앱 자동 업데이트를 위해 GitHub API를 사용하여 최신 릴리즈 정보를 확인하고,
/// 다운로드 페이지를 열 수 있습니다.
class UpdateService {
  /// GitHub 저장소 소유자
  static const String owner = 'guruchun';

  /// GitHub 저장소 이름
  static const String repo = 'mav-flow';

  /// GitHub API URL
  static const String _apiUrl =
      'https://api.github.com/repos/$owner/$repo/releases/latest';

  UpdateService._();

  /// 최신 릴리즈 정보를 확인합니다.
  ///
  /// [currentVersion]은 현재 앱 버전입니다.
  /// 성공 시 [UpdateInfo]를 반환하고, 네트워크 오류나 API 오류 시 null을 반환합니다.
  static Future<UpdateInfo?> checkForUpdates(String currentVersion) async {
    try {
      final response = await http
          .get(
            Uri.parse(_apiUrl),
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'mav-flow-app',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return UpdateInfo.fromGitHubRelease(json, currentVersion);
      } else if (response.statusCode == 403) {
        // API rate limit 초과
        debugPrint('GitHub API rate limit exceeded');
        return null;
      } else if (response.statusCode == 404) {
        // 릴리즈 없음
        debugPrint('No releases found for $owner/$repo');
        return null;
      } else {
        debugPrint(
            'GitHub API returned status ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      // 네트워크 오류 (인터넷 연결 없음 등)
      debugPrint('Failed to check for updates: $e');
      return null;
    }
  }

  /// 다운로드 페이지를 기본 브라우저에서 엽니다.
  ///
  /// [url]은 GitHub Release 페이지 URL입니다.
  /// 성공 시 true, 실패 시 false를 반환합니다.
  static Future<bool> openDownloadPage(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        debugPrint('Cannot launch URL: $url');
        return false;
      }
    } catch (e) {
      debugPrint('Failed to open download page: $e');
      return false;
    }
  }
}
