import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

import '../models/update_info.dart';

/// Download progress callback
typedef DownloadProgressCallback = void Function(int received, int total);

/// Update checking service via GitHub Releases
///
/// Uses GitHub API to check latest release information for app auto-update,
/// and performs download and update operations.
class UpdateService {
  /// GitHub repository owner
  static const String owner = 'guruchun';

  /// GitHub repository name
  static const String repo = 'mav-flow';

  /// GitHub API URL
  static const String _apiUrl =
      'https://api.github.com/repos/$owner/$repo/releases/latest';

  UpdateService._();

  /// Checks for the latest release information.
  ///
  /// [currentVersion] is the current app version.
  /// Returns [UpdateInfo] on success, or null on network/API errors.
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
        // API rate limit exceeded
        debugPrint('GitHub API rate limit exceeded');
        return null;
      } else if (response.statusCode == 404) {
        // No releases found
        debugPrint('No releases found for $owner/$repo');
        return null;
      } else {
        debugPrint(
            'GitHub API returned status ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      // Network error (no internet connection, etc.)
      debugPrint('Failed to check for updates: $e');
      return null;
    }
  }

  /// Opens the download page in the default browser.
  ///
  /// [url] is the GitHub Release page URL.
  /// Returns true on success, false on failure.
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

  /// Downloads the ZIP file.
  ///
  /// Gets the download URL from [updateInfo].
  /// Progress is reported via [onProgress] callback.
  /// Returns the downloaded file path on success.
  static Future<String?> downloadUpdate(
    UpdateInfo updateInfo, {
    DownloadProgressCallback? onProgress,
  }) async {
    try {
      // Get ZIP download URL
      final zipUrl = updateInfo.zipDownloadUrl;
      if (zipUrl == null) {
        debugPrint('No ZIP download URL available');
        return null;
      }

      // Save to temp directory
      final tempDir = Directory.systemTemp;
      final fileName = 'mav-flow-${updateInfo.latestVersion}-windows-x64.zip';
      final filePath = path.join(tempDir.path, fileName);
      final file = File(filePath);

      // Download via HTTP stream
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

  /// Installs the downloaded update.
  ///
  /// Creates and runs an update script.
  /// The app will be replaced with the new version after exit.
  static Future<bool> installUpdate(String zipPath) async {
    try {
      final appDir = Directory.current.path;
      final updateScript = path.join(Directory.systemTemp.path, 'mav-flow-update.bat');

      // Create update batch script
      final script = '''
@echo off
echo Updating MAV-Flow...
timeout /t 2 /nobreak > nul

:: Backup existing files (optional)
:: move "$appDir" "$appDir.backup"

:: Extract ZIP (using PowerShell)
powershell -Command "Expand-Archive -Path '$zipPath' -DestinationPath '$appDir' -Force"

:: Clean up temp files
del "$zipPath"
del "%~f0"

:: Restart app
start "" "$appDir\\mav-flow.exe"
''';

      await File(updateScript).writeAsString(script);

      // Run script (executes after app exits)
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
