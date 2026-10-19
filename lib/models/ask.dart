import '../core/utils/json.dart';

/// `/api/ask?q=` — the free, rule-based "Ask CHT Plus" assistant (see the
/// site's lib/ask.js): a short answer, matching items and follow-up links,
/// each with the app route to open.
class AskAnswer {
  const AskAnswer({
    required this.query,
    required this.intent,
    required this.answer,
    this.results = const [],
    this.links = const [],
    this.examples = const [],
  });

  final String query;
  final String intent;
  final String answer;
  final List<AskResult> results;
  final List<AskLink> links;

  /// Sample questions, sent when the question was empty or not understood.
  final List<String> examples;

  factory AskAnswer.fromJson(Map<String, dynamic> json) => AskAnswer(
        query: json.str('query'),
        intent: json.str('intent'),
        answer: json.str('answer'),
        results: json.mapList('results').map(AskResult.fromJson).toList(growable: false),
        links: json.mapList('links').map(AskLink.fromJson).toList(growable: false),
        examples: json.stringList('examples'),
      );
}

class AskResult {
  const AskResult({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.badge,
    this.photoUrl,
    this.url,
    this.appRoute,
  });

  /// donor · service · listing · biodata
  final String type;
  final String id;
  final String title;
  final String? subtitle;

  /// Short text for the round icon when there is no photo (a blood group).
  final String? badge;
  final String? photoUrl;
  final String? url;
  final String? appRoute;

  factory AskResult.fromJson(Map<String, dynamic> json) => AskResult(
        type: json.str('type'),
        id: json.str('id'),
        title: json.str('title'),
        subtitle: json.strOrNull('subtitle'),
        badge: json.strOrNull('badge'),
        photoUrl: json.strOrNull('photoUrl'),
        url: json.strOrNull('url'),
        appRoute: json.strOrNull('appRoute'),
      );
}

class AskLink {
  const AskLink({required this.label, this.url, this.appRoute});

  final String label;
  final String? url;
  final String? appRoute;

  factory AskLink.fromJson(Map<String, dynamic> json) => AskLink(
        label: json.str('label'),
        url: json.strOrNull('url'),
        appRoute: json.strOrNull('appRoute'),
      );
}
