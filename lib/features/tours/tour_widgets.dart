import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/common.dart';
import '../../models/tour.dart';

/// The gold-and-green frame of official CHT Plus tours (site: .tour-card-is-official).
const officialTourGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF0A202), Color(0xFFFFD166), AppColors.forest, AppColors.forestDark],
  stops: [0, 0.35, 0.7, 1],
);

/// "★ Official CHT Plus Tour" ribbon.
class OfficialTourRibbon extends StatelessWidget {
  const OfficialTourRibbon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF0A202), Color(0xFFFFCB4D)]),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: const Text(
        '★ Official CHT Plus Tour',
        style: TextStyle(color: Color(0xFF3D2A00), fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

DateTime? _parse(String ymd) => DateTime.tryParse(ymd);

/// "30 Oct – 31 Oct 2026", or one date for a day trip (the site's format).
String tourDates(Tour t) {
  final a = _parse(t.startDate);
  final b = _parse(t.endDate);
  if (a == null) return t.startDate;
  String fmt(DateTime d, {bool year = true}) => '${d.day} ${_months[d.month - 1]}${year ? ' ${d.year}' : ''}';
  if (b == null || t.endDate == t.startDate) return fmt(a);
  return '${fmt(a, year: false)} – ${fmt(b)}';
}

/// "2 days 1 night" / "Day trip".
String tourLength(Tour t) {
  final a = _parse(t.startDate);
  final b = _parse(t.endDate);
  if (a == null || b == null) return '';
  final days = b.difference(a).inDays + 1;
  if (days <= 1) return 'Day trip';
  final nights = days - 1;
  return '$days days $nights ${nights == 1 ? 'night' : 'nights'}';
}

String tourPrice(int price) {
  if (price <= 0) return 'Free';
  final s = price.toString();
  // 1,20,000 — the Bangladeshi grouping the site uses.
  if (s.length <= 3) return '৳$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '৳${parts.join(',')},$last3';
}

/// One tour in a list, like the site's TourCard.
class TourCardTile extends StatelessWidget {
  const TourCardTile({super.key, required this.tour, this.footer});

  final Tour tour;

  /// Extra badges under the card (status on "My tours" / "My trips").
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final full = tour.seatsLeft <= 0;
    const meta = TextStyle(fontSize: 12.5, color: AppColors.textSecondary);
    final card = AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/tours/${tour.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if ((tour.photoUrl ?? '').isNotEmpty)
                  AppNetworkImage(url: tour.photoUrl)
                else
                  Container(
                    color: AppColors.forestLight,
                    alignment: Alignment.center,
                    child: const Text('🏞️', style: TextStyle(fontSize: 40)),
                  ),
                if (tour.isOfficial) const Positioned(top: 8, left: 8, child: OfficialTourRibbon()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tour.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tour.isOfficial ? AppColors.forestDark : AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text('📍 ${tour.destination}', style: meta),
                Text('🗓️ ${tourDates(tour)} · ${tourLength(tour)}', style: meta),
                Row(
                  children: [
                    Flexible(child: Text('👤 ${tour.organizer.name}', style: meta, overflow: TextOverflow.ellipsis)),
                    VerifiedBadge(active: tour.organizer.blueBadge, size: 12),
                  ],
                ),
                const Divider(height: 18, color: AppColors.border),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tourPrice(tour.price),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.forestDark),
                      ),
                    ),
                    Text(
                      full ? 'Full' : '${tour.seatsLeft} seats left',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: full ? AppColors.red : AppColors.forest),
                    ),
                  ],
                ),
                if (footer != null) ...[const SizedBox(height: 8), footer!],
              ],
            ),
          ),
        ],
      ),
    );
    if (!tour.isOfficial) return card;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: officialTourGradient,
        borderRadius: BorderRadius.circular(AppRadius.card + 2),
        boxShadow: const [BoxShadow(color: Color(0x38F0A202), blurRadius: 22, offset: Offset(0, 6))],
      ),
      child: card,
    );
  }
}

/// Small coloured status label (`.badge`).
class TourBadge extends StatelessWidget {
  const TourBadge(this.label, {super.key, this.color = AppColors.forestDark, this.background = AppColors.forestLight});

  final String label;
  final Color color;
  final Color background;

  static TourBadge forBooking(String status) => switch (status) {
        'accepted' => const TourBadge('Confirmed'),
        'rejected' => const TourBadge('Declined', color: Color(0xFF9A6A00), background: Color(0xFFFFF3D6)),
        'cancelled' => const TourBadge('Cancelled', color: AppColors.red, background: Color(0xFFFDECEB)),
        _ => const TourBadge('Waiting for the organizer', color: Color(0xFF9A6A00), background: Color(0xFFFFF3D6)),
      };

  static TourBadge forTour(String status) => switch (status) {
        'approved' => const TourBadge('Live'),
        'rejected' => const TourBadge('Not approved', color: Color(0xFF9A6A00), background: Color(0xFFFFF3D6)),
        'cancelled' => const TourBadge('Cancelled', color: AppColors.red, background: Color(0xFFFDECEB)),
        _ => const TourBadge('Waiting for approval', color: Color(0xFF9A6A00), background: Color(0xFFFFF3D6)),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
