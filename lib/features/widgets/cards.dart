import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/utils/data_labels.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/common.dart';
import '../../models/biodata.dart';
import '../../models/catalog.dart';
import '../../models/doctor.dart';
import '../../models/donor.dart';
import '../../models/listing.dart';
import '../../models/service.dart';
import 'save_button.dart';

/// Emoji category icon in a soft circle, matching `CategoryIcon` on the site.
class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category, required this.onTap});

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.forestLight,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                (category.icon ?? '').isEmpty ? '📌' : category.icon!,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service, this.compact = false});

  final ServiceItem service;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final photo = service.allPhotos.isEmpty ? null : service.allPhotos.first;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/services/${service.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AppNetworkImage(
                url: photo,
                width: double.infinity,
                height: compact ? 108 : 140,
                placeholderIcon: Icons.handyman_outlined,
              ),
              if (service.paid)
                const Positioned(
                  top: 8,
                  left: 8,
                  child: StatusPill(
                    label: 'Sponsored',
                    color: AppColors.amber,
                    icon: Icons.bolt_rounded,
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: SaveButton(targetType: 'service', targetId: service.id),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.providerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                if (service.categoryName != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${service.categoryIcon ?? ''} ${service.categoryName}'.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                RatingStars(rating: service.rating, count: service.ratingCount, size: 13),
                if (service.locationLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          service.locationLabel,
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

class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final photo = listing.photos.isEmpty ? null : listing.photos.first;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/marketplace/listing/${listing.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AppNetworkImage(
                url: photo,
                width: double.infinity,
                height: 132,
                placeholderIcon: Icons.inventory_2_outlined,
              ),
              if (listing.paid)
                const Positioned(
                  top: 8,
                  left: 8,
                  child: StatusPill(
                    label: 'Promoted',
                    color: AppColors.amber,
                    icon: Icons.bolt_rounded,
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: SaveButton(
                  targetType: 'marketplace_listing',
                  targetId: listing.id,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      Fmt.taka(listing.price),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forestDark,
                      ),
                    ),
                    if (listing.negotiable) ...[
                      const SizedBox(width: 6),
                      const Text(
                        'Negotiable',
                        style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (listing.condition != null) ...[
                      StatusPill(
                        label: dataLabel(listing.condition),
                        color: AppColors.forest,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        listing.locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DonorCard extends StatelessWidget {
  const DonorCard({super.key, required this.donor});

  final Donor donor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/donors/${donor.id}'),
      child: Row(
        children: [
          // The photo opens the donor's CHT Plus profile; the rest of the card
          // opens the donor listing itself.
          GestureDetector(
            onTap: donor.userId == null
                ? null
                : () => context.push('/u/${donor.userId}'),
            child: Stack(
              children: [
                Avatar(url: donor.photoUrl, name: donor.name, size: 52),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      donor.bloodGroup ?? '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (donor.userId != null)
                  Positioned(
                    left: -1,
                    top: -1,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.forest,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  donor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  donor.locationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StatusPill(
                      label: donor.eligible ? 'Available' : 'Not yet available',
                      color: donor.eligible ? AppColors.forest : AppColors.textSecondary,
                      icon: donor.eligible
                          ? Icons.check_circle_outline
                          : Icons.schedule_rounded,
                    ),
                    if (donor.ratingCount > 0) ...[
                      const SizedBox(width: 8),
                      RatingStars(
                        rating: donor.rating,
                        count: donor.ratingCount,
                        size: 12,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class DoctorCard extends StatelessWidget {
  const DoctorCard({super.key, required this.doctor, this.compact = false});

  final DoctorSummary doctor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SizedBox(
        width: 132,
        child: AppCard(
          padding: const EdgeInsets.all(10),
          onTap: () => context.push('/doctors/${doctor.id}'),
          child: Column(
            children: [
              Avatar(url: doctor.photoUrl, name: doctor.name, size: 58),
              const SizedBox(height: 8),
              Text(
                doctor.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                doctor.specialty ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AppCard(
      onTap: () => context.push('/doctors/${doctor.id}'),
      child: Row(
        children: [
          Avatar(url: doctor.photoUrl, name: doctor.name, size: 54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                if ((doctor.specialty ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    doctor.specialty!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.forestDark),
                  ),
                ],
                if ((doctor.qualifications ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    doctor.qualifications!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.favorite_rounded, size: 16, color: AppColors.red),
              const SizedBox(height: 2),
              Text(
                '${doctor.likeCount}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
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
