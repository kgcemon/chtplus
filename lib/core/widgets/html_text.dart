import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../theme.dart';
import '../utils/formatters.dart';

/// Service and listing descriptions arrive as HTML that the server has already
/// run through `sanitize-html`, so only a small tag set can appear. This
/// renders that safely and falls back to plain text when there is no markup.
class HtmlText extends StatelessWidget {
  const HtmlText({
    super.key,
    required this.html,
    this.fontSize = 14,
    this.color = AppColors.text,
    this.maxLines,
  });

  final String? html;
  final double fontSize;
  final Color color;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final source = (html ?? '').trim();
    if (source.isEmpty) return const SizedBox.shrink();

    final style = TextStyle(fontSize: fontSize, color: color, height: 1.55);

    // Clamped previews are plain text: a truncated HTML tree cannot honour
    // maxLines reliably.
    if (maxLines != null || !source.contains('<')) {
      return Text(
        Fmt.plainText(source),
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: style,
      );
    }

    return HtmlWidget(
      source,
      textStyle: style,
      renderMode: RenderMode.column,
      customStylesBuilder: (element) {
        switch (element.localName) {
          case 'p':
            return {'margin': '0 0 8px 0'};
          case 'ul':
          case 'ol':
            return {'margin': '0 0 8px 0', 'padding-left': '18px'};
          case 'a':
            return {'color': '#145C39', 'text-decoration': 'underline'};
          case 'strong':
          case 'b':
            return {'font-weight': '700'};
          default:
            return null;
        }
      },
    );
  }
}
