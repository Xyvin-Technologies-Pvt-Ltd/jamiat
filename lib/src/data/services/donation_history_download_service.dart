import 'dart:io';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

enum DonationHistoryDownloadStatus { success, cancelled, failed }

class DonationHistoryDownloadResult {
  const DonationHistoryDownloadResult({
    required this.status,
    this.message,
  });

  final DonationHistoryDownloadStatus status;
  final String? message;

  bool get isSuccess => status == DonationHistoryDownloadStatus.success;
}

/// Downloads a donation-history PDF URL into the device Downloads folder
/// (Android) or app Documents / Files (iOS).
class DonationHistoryDownloadService {
  const DonationHistoryDownloadService();

  Future<DonationHistoryDownloadResult> savePdfFromUrl(String pdfUrl) async {
    final uri = Uri.tryParse(pdfUrl.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return const DonationHistoryDownloadResult(
        status: DonationHistoryDownloadStatus.failed,
        message: 'Invalid download link.',
      );
    }

    try {
      if (!kIsWeb && Platform.isAndroid) {
        await _ensureAndroidStoragePermission();
      }

      final response = await http.get(uri).timeout(const Duration(seconds: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return DonationHistoryDownloadResult(
          status: DonationHistoryDownloadStatus.failed,
          message: 'Unable to download PDF (${response.statusCode}).',
        );
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        return const DonationHistoryDownloadResult(
          status: DonationHistoryDownloadStatus.failed,
          message: 'Downloaded PDF is empty.',
        );
      }

      final name = _buildFileName();
      final pdfBytes = Uint8List.fromList(bytes);

      if (!kIsWeb && Platform.isAndroid) {
        await FileSaver.instance.saveToDownloads(
          name: name,
          bytes: pdfBytes,
          fileExtension: 'pdf',
          mimeType: MimeType.pdf,
        );
        return const DonationHistoryDownloadResult(
          status: DonationHistoryDownloadStatus.success,
          message: 'PDF saved to Downloads.',
        );
      }

      // iOS has no shared Downloads folder — save to app Documents (Files app).
      await FileSaver.instance.saveFile(
        name: name,
        bytes: pdfBytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      return const DonationHistoryDownloadResult(
        status: DonationHistoryDownloadStatus.success,
        message: 'PDF saved. Open it from the Files app.',
      );
    } catch (e) {
      return DonationHistoryDownloadResult(
        status: DonationHistoryDownloadStatus.failed,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  String _buildFileName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Jamiat_Donation_History_'
        '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}';
  }

  /// WRITE_EXTERNAL_STORAGE is only needed on Android 9 and below.
  /// Android 10+ uses MediaStore and does not need this permission.
  Future<void> _ensureAndroidStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final status = await Permission.storage.status;
    if (status.isGranted || status.isLimited) return;
    if (status.isDenied) {
      await Permission.storage.request();
    }
  }
}
