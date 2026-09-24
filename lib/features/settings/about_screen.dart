import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/common.dart';
import '../../router.dart';
import '../widgets/site_scaffold.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _features = <({String emoji, String title, String blurb})>[
    (
      emoji: '🧰',
      title: 'Services',
      blurb:
          'Electricians, tutors, transport, repairs and dozens of other trades across the hill districts, with ratings and reviews from real customers.',
    ),
    (
      emoji: '🩸',
      title: 'Blood donors',
      blurb:
          'A searchable register of donors by blood group and area, showing who is available to donate right now.',
    ),
    (
      emoji: '🛒',
      title: 'Marketplace',
      blurb:
          'Buy and sell locally — phones, vehicles, furniture and more — with photos, specifications and direct contact with the seller.',
    ),
    (
      emoji: '💍',
      title: 'Matrimony',
      blurb:
          'Admin-verified biodata with full education, family and expectation details, unlocked with coins or a subscription.',
    ),
    (
      emoji: '🩺',
      title: 'Doctor appointments',
      blurb:
          'Find a doctor by department or hospital and book a serial for an open date, then track it under your appointments.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      title: 'About CHT Plus',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.forestDark,
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'C+',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHT Plus',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Khagrachari · Rangamati · Bandarban',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'CHT Plus brings the everyday services of the Chittagong Hill Tracts into one place — so finding a plumber, a blood donor, a second-hand phone, a doctor\'s serial or a marriage proposal does not mean asking around town.',
            style: TextStyle(fontSize: 14, height: 1.65),
          ),
          const SizedBox(height: 26),
          const Text(
            'What you can do here',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          for (final feature in _features)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(feature.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            feature.blurb,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.55,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Before you buy or sell',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'CHT Plus lists what other people post; it does not handle payments or guarantee any item or service. Meet in a public place, check what you are buying before paying, and never send money in advance or share an OTP code.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => Launchers.url(context, AppConfig.privacyPolicyUrl),
            icon: const Icon(Icons.privacy_tip_outlined, size: 18),
            label: const Text('Read the privacy policy'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Launchers.url(context, AppConfig.websiteUrl),
            icon: const Icon(Icons.language_rounded, size: 18),
            label: const Text('Visit chtplus.xyz'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => context.go(Routes.home),
            icon: const Icon(Icons.home_rounded, size: 18),
            label: const Text('Back to home'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }
}
