
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../widgets/form_fields.dart';
import '../widgets/site_scaffold.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _bio = TextEditingController();
  final _currentCity = TextEditingController();
  final _hometown = TextEditingController();

  String? _area;
  String? _relationshipStatus;
  bool _prefilled = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _bio.dispose();
    _currentCity.dispose();
    _hometown.dispose();
    super.dispose();
  }

  void _prefill(MeProfile me) {
    if (_prefilled) return;
    _prefilled = true;
    _name.text = me.name;
    _email.text = me.email;
    _phone.text = me.phone ?? '';
    _bio.text = me.bio ?? '';
    _currentCity.text = me.currentCity ?? '';
    _hometown.text = me.hometown ?? '';
    _area = me.area;
    _relationshipStatus = me.relationshipStatus;
  }

  Future<void> _pickPhoto({required bool cover}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: cover ? 1800 : 900,
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;

    try {
      await AppDialogs.withBlockingProgress(context, () async {
        final repository = ref.read(meRepositoryProvider);
        if (cover) {
          await repository.uploadCoverPhoto(picked.path);
        } else {
          final url = await repository.uploadPhoto(picked.path);
          final user = ref.read(currentUserProvider);
          if (user != null) {
            await ref
                .read(authControllerProvider.notifier)
                .updateLocalUser(user.copyWith(photoUrl: url));
          }
        }
      });
      ref.invalidate(meProfileProvider);
      if (mounted) AppSnackbar.success(context, 'Photo updated.');
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final repository = ref.read(meRepositoryProvider);
      final user = await repository.updateBasics(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        area: _area ?? '',
      );
      await repository.updateDetails(
        bio: _bio.text.trim(),
        currentCity: _currentCity.text.trim(),
        hometown: _hometown.text.trim(),
        relationshipStatus: _relationshipStatus,
      );

      final current = ref.read(currentUserProvider);
      await ref.read(authControllerProvider.notifier).updateLocalUser(
            current == null
                ? user
                : current.copyWith(
                    name: user.name,
                    email: user.email,
                    phone: user.phone,
                    area: user.area,
                    photoUrl: user.photoUrl,
                  ),
          );
      ref.invalidate(meProfileProvider);
      if (!mounted) return;
      AppSnackbar.success(context, 'Profile saved.');
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(meProfileProvider);
    final me = profile.valueOrNull;
    if (me != null) _prefill(me);

    return SiteScaffold(
      title: 'Edit profile',
      body: profile.isLoading || me == null
          ? const AppLoader()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  _PhotoHeader(
                    me: me,
                    onPickAvatar: () => _pickPhoto(cover: false),
                    onPickCover: () => _pickPhoto(cover: true),
                  ),
                  const SizedBox(height: 22),
                  FormRowField(
                    label: 'Full name',
                    required: true,
                    child: TextFormField(
                      controller: _name,
                      maxLength: 150,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(counterText: ''),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Enter your name' : null,
                    ),
                  ),
                  FormRowField(
                    label: 'Email address',
                    required: true,
                    child: TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 190,
                      decoration: const InputDecoration(counterText: ''),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) return 'Enter your email address';
                        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
                          return 'That email address does not look right';
                        }
                        return null;
                      },
                    ),
                  ),
                  FormRowField(
                    label: 'Mobile number',
                    child: TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      maxLength: 30,
                      decoration: const InputDecoration(
                        hintText: '01XXXXXXXXX',
                        counterText: '',
                      ),
                    ),
                  ),
                  FormRowField(
                    label: 'Area',
                    child: UpazilaPicker(
                      // The account stores a free-text area; any of the four
                      // districts' thanas can be picked here.
                      districtName: me.donor?.district ?? 'খাগড়াছড়ি',
                      value: _area,
                      onChanged: (value) => setState(() => _area = value),
                    ),
                  ),
                  FormRowField(
                    label: 'Bio',
                    hint: 'A short line about yourself, shown on your public profile.',
                    child: TextFormField(
                      controller: _bio,
                      maxLines: 3,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const Divider(height: 28),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      'About you',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Each of these has its own visibility setting below.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  _PrivacyField(
                    label: 'Current city',
                    field: 'currentCity',
                    privacy: me.currentCityPrivacy,
                    child: TextFormField(
                      controller: _currentCity,
                      maxLength: 150,
                      decoration: const InputDecoration(counterText: ''),
                    ),
                  ),
                  _PrivacyField(
                    label: 'Hometown',
                    field: 'hometown',
                    privacy: me.hometownPrivacy,
                    child: TextFormField(
                      controller: _hometown,
                      maxLength: 150,
                      decoration: const InputDecoration(counterText: ''),
                    ),
                  ),
                  _PrivacyField(
                    label: 'Relationship status',
                    field: 'relationshipStatus',
                    privacy: me.relationshipStatusPrivacy,
                    child: AppDropdown(
                      value: _relationshipStatus,
                      options: const [
                        'single',
                        'in_relationship',
                        'married',
                        'complicated',
                      ],
                      includeEmpty: true,
                      emptyLabel: 'Not specified',
                      hint: 'Select',
                      labelBuilder: Fmt.relationshipLabel,
                      onChanged: (value) =>
                          setState(() => _relationshipStatus = value),
                    ),
                  ),
                  const Divider(height: 28),
                  _WorkEducationEditor(me: me),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save profile'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({
    required this.me,
    required this.onPickAvatar,
    required this.onPickCover,
  });

  final MeProfile me;
  final VoidCallback onPickAvatar;
  final VoidCallback onPickCover;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 186,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            bottom: 46,
            child: GestureDetector(
              onTap: onPickCover,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    url: me.coverPhotoUrl,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    placeholderIcon: Icons.landscape_outlined,
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: _EditBadge(label: 'Change cover'),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 0,
            child: GestureDetector(
              onTap: onPickAvatar,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bg, width: 4),
                    ),
                    child: Avatar(url: me.photoUrl, name: me.name, size: 84),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.forest,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bg, width: 2),
                      ),
                      child: const Icon(Icons.photo_camera_rounded,
                          size: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditBadge extends StatelessWidget {
  const _EditBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_camera_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A field plus its own public / followers / only-me selector, saved straight
/// away because privacy has its own endpoint.
class _PrivacyField extends ConsumerStatefulWidget {
  const _PrivacyField({
    required this.label,
    required this.field,
    required this.privacy,
    required this.child,
  });

  final String label;
  final String field;
  final String privacy;
  final Widget child;

  @override
  ConsumerState<_PrivacyField> createState() => _PrivacyFieldState();
}

class _PrivacyFieldState extends ConsumerState<_PrivacyField> {
  late String _privacy = widget.privacy;

  Future<void> _update(String value) async {
    final previous = _privacy;
    setState(() => _privacy = value);
    try {
      await ref
          .read(meRepositoryProvider)
          .updatePrivacy(field: widget.field, privacy: value);
      ref.invalidate(meProfileProvider);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _privacy = previous);
        AppSnackbar.error(context, error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                initialValue: _privacy,
                onSelected: _update,
                tooltip: 'Who can see this',
                itemBuilder: (context) => [
                  for (final option in ['public', 'followers', 'only_me'])
                    PopupMenuItem(
                      value: option,
                      child: Text(Fmt.privacyLabel(option)),
                    ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        switch (_privacy) {
                          'followers' => Icons.group_outlined,
                          'only_me' => Icons.lock_outline_rounded,
                          _ => Icons.public_rounded,
                        },
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        Fmt.privacyLabel(_privacy),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Icon(Icons.expand_more_rounded,
                          size: 15, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          widget.child,
        ],
      ),
    );
  }
}

class _WorkEducationEditor extends ConsumerWidget {
  const _WorkEducationEditor({required this.me});

  final MeProfile me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Work',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _addWork(context, ref),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Add'),
            ),
          ],
        ),
        if (me.work.isEmpty)
          const Text(
            'No work history added.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        for (final entry in me.work)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.work_outline_rounded, size: 20),
            title: Text(
              entry.company,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              [
                if ((entry.position ?? '').isNotEmpty) entry.position!,
                if (entry.isCurrent) 'Current',
              ].join(' · '),
            ),
            trailing: IconButton(
              onPressed: () async {
                try {
                  await ref.read(meRepositoryProvider).deleteWork(entry.id);
                  ref.invalidate(meProfileProvider);
                } on ApiException catch (error) {
                  if (context.mounted) AppSnackbar.error(context, error.message);
                }
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
              color: AppColors.red,
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text(
              'Education',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _addEducation(context, ref),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Add'),
            ),
          ],
        ),
        if (me.education.isEmpty)
          const Text(
            'No education added.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        for (final entry in me.education)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.school_outlined, size: 20),
            title: Text(
              entry.institution,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              [
                entry.levelLabel,
                if ((entry.fieldOfStudy ?? '').isNotEmpty) entry.fieldOfStudy!,
                if ((entry.passingYear ?? '').isNotEmpty) entry.passingYear!,
              ].join(' · '),
            ),
            trailing: IconButton(
              onPressed: () async {
                try {
                  await ref.read(meRepositoryProvider).deleteEducation(entry.id);
                  ref.invalidate(meProfileProvider);
                } on ApiException catch (error) {
                  if (context.mounted) AppSnackbar.error(context, error.message);
                }
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
              color: AppColors.red,
            ),
          ),
      ],
    );
  }

  Future<void> _addWork(BuildContext context, WidgetRef ref) async {
    final company = await AppDialogs.prompt(
      context,
      title: 'Company or organization',
      hint: 'e.g. Khagrachari Sadar Hospital',
      confirmLabel: 'Next',
    );
    if (company == null || company.isEmpty || !context.mounted) return;

    final position = await AppDialogs.prompt(
      context,
      title: 'Your position',
      hint: 'e.g. Senior technician',
      confirmLabel: 'Add',
    );
    try {
      await ref.read(meRepositoryProvider).addWork(
            company: company,
            position: position,
            isCurrent: true,
          );
      ref.invalidate(meProfileProvider);
    } on ApiException catch (error) {
      if (context.mounted) AppSnackbar.error(context, error.message);
    }
  }

  Future<void> _addEducation(BuildContext context, WidgetRef ref) async {
    final institution = await AppDialogs.prompt(
      context,
      title: 'Institution',
      hint: 'e.g. Khagrachari Government College',
      confirmLabel: 'Next',
    );
    if (institution == null || institution.isEmpty || !context.mounted) return;

    final year = await AppDialogs.prompt(
      context,
      title: 'Passing year',
      hint: 'e.g. 2018',
      keyboardType: TextInputType.number,
      confirmLabel: 'Add',
    );
    try {
      await ref.read(meRepositoryProvider).addEducation(
            institution: institution,
            passingYear: year,
          );
      ref.invalidate(meProfileProvider);
    } on ApiException catch (error) {
      if (context.mounted) AppSnackbar.error(context, error.message);
    }
  }
}
