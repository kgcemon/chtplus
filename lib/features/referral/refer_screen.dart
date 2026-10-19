import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../models/referral.dart';
import '../../providers/core_providers.dart';
import '../widgets/site_layout.dart';
import '../widgets/site_scaffold.dart';

final referralSummaryProvider = FutureProvider.autoDispose<ReferralSummary>(
  (ref) => ref.watch(meRepositoryProvider).referral(),
);

const _statusLabels = {
  'pending': 'Profile not complete yet',
  'rewarded': 'Completed',
  'rejected': 'Not counted',
};

const _checklistLabels = {
  'photo': 'Profile photo',
  'phone': 'Phone number',
  'location': 'Area / current city',
};

/// Refer & Win, laid out like the site's /refer page: the green reward card
/// with the code and share buttons, the user's own welcome-bonus checklist
/// (if they joined with a code), three stat tiles, then who joined.
class ReferScreen extends ConsumerWidget {
  const ReferScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(referralSummaryProvider);

    return SiteScaffold(
      title: 'Refer & Win',
      subtitle: 'Invite friends to CHT Plus and you both get free coins',
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(referralSummaryProvider.future),
        child: summary.when(
          loading: () => const AppLoader(),
          error: (_, __) => ListView(
            children: [
              ErrorView(
                message: 'Could not load your referral details, please try again.',
                onRetry: () => ref.invalidate(referralSummaryProvider),
              ),
            ],
          ),
          data: (data) => data.enabled
              ? _ReferBody(data: data)
              : ListView(
                  children: const [
                    EmptyNote('Refer & Win is paused right now. Please check back later.'),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ReferBody extends StatelessWidget {
  const _ReferBody({required this.data});

  final ReferralSummary data;

  String get _shareText {
    final bonus = data.referredReward > 0 ? ' and get ${data.referredReward} free coins' : '';
    return 'Join me on CHT Plus — services, blood donors, marketplace and more in the '
        'Hill Tracts. Sign up with my code ${data.code}$bonus: ${data.shareUrl}';
  }

  Future<void> _copy(BuildContext context, String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) AppSnackbar.success(context, '$what copied');
  }

  @override
  Widget build(BuildContext context) {
    final joined = data.joinedWith;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _HeroCard(
          data: data,
          onCopyCode: () => _copy(context, data.code, 'Code'),
          onWhatsApp: () => Launchers.url(
            context,
            'https://wa.me/?text=${Uri.encodeComponent(_shareText)}',
          ),
          onFacebook: () => Launchers.url(
            context,
            'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(data.shareUrl)}',
          ),
          onCopyLink: () => _copy(context, data.shareUrl, 'Link'),
          onShare: () => Launchers.share(_shareText, subject: 'CHT Plus'),
        ),
        if (joined != null && joined.status == 'pending' && joined.checklist.isNotEmpty) ...[
          const SizedBox(height: 16),
          _OwnBonusCard(joined: joined),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _StatTile(value: '${data.stats.joined}', label: 'Joined')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(value: '${data.stats.completed}', label: 'Completed')),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(value: '🪙 ${data.stats.coinsEarned}', label: 'Coins earned'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FriendsCard(friends: data.referrals),
        if (data.monthlyLimit > 0) ...[
          const SizedBox(height: 14),
          Text(
            'You can earn coins for up to ${data.monthlyLimit} friends each month.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.data,
    required this.onCopyCode,
    required this.onWhatsApp,
    required this.onFacebook,
    required this.onCopyLink,
    required this.onShare,
  });

  final ReferralSummary data;
  final VoidCallback onCopyCode;
  final VoidCallback onWhatsApp;
  final VoidCallback onFacebook;
  final VoidCallback onCopyLink;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    Widget reward(int coins, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0x24FFFFFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  '🪙 $coins',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF))),
              ],
            ),
          ),
        );

    Widget shareButton(String label, Color color, VoidCallback onTap) => FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        );

    Widget outlineButton(String label, VoidCallback onTap) => OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0x99FFFFFF)),
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest, AppColors.forestDark],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              reward(data.referrerReward, 'for you'),
              const SizedBox(width: 10),
              reward(data.referredReward, 'for your friend'),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Coins are added when your friend signs up with your code and completes '
            'their profile (photo, phone and area).',
            style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xEBFFFFFF)),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('Your code', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data.code,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      fontFamily: 'monospace',
                      color: AppColors.text,
                    ),
                  ),
                ),
                SiteButton(label: 'Copy', outlined: true, onPressed: onCopyCode),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: shareButton('WhatsApp', const Color(0xFF25D366), onWhatsApp)),
              const SizedBox(width: 8),
              Expanded(child: shareButton('Facebook', const Color(0xFF1877F2), onFacebook)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: outlineButton('Copy link', onCopyLink)),
              const SizedBox(width: 8),
              Expanded(child: outlineButton('More…', onShare)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnBonusCard extends StatelessWidget {
  const _OwnBonusCard({required this.joined});

  final JoinedWith joined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3E0B0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Get your ${joined.reward} welcome coins',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'You joined with ${joined.referrerName}’s code. Complete your profile to get the bonus:',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          for (final entry in _checklistLabels.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${joined.checklist[entry.key] == true ? '✅' : '⬜'}  ${entry.value}',
                style: TextStyle(
                  fontSize: 14,
                  color: joined.checklist[entry.key] == true ? AppColors.textSecondary : AppColors.text,
                ),
              ),
            ),
          const SizedBox(height: 6),
          SiteButton(label: 'Complete profile', onPressed: () => context.push('/profile/edit')),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.forestDark),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _FriendsCard extends StatelessWidget {
  const _FriendsCard({required this.friends});

  final List<ReferredFriend> friends;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Friends who joined', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (friends.isEmpty)
            const Text(
              'No one has joined with your code yet. Share it to start earning!',
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            )
          else
            for (var i = 0; i < friends.length; i++) ...[
              if (i > 0) const Divider(height: 20),
              InkWell(
                onTap: friends[i].userId.isEmpty ? null : () => context.push('/u/${friends[i].userId}'),
                child: Row(
                  children: [
                    Avatar(url: friends[i].photoUrl, name: friends[i].name, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friends[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            [
                              if (friends[i].createdAt != null) Fmt.date(friends[i].createdAt),
                              _statusLabels[friends[i].status] ?? friends[i].status,
                            ].join(' · '),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (friends[i].status == 'rewarded' && friends[i].reward > 0)
                      Text(
                        '+${friends[i].reward}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.forestDark),
                      ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}
