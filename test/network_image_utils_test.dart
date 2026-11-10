import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamiat/src/data/utils/network_image_utils.dart';
import 'package:jamiat/src/interfaces/components/campaign_card.dart';

void main() {
  group('resolveNetworkImageUrl', () {
    test('returns null for missing / empty / literal null values', () {
      expect(resolveNetworkImageUrl(null), isNull);
      expect(resolveNetworkImageUrl(''), isNull);
      expect(resolveNetworkImageUrl('   '), isNull);
      expect(resolveNetworkImageUrl('null'), isNull);
      expect(resolveNetworkImageUrl('"null"'), isNull);
      expect(resolveNetworkImageUrl("''"), isNull);
      expect(resolveNetworkImageUrl('""'), isNull);
    });

    test('accepts http and https URLs', () {
      expect(
        resolveNetworkImageUrl('https://cdn.example.com/a.jpg'),
        'https://cdn.example.com/a.jpg',
      );
      expect(
        resolveNetworkImageUrl('http://cdn.example.com/a.jpg'),
        'http://cdn.example.com/a.jpg',
      );
    });

    test('upgrades protocol-relative URLs', () {
      expect(
        resolveNetworkImageUrl('//cdn.example.com/a.jpg'),
        'https://cdn.example.com/a.jpg',
      );
    });

    test('strips wrapping quotes then resolves', () {
      expect(
        resolveNetworkImageUrl('"https://cdn.example.com/a.jpg"'),
        'https://cdn.example.com/a.jpg',
      );
      expect(
        resolveNetworkImageUrl("'//cdn.example.com/a.jpg'"),
        'https://cdn.example.com/a.jpg',
      );
    });

    test('rejects relative paths and non-http schemes', () {
      expect(resolveNetworkImageUrl('/uploads/a.jpg'), isNull);
      expect(resolveNetworkImageUrl('uploads/a.jpg'), isNull);
      expect(resolveNetworkImageUrl('ftp://cdn.example.com/a.jpg'), isNull);
      expect(resolveNetworkImageUrl('data:image/png;base64,abc'), isNull);
    });

    test('trims surrounding whitespace', () {
      expect(
        resolveNetworkImageUrl('  https://cdn.example.com/a.jpg  '),
        'https://cdn.example.com/a.jpg',
      );
    });
  });

  group('networkImageCachePx', () {
    test('scales logical size by device pixel ratio', () {
      expect(networkImageCachePx(241, 3), 723);
      expect(networkImageCachePx(100, 2), 200);
    });

    test('clamps extremely large decode sizes', () {
      expect(networkImageCachePx(5000, 3), 2048);
    });

    test('returns null for invalid inputs', () {
      expect(networkImageCachePx(null, 3), isNull);
      expect(networkImageCachePx(0, 3), isNull);
      expect(networkImageCachePx(-10, 3), isNull);
      expect(networkImageCachePx(double.nan, 3), isNull);
      expect(networkImageCachePx(double.infinity, 3), isNull);
      expect(networkImageCachePx(100, 0), isNull);
      expect(networkImageCachePx(100, -1), isNull);
      expect(networkImageCachePx(100, double.nan), isNull);
    });

    test('never returns less than 1px for tiny positive sizes', () {
      expect(networkImageCachePx(0.1, 0.1), 1);
    });
  });

  group('campaignCoverImage', () {
    testWidgets('shows placeholder when url is missing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.expand(child: _Cover(url: null))),
        ),
      );

      expect(find.text('No image'), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('shows placeholder for invalid url', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(child: _Cover(url: '/local/path.jpg')),
          ),
        ),
      );

      expect(find.text('No image'), findsOneWidget);
    });

    testWidgets('can hide placeholder label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: _Cover(url: null, showLabel: false),
            ),
          ),
        ),
      );

      expect(find.text('No image'), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('builds cached image for valid https url', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 241,
              height: 262,
              child: _Cover(url: 'https://cdn.example.com/cover.jpg'),
            ),
          ),
        ),
      );

      // Placeholder while loading — must not crash or show broken-image error.
      expect(find.text('No image'), findsNothing);
      expect(find.byType(ColoredBox), findsWidgets);
    });

    testWidgets('prefetch ignores empty url sets and unmounted contexts', (
      tester,
    ) async {
      resetNetworkImagePrefetchSignature();

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );
      final context = tester.element(find.byType(SizedBox));

      expect(
        () => prefetchNetworkImages(context, const [null, '', 'null']),
        returnsNormally,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      expect(
        () => prefetchNetworkImages(context, const [
          'https://cdn.example.com/a.jpg',
        ]),
        returnsNormally,
      );
    });
  });
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, this.showLabel = true});

  final String? url;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return campaignCoverImage(
      url,
      showPlaceholderLabel: showLabel,
      placeholderIconSize: 36,
    );
  }
}
