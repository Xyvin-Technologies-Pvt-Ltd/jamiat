import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders [text] with tappable http(s)/www URLs that open externally.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    required this.style,
    this.linkStyle,
  });

  final String text;
  final TextStyle style;
  final TextStyle? linkStyle;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  static final _urlPattern = RegExp(
    r'((?:https?:\/\/|www\.)[^\s<>"{}|\\^`\[\]]+)',
    caseSensitive: false,
  );

  final List<TapGestureRecognizer> _recognizers = [];
  late List<InlineSpan> _spans;

  @override
  void initState() {
    super.initState();
    _spans = _buildSpans();
  }

  @override
  void didUpdateWidget(covariant LinkifiedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.linkStyle != widget.linkStyle) {
      _spans = _buildSpans();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  /// Splits a matched URL into (urlPart, trailingPunctuation).
  (String, String) _splitTrailingPunctuation(String matched) {
    var url = matched;
    var trailing = '';
    while (url.isNotEmpty && '.,);:!?]'.contains(url[url.length - 1])) {
      trailing = url[url.length - 1] + trailing;
      url = url.substring(0, url.length - 1);
    }
    return (url, trailing);
  }

  Uri? _parseUri(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final withScheme =
        trimmed.toLowerCase().startsWith('http://') ||
            trimmed.toLowerCase().startsWith('https://')
        ? trimmed
        : 'https://$trimmed';

    final uri = Uri.tryParse(withScheme);
    if (uri == null || !(uri.hasScheme && uri.host.isNotEmpty)) return null;
    return uri;
  }

  Future<void> _open(Uri uri) async {
    HapticHelper.impact(HapticImpact.light);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open link')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link')),
      );
    }
  }

  List<InlineSpan> _buildSpans() {
    _disposeRecognizers();

    final text = widget.text;
    final linkStyle =
        widget.linkStyle ??
        widget.style.copyWith(
          color: kPrimaryColor,
          decoration: TextDecoration.underline,
          decorationColor: kPrimaryColor,
        );

    if (text.isEmpty) {
      return [TextSpan(text: text, style: widget.style)];
    }

    final spans = <InlineSpan>[];
    var start = 0;

    for (final match in _urlPattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, match.start),
            style: widget.style,
          ),
        );
      }

      final matched = match.group(0)!;
      final (urlPart, trailing) = _splitTrailingPunctuation(matched);
      final uri = _parseUri(urlPart);

      if (uri == null) {
        spans.add(TextSpan(text: matched, style: widget.style));
      } else {
        final recognizer = TapGestureRecognizer()..onTap = () => _open(uri);
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: urlPart,
            style: linkStyle,
            recognizer: recognizer,
          ),
        );
        if (trailing.isNotEmpty) {
          spans.add(TextSpan(text: trailing, style: widget.style));
        }
      }

      start = match.end;
    }

    if (start < text.length) {
      spans.add(
        TextSpan(text: text.substring(start), style: widget.style),
      );
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(children: _spans));
  }
}
