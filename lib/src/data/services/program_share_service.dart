import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

class ProgramShareResult {
  const ProgramShareResult({required this.success, this.message});

  final bool success;
  final String? message;
}

/// Opens the system share sheet for an empowerment program.
class ProgramShareService {
  const ProgramShareService();

  Future<ProgramShareResult> shareProgram({
    required BuildContext context,
    required String title,
    String? description,
  }) async {
    if (!context.mounted) {
      return const ProgramShareResult(success: false);
    }

    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    final buffer = StringBuffer('Check out "$title" on Jamiat Connect');
    final trimmed = description?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      buffer.write('\n\n$trimmed');
    }

    await SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: title,
        sharePositionOrigin: origin,
      ),
    );

    return const ProgramShareResult(success: true);
  }
}

final programShareServiceProvider = Provider<ProgramShareService>(
  (ref) => const ProgramShareService(),
);
