import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../theme.dart';
import '../utils/formatters.dart';

/// Service and listing descriptions arrive as HTML that the server has already
/// run through `sanitize-html`, so only a small tag set can appear — or as
/// plain text with Enter-made line breaks. Like the site's
/// `.service-detail-description` (`white-space: pre-wrap`), line breaks and
/// extra spaces are kept as typed, and any HTML tags still format the text.
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

    // Clamped previews are one-line plain text: a truncated HTML tree cannot
    // honour maxLines reliably.
    if (maxLines != null) {
      return Text(
        Fmt.plainText(source),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return HtmlWidget(
      preWrap(source),
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

/// Makes HTML keep its typed line breaks and runs of spaces, the way CSS
/// `white-space: pre-wrap` does on the site: outside of tags each newline
/// becomes `<br>` and every space after the first in a run becomes `&nbsp;`.
/// Text inside `<pre>` is left alone (it keeps them already).
String preWrap(String html) {
  final source = html.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final out = StringBuffer();
  var inTag = false;
  var tagStart = 0;
  var preDepth = 0;
  var previousWasSpace = false;

  for (var i = 0; i < source.length; i++) {
    final ch = source[i];
    if (inTag) {
      out.write(ch);
      if (ch == '>') {
        inTag = false;
        final tag = source.substring(tagStart, i + 1).toLowerCase();
        if (RegExp(r'^<pre[\s>]').hasMatch(tag)) preDepth++;
        if (tag.startsWith('</pre') && preDepth > 0) preDepth--;
      }
      continue;
    }
    if (ch == '<') {
      inTag = true;
      tagStart = i;
      previousWasSpace = false;
      out.write(ch);
      continue;
    }
    if (preDepth > 0) {
      out.write(ch);
    } else if (ch == '\n') {
      out.write('<br>');
      previousWasSpace = false;
    } else if (ch == ' ' || ch == '\t') {
      out.write(previousWasSpace ? '&nbsp;' : ' ');
      previousWasSpace = true;
    } else {
      out.write(ch);
      previousWasSpace = false;
    }
  }
  return out.toString();
}
