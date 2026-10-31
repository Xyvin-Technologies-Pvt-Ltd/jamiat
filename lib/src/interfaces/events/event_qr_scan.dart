import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/event_api.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class EventQrScanScreen extends ConsumerStatefulWidget {
  const EventQrScanScreen({
    super.key,
    required this.eventId,
    this.eventTitle,
  });

  final String eventId;
  final String? eventTitle;

  @override
  ConsumerState<EventQrScanScreen> createState() => _EventQrScanScreenState();
}

class _EventQrScanScreenState extends ConsumerState<EventQrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _busy = false;
  bool _permissionDenied = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _ensureCameraPermission();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ensureCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => _permissionDenied = true);
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue?.trim())
        .whereType<String>()
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;

    setState(() {
      _busy = true;
      _statusMessage = null;
    });

    try {
      await _controller.stop();
      final res = await ref.read(eventApiProvider).scanTicket(raw);
      if (!mounted) return;

      if (!res.success || res.data == null) {
        HapticHelper.impact(HapticImpact.medium);
        setState(() {
          _statusIsError = true;
          _statusMessage = res.message ?? 'Scan failed';
        });
        await Future<void>.delayed(const Duration(milliseconds: 1600));
        return;
      }

      final result = res.data!;
      HapticHelper.impact(HapticImpact.medium);

      if (result.alreadyAttended) {
        setState(() {
          _statusIsError = true;
          _statusMessage = res.message ??
              '${result.attendeeName ?? 'Guest'} already checked in';
        });
      } else {
        setState(() {
          _statusIsError = false;
          _statusMessage = res.message ??
              'Attendance marked${result.attendeeName != null ? ' · ${result.attendeeName}' : ''}';
        });
      }

      await Future<void>.delayed(const Duration(milliseconds: 1800));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusIsError = true;
        _statusMessage = e.toString().replaceFirst('Exception: ', '');
      });
      await Future<void>.delayed(const Duration(milliseconds: 1600));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _statusMessage = null;
        });
        try {
          await _controller.start();
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cutoutSize = size.width * 0.68;

    return Scaffold(
      backgroundColor: kBlack,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: kScreenPaddingH),
          child: Center(
            child: GestureDetector(
              onTap: () {
                HapticHelper.impact(HapticImpact.light);
                Navigator.pop(context);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kWhite, width: 1.25),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: kWhite,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        titleSpacing: 8,
        title: Text(
          'Scan any QR',
          style: kSectionTitleSB.copyWith(color: kWhite),
        ),
        centerTitle: false,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_permissionDenied)
            const ColoredBox(
              color: kBlack,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Camera permission is required to scan tickets.\nOpen Settings to enable it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kWhite, height: 1.4),
                  ),
                ),
              ),
            )
          else
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          CustomPaint(
            size: size,
            painter: _ScanOverlayPainter(
              cutoutSize: cutoutSize,
              overlayColor: kBlack.withValues(alpha: 0.55),
              frameColor: kWhite,
            ),
          ),
          if (_statusMessage != null)
            Positioned(
              left: kScreenPaddingH,
              right: kScreenPaddingH,
              bottom: 48,
              child: Material(
                color: _statusIsError
                    ? const Color(0xFF7F1D1D)
                    : kPrimaryColor,
                borderRadius: BorderRadius.circular(kCardRadiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(
                    _statusMessage!,
                    textAlign: TextAlign.center,
                    style: kBodyTitleM.copyWith(color: kWhite, height: 1.3),
                  ),
                ),
              ),
            ),
          if (_busy && _statusMessage == null)
            const Center(
              child: CircularProgressIndicator(color: kWhite),
            ),
          if (_permissionDenied)
            Positioned(
              left: kScreenPaddingH,
              right: kScreenPaddingH,
              bottom: 48,
              child: ElevatedButton(
                onPressed: openAppSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: kWhite,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kCardRadiusSm),
                  ),
                  elevation: 0,
                ),
                child: Text('Open Settings', style: kButtonLabelSB),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  _ScanOverlayPainter({
    required this.cutoutSize,
    required this.overlayColor,
    required this.frameColor,
  });

  final double cutoutSize;
  final Color overlayColor;
  final Color frameColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cutout = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cutoutSize,
      height: cutoutSize,
    );

    final overlayPath = Path()
      ..addRect(Offset.zero & size)
      ..addRect(cutout)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(overlayPath, Paint()..color = overlayColor);

    final paint = Paint()
      ..color = frameColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    const corner = 28.0;
    final left = cutout.left;
    final top = cutout.top;
    final right = cutout.right;
    final bottom = cutout.bottom;

    canvas.drawLine(Offset(left, top + corner), Offset(left, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left + corner, top), paint);

    canvas.drawLine(Offset(right - corner, top), Offset(right, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + corner), paint);

    canvas.drawLine(Offset(left, bottom - corner), Offset(left, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left + corner, bottom), paint);

    canvas.drawLine(
      Offset(right - corner, bottom),
      Offset(right, bottom),
      paint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - corner),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) {
    return oldDelegate.cutoutSize != cutoutSize ||
        oldDelegate.overlayColor != overlayColor ||
        oldDelegate.frameColor != frameColor;
  }
}
