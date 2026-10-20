import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../models/donor.dart';

/// Who liked something, as on the site's `LikersBox`: a bordered list, each
/// row a small round photo and the name (with blue tick); tapping a row opens
/// that person's profile.
class LikersList extends StatelessWidget {
  const LikersList({super.key, required this.likers});

  final List<Liker> likers;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: likers.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final liker = likers[index];
          return InkWell(
            onTap: liker.id.isEmpty ? null : () => context.push('/u/${liker.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Avatar(url: liker.photoUrl, name: liker.name, size: 32, userId: liker.id),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      liker.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  VerifiedBadge(active: liker.blueBadge, size: 13),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
