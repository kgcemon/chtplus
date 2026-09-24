import 'package:flutter/material.dart';

import '../home/widgets/home_header.dart';
import 'site_layout.dart';

/// A secondary page laid out like the website's: the site header, the page
/// title and subtitle (with an optional button beside them), then [body].
///
/// [body] may scroll on its own; the title row stays above it.
class SiteScaffold extends StatelessWidget {
  const SiteScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    required this.body,
    this.headerBottom,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showTitle = true,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget body;

  /// A strip under the header, such as tabs or a step progress bar.
  final PreferredSizeWidget? headerBottom;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  /// False for pages that draw their own heading inside [body].
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SiteAppBar(bottom: headerBottom),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: showTitle
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHead(
                  title: Text(title),
                  subtitle: subtitle,
                  action: action,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                ),
                Expanded(child: body),
              ],
            )
          : body,
    );
  }
}
