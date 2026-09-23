import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../core/utils/data_labels.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../providers/catalog_providers.dart';

/// Label + field, the layout every form in the app uses.
class FormRowField extends StatelessWidget {
  const FormRowField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.hint,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? hint;

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
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              if (required)
                const Text(' *', style: TextStyle(fontSize: 13, color: AppColors.red)),
            ],
          ),
          const SizedBox(height: 6),
          child,
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                hint!,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dropdown whose options are stored strings but displayed through
/// [dataLabel], so Bengali-stored values read in English.
class AppDropdown extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint = 'Select',
    this.includeEmpty = false,
    this.emptyLabel = 'Any',
    this.labelBuilder,
  });

  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String hint;
  final bool includeEmpty;
  final String emptyLabel;
  final String Function(String)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    // A value no longer present in the list would make the dropdown assert.
    final safeValue = value != null && options.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      hint: Text(hint, style: const TextStyle(fontSize: 14)),
      icon: const Icon(Icons.expand_more_rounded),
      style: const TextStyle(fontSize: 14, color: AppColors.text),
      items: [
        if (includeEmpty)
          DropdownMenuItem<String>(
            value: null,
            child: Text(emptyLabel, style: const TextStyle(fontSize: 14)),
          ),
        for (final option in options)
          DropdownMenuItem<String>(
            value: option,
            child: Text(
              labelBuilder?.call(option) ?? dataLabel(option),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// District picker backed by `/api/locations/districts`. The value is the
/// stored (Bengali) district name, which is what listings are filtered by.
class DistrictPicker extends ConsumerWidget {
  const DistrictPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.includeEmpty = true,
    this.emptyLabel = 'All districts',
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool includeEmpty;
  final String emptyLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final districts = ref.watch(districtsProvider);
    return districts.when(
      loading: () => const _FieldPlaceholder(label: 'Loading districts…'),
      error: (_, __) => const _FieldPlaceholder(label: 'Districts unavailable'),
      data: (items) => AppDropdown(
        value: value,
        options: items.map((d) => d.filterValue).toList(),
        includeEmpty: includeEmpty,
        emptyLabel: emptyLabel,
        hint: 'Choose a district',
        labelBuilder: (option) =>
            items.firstWhere((d) => d.filterValue == option).label,
        onChanged: onChanged,
      ),
    );
  }
}

/// Upazila (thana) picker for the currently selected district.
class UpazilaPicker extends ConsumerWidget {
  const UpazilaPicker({
    super.key,
    required this.districtName,
    required this.value,
    required this.onChanged,
    this.includeEmpty = true,
    this.emptyLabel = 'All areas',
  });

  final String? districtName;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool includeEmpty;
  final String emptyLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (districtName == null || districtName!.isEmpty) {
      return const _FieldPlaceholder(label: 'Choose a district first');
    }
    final upazilas = ref.watch(upazilasByDistrictNameProvider(districtName));
    return upazilas.when(
      loading: () => const _FieldPlaceholder(label: 'Loading areas…'),
      error: (_, __) => const _FieldPlaceholder(label: 'Areas unavailable'),
      data: (items) => AppDropdown(
        value: value,
        options: items.map((u) => u.filterValue).toList(),
        includeEmpty: includeEmpty,
        emptyLabel: emptyLabel,
        hint: 'Choose an area',
        labelBuilder: (option) =>
            items.firstWhere((u) => u.filterValue == option).label,
        onChanged: onChanged,
      ),
    );
  }
}

class _FieldPlaceholder extends StatelessWidget {
  const _FieldPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.field),
        color: AppColors.surface,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
    );
  }
}

/// Date field that opens the platform date picker and hands back `yyyy-MM-dd`.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'Select a date',
    this.firstDate,
    this.lastDate,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final String hint;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.field),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(value ?? '') ?? (lastDate ?? now),
          firstDate: firstDate ?? DateTime(1940),
          lastDate: lastDate ?? now,
        );
        if (picked != null) {
          onChanged('${picked.year.toString().padLeft(4, '0')}-'
              '${picked.month.toString().padLeft(2, '0')}-'
              '${picked.day.toString().padLeft(2, '0')}');
        }
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.field),
          color: AppColors.surface,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                (value ?? '').isEmpty ? hint : value!,
                style: TextStyle(
                  fontSize: 14,
                  color: (value ?? '').isEmpty ? AppColors.textSecondary : AppColors.text,
                ),
              ),
            ),
            const Icon(Icons.calendar_today_rounded,
                size: 17, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Picks photos from the gallery or camera and shows the chosen set.
///
/// Images are downscaled and re-encoded on the device before upload, which
/// keeps uploads quick on a slow connection — the server compresses again.
class PhotoPickerField extends StatelessWidget {
  const PhotoPickerField({
    super.key,
    required this.maxPhotos,
    required this.existingUrls,
    required this.newPaths,
    required this.onExistingRemoved,
    required this.onNewPathsChanged,
  });

  final int maxPhotos;
  final List<String> existingUrls;
  final List<String> newPaths;
  final ValueChanged<String> onExistingRemoved;
  final ValueChanged<List<String>> onNewPathsChanged;

  int get _total => existingUrls.length + newPaths.length;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final remaining = maxPhotos - _total;
    if (remaining <= 0) {
      AppSnackbar.show(context, 'You can add at most $maxPhotos photos.');
      return;
    }
    final picker = ImagePicker();
    try {
      if (source == ImageSource.camera) {
        final shot = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 85,
        );
        if (shot != null) onNewPathsChanged([...newPaths, shot.path]);
        return;
      }
      final picked = await picker.pickMultiImage(maxWidth: 1600, imageQuality: 85);
      if (picked.isEmpty) return;
      onNewPathsChanged([
        ...newPaths,
        ...picked.take(remaining).map((f) => f.path),
      ]);
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.error(context, 'Could not open the photo picker.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_total > 0)
          SizedBox(
            height: 82,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final url in existingUrls)
                  _Thumb(
                    child: AppNetworkImage(url: url, width: 78, height: 78),
                    onRemove: () => onExistingRemoved(url),
                  ),
                for (final path in newPaths)
                  _Thumb(
                    child: Image.file(
                      File(path),
                      width: 78,
                      height: 78,
                      fit: BoxFit.cover,
                      cacheWidth: 200,
                      errorBuilder: (_, __, ___) => Container(
                        width: 78,
                        height: 78,
                        color: AppColors.forestLight,
                        child: const Icon(Icons.image_outlined, color: AppColors.forest),
                      ),
                    ),
                    onRemove: () =>
                        onNewPathsChanged(newPaths.where((p) => p != path).toList()),
                  ),
              ],
            ),
          ),
        if (_total > 0) const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _pick(context, ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Gallery'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => _pick(context, ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Camera'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
            ),
            const Spacer(),
            Text(
              '$_total / $maxPhotos',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: child),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 13, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
