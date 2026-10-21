import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/photo_crop_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';

/// Pick a new profile or cover photo, move / zoom it into place in the crop
/// editor, then upload it — used from the profile page and from Edit profile.
/// Nothing is uploaded unless the user taps "Update".
Future<void> changeProfilePhoto(BuildContext context, WidgetRef ref, {required bool cover}) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: cover ? 1800 : 900,
    imageQuality: 88,
  );
  if (picked == null || !context.mounted) return;

  final crop = await PhotoCropScreen.open(
    context,
    filePath: picked.path,
    aspect: cover ? 3 : 1,
    round: !cover,
    title: cover ? 'Adjust cover photo' : 'Adjust profile picture',
  );
  if (crop == null || !context.mounted) return;

  try {
    await AppDialogs.withBlockingProgress(context, () async {
      final repository = ref.read(meRepositoryProvider);
      if (cover) {
        await repository.uploadCoverPhoto(picked.path, crop: crop);
      } else {
        final url = await repository.uploadPhoto(picked.path, crop: crop);
        final user = ref.read(currentUserProvider);
        if (user != null) {
          await ref.read(authControllerProvider.notifier).updateLocalUser(user.copyWith(photoUrl: url));
        }
      }
    });
    ref.invalidate(meProfileProvider);
    if (context.mounted) AppSnackbar.success(context, 'Photo updated.');
  } on ApiException catch (error) {
    if (context.mounted) AppSnackbar.error(context, error.message);
  }
}

/// "📷 Change cover photo" pill on the profile cover, like the site's
/// `ProfileCover` button.
class ChangeCoverButton extends StatelessWidget {
  const ChangeCoverButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_camera_rounded, size: 15, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Change cover',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round camera button on the corner of the profile photo.
class ChangeAvatarButton extends StatelessWidget {
  const ChangeAvatarButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      shape: const CircleBorder(side: BorderSide(color: AppColors.surface, width: 2)),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(7),
          child: Icon(Icons.photo_camera_rounded, size: 18, color: AppColors.text),
        ),
      ),
    );
  }
}
