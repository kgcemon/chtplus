import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/utils/data_labels.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/common.dart';
import '../../models/biodata.dart';
import '../../models/doctor.dart';
import '../../models/donor.dart';
import '../../models/listing.dart';
import '../../models/service.dart';
import 'save_button.dart';

/// A provider tile as the site's `ServiceCard` draws it: category chip (and
/// a Sponsored badge), avatar and name, a two-line description, area, then the
/// rating above the Call button. [compact] is the two-per-row phone size.
class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service, this.compact = false});

  final ServiceItem service;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final category = '${service.categoryIcon ?? ''} ${service.categoryName ?? ''}'.trim();
    final area = (service.area ?? '').isNotEmpty ? service.area! : service.locationLabel;
    final gap = compact ? 6.0 : 10.0;

    return Material(
      color: service.paid ? const Color(0xFFFFFAF0) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: service.paid ? const Color(0xFFF3D896) : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/services/${service.id}'),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (category.isNotEmpty)
                    Flexible(
                      child: _Badge(
                        label: category,
                        color: AppColors.textSecondary,
                        background: AppColors.forestLight,
                        weight: FontWeight.w500,
                        fontSize: compact ? 10 : 12,
                      ),
                    ),
                  const Spacer(),
                  if (service.paid)
                    const _Badge(
                      label: 'Sponsored',
                      color: Color(0xFF9A6700),
                      background: Color(0xFFFFF3D6),
                    ),
                ],
              ),
              SizedBox(height: gap),
              Row(
                children: [
                  Avatar(
                    url: service.photoUrl ?? (service.allPhotos.isEmpty ? null : service.allPhotos.first),
                    name: service.providerName,
                    size: compact ? 32 : 44,
                  ),
                  SizedBox(width: compact ? 6 : 10),
                  Expanded(
                    child: Text(
                      service.providerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 12.5 : 15.5,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (service.preview.isNotEmpty) ...[
                SizedBox(height: gap),
                Text(
                  service.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (area.isNotEmpty) ...[
                SizedBox(height: gap),
                Text(
                  '📍 $area',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 10.5 : 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              SizedBox(height: gap),
              const Divider(height: 1, color: AppColors.border),
              SizedBox(height: compact ? 8 : 10),
              RatingStars(
                rating: service.rating,
                count: service.ratingCount,
                size: compact ? 12 : 14,
              ),
              const SizedBox(height: 6),
              FilledButton(
                onPressed: () => Launchers.call(context, service.phone),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  minimumSize: const Size.fromHeight(32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Call'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A product tile as the site's `MarketplaceCard` draws it on a phone: 4:3
/// cover, category chip, title, condition and area, then the price above a
/// full-width outlined Call button. Sponsored listings get a warm tint.
class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final photo = listing.photos.isEmpty ? null : listing.photos.first;
    final category = '${listing.categoryIcon ?? ''} ${listing.categoryName ?? ''}'.trim();
    final area = (listing.area ?? '').isNotEmpty ? listing.area! : listing.locationLabel;

    return Material(
      color: listing.paid ? const Color(0xFFFFFAF0) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: listing.paid ? const Color(0xFFF3D896) : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/marketplace/listing/${listing.id}'),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: AppNetworkImage(
                      url: photo,
                      width: double.infinity,
                      borderRadius: BorderRadius.circular(10),
                      placeholderIcon: Icons.inventory_2_outlined,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: SaveButton(
                      targetType: 'marketplace_listing',
                      targetId: listing.id,
                      light: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (category.isNotEmpty)
                    Flexible(
                      child: _Badge(
                        label: category,
                        color: AppColors.textSecondary,
                        background: AppColors.forestLight,
                        weight: FontWeight.w500,
                      ),
                    ),
                  if (listing.paid) ...[
                    const SizedBox(width: 4),
                    const _Badge(
                      label: 'Sponsored',
                      color: Color(0xFF9A6700),
                      background: Color(0xFFFFF3D6),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                listing.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, height: 1.3, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (listing.condition != null) ...[
                    _Badge(
                      label: dataLabel(listing.condition),
                      color: AppColors.forestDark,
                      background: AppColors.forestLight,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      '📍 $area',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(height: 1, color: AppColors.border),
              ),
              Text(
                Fmt.taka(listing.price),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forestDark,
                ),
              ),
              const SizedBox(height: 5),
              OutlinedButton(
                onPressed: () => Launchers.call(context, listing.sellerPhone),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forest,
                  side: const BorderSide(color: AppColors.forest),
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  minimumSize: const Size.fromHeight(30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Call'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small rounded label (`.badge`, `.info-card-cat` on the site).
class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.background,
    this.weight = FontWeight.w700,
    this.fontSize = 9.5,
  });

  final String label;
  final Color color;
  final Color background;
  final FontWeight weight;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: fontSize, fontWeight: weight, color: color),
      ),
    );
  }
}

/// A donor row as the site draws it: photo, blood group (green when they can
/// donate, red when they gave recently), name and area, then a Call button or
/// a "Donated recently" note above the like and review counts. The border
/// and tint follow eligibility too.
class DonorCard extends StatelessWidget {
  const DonorCard({super.key, required this.donor});

  final Donor donor;

  static const _green = Color(0xFF1F9E57);

  @override
  Widget build(BuildContext context) {
    final eligible = donor.eligible;
    final area = (donor.area ?? '').isNotEmpty ? donor.area! : donor.locationLabel;

    return Material(
      color: eligible ? AppColors.surface : const Color(0xFFFFF6F5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          width: 2,
          color: eligible ? const Color(0xCC2F9E57) : const Color(0xCCD0342C),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/donors/${donor.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (donor.photoUrl ?? '').isEmpty
                    ? Container(
                        width: 68,
                        height: 68,
                        color: AppColors.forestLight,
                        alignment: Alignment.center,
                        child: Text(
                          donor.name.isEmpty ? '?' : donor.name.characters.first,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forestDark,
                          ),
                        ),
                      )
                    : AppNetworkImage(
                        url: donor.photoUrl,
                        width: 68,
                        height: 68,
                        placeholderIcon: Icons.person_outline,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donor.bloodGroup ?? '?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: eligible ? _green : AppColors.red,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      donor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '📍 $area',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (eligible)
                    FilledButton(
                      onPressed: () => Launchers.call(context, donor.phone),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Call'),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Donated recently',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _CountPill(
                        icon: donor.likedByMe ? '❤️' : '🤍',
                        count: donor.likeCount,
                        color: AppColors.red,
                        background: const Color(0xFFFFF5F4),
                        border: const Color(0xFFF7D9D6),
                      ),
                      const SizedBox(width: 6),
                      _CountPill(
                        icon: '💬',
                        count: donor.ratingCount,
                        color: AppColors.textSecondary,
                        background: AppColors.surface,
                        border: AppColors.border,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small rounded count badge (likes, reviews), like `.donor-like-btn`.
class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.icon,
    required this.count,
    required this.color,
    required this.background,
    required this.border,
  });

  final String icon;
  final int count;
  final Color color;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        '$icon $count',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// A doctor tile as the site's `DoctorCard` draws it: avatar with name and
/// qualifications, the specialty, then the love count beside a "View profile"
/// button. [compact] is the two-per-row phone size.
class DoctorCard extends StatelessWidget {
  const DoctorCard({super.key, required this.doctor, this.compact = false});

  final DoctorSummary doctor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    void open() => context.push('/doctors/${doctor.id}');
    final gap = compact ? 6.0 : 10.0;

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Avatar(url: doctor.photoUrl, name: doctor.name, size: compact ? 32 : 44),
                  SizedBox(width: compact ? 6 : 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 12.5 : 15.5,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if ((doctor.qualifications ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              doctor.qualifications!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 10.5 : 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if ((doctor.specialty ?? '').isNotEmpty) ...[
                SizedBox(height: gap),
                Text(
                  doctor.specialty!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              SizedBox(height: gap),
              const Divider(height: 1, color: AppColors.border),
              SizedBox(height: compact ? 8 : 10),
              Align(
                alignment: Alignment.centerLeft,
                child: _CountPill(
                  icon: doctor.likedByMe ? '❤️' : '🤍',
                  count: doctor.likeCount,
                  color: AppColors.red,
                  background: const Color(0xFFFFF5F4),
                  border: const Color(0xFFF7D9D6),
                ),
              ),
              const SizedBox(height: 6),
              FilledButton(
                onPressed: open,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  minimumSize: const Size.fromHeight(32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('View profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BiodataCard extends StatelessWidget {
  const BiodataCard({super.key, required this.biodata});

  final Biodata biodata;

  @override
  Widget build(BuildContext context) {
    final photo = biodata.photos.isEmpty ? null : biodata.photos.first;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/biodata/view/${biodata.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AppNetworkImage(
                url: photo,
                width: double.infinity,
                height: 138,
                placeholderIcon: Icons.person_outline,
              ),
              Positioned(
                top: 8,
                left: 8,
                child: StatusPill(
                  label: dataLabel(biodata.gender),
                  color: biodata.isBride ? const Color(0xFFC2185B) : AppColors.forest,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: SaveButton(targetType: 'biodata', targetId: biodata.id),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  biodata.biodataNo ?? 'Biodata',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forestDark,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (biodata.age != null)
                      _Chip(label: '${biodata.age} yrs'),
                    if ((biodata.height ?? '').isNotEmpty)
                      _Chip(label: biodata.height!),
                    if ((biodata.maritalStatus ?? '').isNotEmpty)
                      _Chip(label: dataLabel(biodata.maritalStatus)),
                  ],
                ),
                if ((biodata.profession ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    biodata.profession!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
                if ((biodata.area ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          biodata.area!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.forestLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.forestDark,
        ),
      ),
    );
  }
}
