import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/home_provider.dart';

/// The home-page topics a user can put first, as on the site's
/// `EditInterestsModal` (the same keys the onboarding screen saves).
const interestOptions = [
  (key: 'services', icon: '🧰', label: 'Services'),
  (key: 'donors', icon: '🩸', label: 'Blood Donors'),
  (key: 'marketplace', icon: '🛒', label: 'Marketplace'),
  (key: 'biodata', icon: '💍', label: 'Matrimony'),
];

const _labels = {
  'services': 'Services',
  'donors': 'Blood Donors',
  'marketplace': 'Marketplace',
  'biodata': 'Matrimony',
  'doctors': 'Doctor Appointments',
};

/// "Services, Matrimony" — or the site's note when nothing is picked.
String interestsSummary(List<String> interests) => interests.isEmpty
    ? 'None selected (the default order is shown)'
    : interests.map((k) => _labels[k] ?? k).join(', ');

Future<void> showEditInterestsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => const _EditInterestsSheet(),
  );
}

class _EditInterestsSheet extends ConsumerStatefulWidget {
  const _EditInterestsSheet();

  @override
  ConsumerState<_EditInterestsSheet> createState() => _EditInterestsSheetState();
}

class _EditInterestsSheetState extends ConsumerState<_EditInterestsSheet> {
  late final Set<String> _selected = {...?ref.read(currentUserProvider)?.homeInterests};
  bool _busy = false;

  Future<void> _save(List<String> interests) async {
    setState(() => _busy = true);
    try {
      await ref.read(meRepositoryProvider).saveHomeInterests(interests);
      await ref.read(authControllerProvider.notifier).markOnboardingComplete(interests);
      ref.invalidate(homeFeedProvider);
      if (mounted) {
        AppSnackbar.success(context, 'Interests saved.');
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        AppSnackbar.error(context, error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Change your interests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'The topics you select will be shown first on the home page',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          for (final opt in interestOptions) ...[
            _InterestTile(
              icon: opt.icon,
              label: opt.label,
              checked: _selected.contains(opt.key),
              onTap: _busy
                  ? null
                  : () => setState(() {
                        if (!_selected.remove(opt.key)) _selected.add(opt.key);
                      }),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _save(const []),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.forest,
                    side: const BorderSide(color: AppColors.forest),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Keep default'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  // Keep the order the options are listed in.
                  onPressed: _busy
                      ? null
                      : () => _save([
                            for (final opt in interestOptions)
                              if (_selected.contains(opt.key)) opt.key,
                          ]),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(_busy ? 'Saving...' : 'Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InterestTile extends StatelessWidget {
  const _InterestTile({required this.icon, required this.label, required this.checked, required this.onTap});

  final String icon;
  final String label;
  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: checked ? AppColors.forestLight : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: checked ? AppColors.forest : AppColors.border, width: checked ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
              ),
              Icon(
                checked ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: checked ? AppColors.forest : AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
