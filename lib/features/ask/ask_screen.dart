import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/common.dart';
import '../../models/ask.dart';
import '../../providers/core_providers.dart';
import '../widgets/site_layout.dart';
import '../widgets/site_scaffold.dart';

const _examples = [
  'খাগড়াছড়িতে O+ রক্ত লাগবে',
  'panchari te electrician',
  'used bike kinbo',
  'পাত্রী খুঁজছি রাঙ্গামাটি',
  'coin kivabe kinbo',
  'hotel in sajek',
];

const _typeIcons = {'donor': '🩸', 'service': '🧰', 'listing': '🛒', 'biodata': '💍'};

// The bottom-nav tabs are switched to (go), everything else is pushed.
const _tabRoots = {'/', '/services', '/donors', '/marketplace', '/biodata'};

/// "Ask CHT Plus", like the site's /ask page: type what you need in Bangla,
/// English or Banglish and get matching donors, services, products or
/// biodata (and how-to answers), each one tap away.
class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  late final _input = TextEditingController(text: widget.initialQuery ?? '');
  final _focus = FocusNode();
  AskAnswer? _answer;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isNotEmpty) {
      _ask(q);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _ask(String question) async {
    final q = question.trim();
    if (q.isEmpty || _loading) return;
    _input.text = q;
    _focus.unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final answer = await ref.read(catalogRepositoryProvider).ask(q);
      if (mounted) setState(() => _answer = answer);
    } on ApiException {
      if (mounted) setState(() => _error = 'কিছু একটা সমস্যা হয়েছে, আবার চেষ্টা করুন।');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(String? appRoute, String? url) {
    final route = (appRoute ?? '').trim();
    if (route.isNotEmpty) {
      final path = Uri.parse(route).path;
      if (_tabRoots.contains(path)) {
        context.go(route);
      } else {
        context.push(route);
      }
      return;
    }
    if ((url ?? '').isNotEmpty) Launchers.url(context, url);
  }

  @override
  Widget build(BuildContext context) {
    final answer = _answer;
    final examples = answer == null ? _examples : answer.examples;

    return SiteScaffold(
      title: 'Ask CHT Plus',
      subtitle: 'যা দরকার লিখুন — রক্ত, সার্ভিস, পণ্য, পাত্র-পাত্রী বা সাইট ব্যবহারের নিয়ম',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _focus,
                    maxLength: 200,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _ask,
                    decoration: const InputDecoration(
                      hintText: 'যেমন: পানছড়িতে ইলেকট্রিশিয়ান লাগবে',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: _loading ? null : () => _ask(_input.text),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Ask'),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13.5)),
          ],
          if (answer != null && answer.answer.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.forestLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 17)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(answer.answer, style: const TextStyle(fontSize: 14.5, height: 1.55)),
                  ),
                ],
              ),
            ),
          ],
          if (answer != null && answer.results.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < answer.results.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.border),
                    _ResultRow(
                      result: answer.results[i],
                      onTap: () => _open(answer.results[i].appRoute, answer.results[i].url),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (answer != null && answer.links.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < answer.links.length; i++)
                  SiteButton(
                    label: '${answer.links[i].label} →',
                    outlined: i > 0,
                    onPressed: () => _open(answer.links[i].appRoute, answer.links[i].url),
                  ),
              ],
            ),
          ],
          if (examples.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'উদাহরণ — চাপলেই জিজ্ঞেস হবে:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ex in examples)
                  ActionChip(
                    label: Text(ex, style: const TextStyle(fontSize: 13)),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.border),
                    shape: const StadiumBorder(),
                    onPressed: () => _ask(ex),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result, required this.onTap});

  final AskResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = (result.photoUrl ?? '').isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            if (hasPhoto)
              Avatar(url: result.photoUrl, name: result.title, size: 44)
            else
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFFFDECEB), shape: BoxShape.circle),
                child: Text(
                  result.badge ?? _typeIcons[result.type] ?? '•',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.red),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                  if ((result.subtitle ?? '').isNotEmpty)
                    Text(
                      result.subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
