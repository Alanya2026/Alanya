import 'package:flutter/material.dart';

import '../../core/utils/rich_text_parser.dart';

/// Aperçu mono/multi-ligne qui conserve la mise en forme (*gras*, _italique_…).
class StyledPreviewText extends StatelessWidget {
  const StyledPreviewText(
    this.text, {
    super.key,
    this.style,
    this.linkColor,
    this.maxLines = 1,
  });

  final String text;
  final TextStyle? style;
  final Color? linkColor;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodySmall ?? const TextStyle();
    return Text.rich(
      TextSpan(
        children: parseRichSpans(text, base, linkColor: linkColor),
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
