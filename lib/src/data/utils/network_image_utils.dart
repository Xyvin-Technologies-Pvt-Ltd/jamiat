import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Normalizes API image URLs (`//…`, quoted strings, empty/`null`).
String? resolveNetworkImageUrl(String? raw) {
  var value = raw?.trim();
  if (value == null || value.isEmpty || value == 'null') return null;
  if ((value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))) {
    value = value.substring(1, value.length - 1).trim();
  }
  if (value.isEmpty || value == 'null') return null;
  if (value.startsWith('//')) value = 'https:$value';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  return null;
}

/// Pixel size for decode/cache from a logical layout size.
int? networkImageCachePx(double? logicalSize, double devicePixelRatio) {
  if (logicalSize == null ||
      !logicalSize.isFinite ||
      logicalSize <= 0 ||
      !devicePixelRatio.isFinite ||
      devicePixelRatio <= 0) {
    return null;
  }
  return (logicalSize * devicePixelRatio).round().clamp(1, 2048);
}

String? _lastPrefetchSignature;

@visibleForTesting
void resetNetworkImagePrefetchSignature() => _lastPrefetchSignature = null;

/// Warm disk + memory cache so home covers appear instantly on next build.
///
/// Safe to call from build/listen: work is deferred to a post-frame callback,
/// duplicate URL sets are skipped, and unmounted contexts are ignored.
void prefetchNetworkImages(
  BuildContext context,
  Iterable<String?> urls, {
  int? cacheWidth,
  int? cacheHeight,
}) {
  if (!context.mounted) return;

  final resolved = <String>[];
  final seen = <String>{};
  for (final raw in urls) {
    final url = resolveNetworkImageUrl(raw);
    if (url == null || !seen.add(url)) continue;
    resolved.add(url);
  }
  if (resolved.isEmpty) return;

  final signature = '${resolved.join('|')}@${cacheWidth}x$cacheHeight';
  if (signature == _lastPrefetchSignature) return;
  _lastPrefetchSignature = signature;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    for (final url in resolved) {
      final provider = CachedNetworkImageProvider(
        url,
        maxWidth: cacheWidth,
        maxHeight: cacheHeight,
      );
      unawaited(_precacheQuietly(provider, context));
    }
  });
}

Future<void> _precacheQuietly(
  ImageProvider provider,
  BuildContext context,
) async {
  if (!context.mounted) return;
  try {
    await precacheImage(provider, context);
  } catch (_) {
    // Prefetch is best-effort; UI still has its own error path.
  }
}
