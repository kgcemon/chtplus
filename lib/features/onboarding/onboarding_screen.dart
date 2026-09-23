import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/home_provider.dart';
import '../../router.dart';

/// Asks a new account which parts of CHT Plus they care about, then orders the
/// home screen accordingly — the same idea as `HomePersonalize` on the site.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _topics = <({String key, String emoji, String title, String blurb})>[
    (
      key: 'services',
      emoji: '🧰',
      title: 'Services',
      blurb: 'Electricians, tutors, transport and more',
    ),
    (
      key: 'donors',
      emoji: '🩸',
      title: 'Blood donors',
      blurb: 'Find a donor near you in an emergency',
    ),
    (
      key: 'marketplace',
      emoji: '🛒',
      title: 'Marketplace',
      blurb: 'Buy and sell locally',
    ),
    (
      key: 'biodata',
      emoji: '💍',
      title: 'Matrimony',
      blurb: 'Verified biodata for marriage',
    ),
    (
      key: 'doctors',
      emoji: '🩺',
      title: 'Doctors',
      blurb: 'Book a serial with a doctor',
    ),
  ];

  final _selected = <String>{};
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    final interests = _selected.toList();
    try {
      await ref.read(meRepositoryProvider).saveHomeInterests(interests);
      await ref.read(authControllerProvider.notifier).markOnboardingComplete(interests);
      ref.invalidate(homeFeedProvider);
      if (mounted) context.go(Routes.home);
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(currentUserProvider)?.name ?? '';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 32, 22, 20),
                children: [
                  Text(
                    name.isEmpty ? 'Welcome to CHT Plus' : 'Welcome, ${name.split(' ').first}',
                    style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pick what interests you and we will put it at the top of your home screen. You can change this any time.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 26),
                  for (final topic in _topics) ...[
                    _TopicTile(
                      emoji: topic.emoji,
                      title: topic.title,
                      blurb: topic.blurb,
                      selected: _selected.contains(topic.key),
                      onTap: () => setState(() {
                        if (!_selected.remove(topic.key)) _selected.add(topic.key);
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _busy ? null : _save,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size(0, 50),
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _busy ? null : _save,
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.emoji,
    required this.title,
    required this.blurb,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String blurb;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.forestLight : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    blurb,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? AppColors.forest : AppColors.border,
            ),
          ],
        ),
      ),
    );
  }
}
