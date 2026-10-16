import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

import '../models/update_info.dart';

/// 다운로드 진행 상황 콜백
typedef DownloadProgressCallback = void Function(int received, int total);

/// GitHub Release를 통한 업데이트 확인 서비스
///
/// 앱 자동 업데이트를 위해 GitHub API를 사용하여 최신 릴리즈 정보를 확인하고,
/// 다운로드 및 업데이트를 수행합니다.
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

  /// ZIP 파일을 다운로드합니다.
  ///
  /// [updateInfo]에서 다운로드 URL을 가져옵니다.
  /// [onProgress] 콜백으로 진행 상황을 전달합니다.
  /// 성공 시 다운로드된 파일 경로를 반환합니다.
  static Future<String?> downloadUpdate(
    UpdateInfo updateInfo, {
    DownloadProgressCallback? onProgress,
  }) async {
    try {
      // ZIP 다운로드 URL 가져오기
      final zipUrl = updateInfo.zipDownloadUrl;
      if (zipUrl == null) {
        debugPrint('No ZIP download URL available');
        return null;
      }

      // 임시 디렉토리에 저장
      final tempDir = Directory.systemTemp;
      final fileName = 'mav-flow-${updateInfo.latestVersion}-windows-x64.zip';
      final filePath = path.join(tempDir.path, fileName);
      final file = File(filePath);

      // HTTP 스트림으로 다운로드
      final request = http.Request('GET', Uri.parse(zipUrl));
      request.headers['User-Agent'] = 'mav-flow-app';

      final client = http.Client();
      try {
        final response = await client.send(request);

        if (response.statusCode != 200) {
          debugPrint('Download failed with status ${response.statusCode}');
          return null;
        }

        final contentLength = response.contentLength ?? 0;
        int received = 0;

        final sink = file.openWrite();
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, contentLength);
        }
        await sink.close();

        debugPrint('Downloaded to: $filePath');
        return filePath;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Failed to download update: $e');
      return null;
    }
  }

  /// 다운로드된 업데이트를 설치합니다.
  ///
  /// 업데이트 스크립트를 생성하고 실행합니다.
  /// 앱이 종료된 후 새 버전으로 교체됩니다.
  static Future<bool> installUpdate(String zipPath) async {
    try {
      final appDir = Directory.current.path;
      final updateScript = path.join(Directory.systemTemp.path, 'mav-flow-update.bat');

      // 업데이트 배치 스크립트 생성
      final script = '''
@echo off
echo MAV-Flow 업데이트 중...
timeout /t 2 /nobreak > nul

:: 기존 파일 백업 (선택사항)
:: move "$appDir" "$appDir.backup"

:: ZIP 압축 해제 (PowerShell 사용)
powershell -Command "Expand-Archive -Path '$zipPath' -DestinationPath '$appDir' -Force"

:: 임시 파일 정리
del "$zipPath"
del "%~f0"

:: 앱 재시작
start "" "$appDir\\mav-flow.exe"
''';

      await File(updateScript).writeAsString(script);

      // 스크립트 실행 (앱 종료 후 실행됨)
      await Process.start(
        'cmd',
        ['/c', updateScript],
        mode: ProcessStartMode.detached,
        runInShell: true,
      );

      return true;
    } catch (e) {
      debugPrint('Failed to install update: $e');
      return false;
    }
  }
}
