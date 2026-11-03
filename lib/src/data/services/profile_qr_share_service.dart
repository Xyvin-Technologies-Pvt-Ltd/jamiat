import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/models/user_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

enum ProfileQrShareStatus { success, cancelled, failed }

class ProfileQrShareResult {
  const ProfileQrShareResult({
    required this.status,
    this.message,
  });

  final ProfileQrShareStatus status;
  final String? message;

  bool get isSuccess => status == ProfileQrShareStatus.success;
}

/// Captures the member QR card and opens the system share sheet
/// (WhatsApp, Instagram, Messages, etc.).
class ProfileQrShareService {
  const ProfileQrShareService();

  Future<ProfileQrShareResult> shareProfileQr({
    required BuildContext context,
    required UserModel user,
  }) async {
    OverlayEntry? overlayEntry;
    try {
      final qrBytes = _decodeQrBytes(user.qrCode);
      final boundaryKey = GlobalKey();
      final cardWidth = MediaQuery.sizeOf(context).width - 48;
      final shareOrigin = _shareOrigin(context);

      overlayEntry = OverlayEntry(
        builder: (_) => Material(
          color: Colors.transparent,
          child: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: cardWidth,
                child: _ProfileQrCaptureCard(
                  user: user,
                  qrBytes: qrBytes,
                ),
              ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(overlayEntry);

      await Future<void>.delayed(const Duration(milliseconds: 500));
      await WidgetsBinding.instance.endOfFrame;

      final bytes = await _captureBoundary(boundaryKey);
      overlayEntry.remove();
      overlayEntry = null;

      if (bytes == null || bytes.isEmpty) {
        return const ProfileQrShareResult(
          status: ProfileQrShareStatus.failed,
          message: 'Unable to capture QR code. Please try again.',
        );
      }

      final file = await _writeTempPng(bytes, _buildFileName(user));
      if (file == null) {
        return const ProfileQrShareResult(
          status: ProfileQrShareStatus.failed,
          message: 'Unable to prepare QR image for sharing.',
        );
      }

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text:
              'My Jamiat membership QR\n${user.displayName} · ID : ${user.displayMemberId}',
          subject: 'Jamiat Member QR',
          sharePositionOrigin: shareOrigin,
        ),
      );

      if (result.status == ShareResultStatus.dismissed) {
        return const ProfileQrShareResult(
          status: ProfileQrShareStatus.cancelled,
        );
      }

      return const ProfileQrShareResult(
        status: ProfileQrShareStatus.success,
      );
    } catch (e, st) {
      debugPrint('Profile QR share failed: $e\n$st');
      final raw = e.toString();
      if (raw.contains('MissingPluginException')) {
        return const ProfileQrShareResult(
          status: ProfileQrShareStatus.failed,
          message: 'Please fully restart the app, then try again.',
        );
      }
      return ProfileQrShareResult(
        status: ProfileQrShareStatus.failed,
        message: 'Failed to share QR code: ${_shortError(raw)}',
      );
    } finally {
      overlayEntry?.remove();
    }
  }

  Rect? _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Uint8List? _decodeQrBytes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final base64Part = raw.contains(',') ? raw.split(',').last : raw;
      return base64Decode(base64Part);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _captureBoundary(GlobalKey boundaryKey) async {
    final boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    for (var i = 0; i < 20; i++) {
      await WidgetsBinding.instance.endOfFrame;
      var needsPaint = false;
      assert(() {
        needsPaint = boundary.debugNeedsPaint;
        return true;
      }());
      if (!needsPaint) break;
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<File?> _writeTempPng(Uint8List bytes, String name) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name.png');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('Temp profile QR file write failed: $e');
      return null;
    }
  }

  String _buildFileName(UserModel user) {
    final safeId =
        user.displayMemberId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    return 'jamiat_qr_${safeId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _shortError(String raw) {
    final cleaned = raw
        .replaceAll('Exception: ', '')
        .replaceAll('FlutterError: ', '')
        .trim();
    if (cleaned.length <= 120) return cleaned;
    return '${cleaned.substring(0, 117)}...';
  }
}

class _ProfileQrCaptureCard extends StatelessWidget {
  const _ProfileQrCaptureCard({
    required this.user,
    required this.qrBytes,
  });

  final UserModel user;
  final Uint8List? qrBytes;

  @override
  Widget build(BuildContext context) {
    final qrData = user.id;

    return Material(
      color: kWhite,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kCardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Jamiat Member',
                style: kSectionTitleSB.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                user.displayName,
                style: kBodyTitleB.copyWith(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'ID : ${user.displayMemberId}',
                style: kCaption12R.copyWith(color: kSecondaryTextColor),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                child: qrBytes != null
                    ? Image.memory(
                        qrBytes!,
                        width: 180,
                        height: 180,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (_, _, _) => _QrFallback(data: qrData),
                      )
                    : _QrFallback(data: qrData),
              ),
              const SizedBox(height: 12),
              Text(
                'Show this QR to verify your Jamiat membership',
                style: kCaption12R.copyWith(color: kSecondaryTextColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrFallback extends StatelessWidget {
  const _QrFallback({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        width: 180,
        height: 180,
        color: kScreenBg,
        child: const Icon(Icons.qr_code_2, size: 100, color: kMutedText),
      );
    }
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: 180,
      backgroundColor: kWhite,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: kBlack,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: kBlack,
      ),
    );
  }
}
