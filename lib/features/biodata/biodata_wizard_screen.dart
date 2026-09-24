import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/utils/data_labels.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/biodata_repository.dart';
import '../../models/biodata.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/home_provider.dart';
import '../widgets/form_fields.dart';
import '../widgets/site_scaffold.dart';
import '../widgets/wizard_parts.dart';

/// Four-step matrimony biodata wizard, collecting the same field set as the
/// website's own submission form.
class BiodataWizardScreen extends ConsumerStatefulWidget {
  const BiodataWizardScreen({super.key, this.existing});

  final Biodata? existing;

  @override
  ConsumerState<BiodataWizardScreen> createState() => _BiodataWizardScreenState();
}

class _BiodataWizardScreenState extends ConsumerState<BiodataWizardScreen> {
  static const _steps = [
    'General Information',
    'Education & Family',
    'Life Partner & Contact',
    'Preview',
  ];

  late final BiodataDraft _draft = widget.existing == null
      ? BiodataDraft()
      : BiodataDraft.fromBiodata(widget.existing!);

  int _step = 0;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  Future<void> _submit() async {
    final problem = _draft.validate();
    if (problem != null) {
      AppSnackbar.error(context, problem);
      return;
    }

    setState(() => _busy = true);
    try {
      final repository = ref.read(biodataRepositoryProvider);
      if (_isEdit) {
        await repository.update(widget.existing!.id, _draft);
      } else {
        await repository.create(_draft);
      }

      ref.invalidate(myBiodataProvider);
      ref.invalidate(biodataListProvider);
      ref.invalidate(homeFeedProvider);
      if (!mounted) return;

      await AppDialogs.confirm(
        context,
        title: _isEdit ? 'Biodata updated' : 'Biodata submitted',
        message: _isEdit
            ? 'Your changes were saved. An admin verifies every edit before it is published.'
            : 'Thanks! An admin will verify your biodata before it appears in the matrimony list. You can track it under "My biodata".',
        confirmLabel: 'Done',
        cancelLabel: 'Close',
      );
      if (mounted) context.pop(true);
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
      return;
    }
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await AppDialogs.confirm(
          context,
          title: 'Discard this biodata?',
          message: 'Anything you have filled in will be lost.',
          confirmLabel: 'Discard',
          cancelLabel: 'Keep editing',
          destructive: true,
        );
        if (leave && context.mounted) context.pop();
      },
      child: SiteScaffold(
          title: _isEdit ? 'Edit biodata' : 'Submit biodata',
          subtitle: 'Fill in your details step by step; it is published after admin review',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: WizardSteps(labels: _steps, current: _step),
            ),
            Expanded(
              child: switch (_step) {
                0 => _GeneralStep(draft: _draft, onChanged: () => setState(() {})),
                1 => _EducationFamilyStep(draft: _draft, onChanged: () => setState(() {})),
                2 => _PartnerContactStep(draft: _draft, onChanged: () => setState(() {})),
                _ => _ReviewStep(draft: _draft, onChanged: () => setState(() {})),
              },
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    OutlinedButton(
                      onPressed: _busy ? null : () => setState(() => _step--),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: const Text('← Previous step'),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _next,
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _step == _steps.length - 1
                                  ? (_isEdit ? 'Save changes' : 'Submit for review')
                                  : 'Next step →',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Step 1 -----------------------------------------------------------------

class _GeneralStep extends ConsumerWidget {
  const _GeneralStep({required this.draft, required this.onChanged});

  final BiodataDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        FormRowField(
          label: 'Biodata type',
          required: true,
          child: AppDropdown(
            value: draft.biodataType,
            options: BiodataOptions.types,
            onChanged: (value) {
              draft.biodataType = value ?? draft.biodataType;
              onChanged();
            },
          ),
        ),
        FormRowField(
          label: 'Marital status',
          required: true,
          child: AppDropdown(
            value: draft.maritalStatus,
            options: BiodataOptions.maritalStatuses,
            onChanged: (value) {
              draft.maritalStatus = value ?? draft.maritalStatus;
              onChanged();
            },
          ),
        ),
        FormRowField(
          label: 'Date of birth',
          required: true,
          child: DateField(
            value: draft.dateOfBirth,
            lastDate: DateTime.now(),
            onChanged: (value) {
              draft.dateOfBirth = value;
              onChanged();
            },
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowField(
                label: 'Height',
                required: true,
                child: AppDropdown(
                  value: draft.height.isEmpty ? null : draft.height,
                  options: BiodataOptions.heights(),
                  hint: 'Select',
                  onChanged: (value) {
                    draft.height = value ?? '';
                    onChanged();
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FormRowField(
                label: 'Blood group',
                required: true,
                child: AppDropdown(
                  value: draft.bloodGroup.isEmpty ? null : draft.bloodGroup,
                  options: BiodataOptions.bloodGroups,
                  hint: 'Select',
                  onChanged: (value) {
                    draft.bloodGroup = value ?? '';
                    onChanged();
                  },
                ),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowField(
                label: 'Skin tone',
                required: true,
                child: AppDropdown(
                  value: draft.skinTone.isEmpty ? null : draft.skinTone,
                  options: BiodataOptions.skinTones,
                  hint: 'Select',
                  onChanged: (value) {
                    draft.skinTone = value ?? '';
                    onChanged();
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FormRowField(
                label: 'Religion',
                child: AppDropdown(
                  value: draft.religion.isEmpty ? null : draft.religion,
                  options: BiodataOptions.religions,
                  includeEmpty: true,
                  emptyLabel: 'Not specified',
                  hint: 'Select',
                  onChanged: (value) {
                    draft.religion = value ?? '';
                    onChanged();
                  },
                ),
              ),
            ),
          ],
        ),
        FormRowField(
          label: 'Profession type',
          required: true,
          child: AppDropdown(
            value: draft.professionType,
            options: BiodataOptions.professionTypes,
            onChanged: (value) {
              draft.professionType = value ?? draft.professionType;
              onChanged();
            },
          ),
        ),
        FormRowField(
          label: 'Profession',
          required: true,
          child: TextFormField(
            initialValue: draft.profession,
            maxLength: 150,
            decoration: const InputDecoration(
              hintText: 'e.g. Secondary school teacher',
              counterText: '',
            ),
            onChanged: (value) => draft.profession = value.trim(),
          ),
        ),
        const Divider(height: 32),
        FormRowField(
          label: 'Permanent district',
          required: true,
          child: DistrictPicker(
            value: draft.permanentDistrict.isEmpty ? null : draft.permanentDistrict,
            includeEmpty: false,
            onChanged: (value) {
              draft.permanentDistrict = value ?? '';
              draft.permanentUpazila = '';
              onChanged();
            },
          ),
        ),
        FormRowField(
          label: 'Permanent upazila',
          child: UpazilaPicker(
            districtName:
                draft.permanentDistrict.isEmpty ? null : draft.permanentDistrict,
            value: draft.permanentUpazila.isEmpty ? null : draft.permanentUpazila,
            includeEmpty: false,
            onChanged: (value) {
              draft.permanentUpazila = value ?? '';
              onChanged();
            },
          ),
        ),
        FormRowField(
          label: 'Current district',
          required: true,
          child: DistrictPicker(
            value: draft.currentDistrict.isEmpty ? null : draft.currentDistrict,
            includeEmpty: false,
            onChanged: (value) {
              draft.currentDistrict = value ?? '';
              draft.currentUpazila = '';
              onChanged();
            },
          ),
        ),
        FormRowField(
          label: 'Current upazila',
          child: UpazilaPicker(
            districtName: draft.currentDistrict.isEmpty ? null : draft.currentDistrict,
            value: draft.currentUpazila.isEmpty ? null : draft.currentUpazila,
            includeEmpty: false,
            onChanged: (value) {
              draft.currentUpazila = value ?? '';
              onChanged();
            },
          ),
        ),
        FormRowField(
          label: 'Current address',
          required: true,
          child: TextFormField(
            initialValue: draft.currentAddress,
            maxLength: 255,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Village / road, area',
              counterText: '',
            ),
            onChanged: (value) => draft.currentAddress = value.trim(),
          ),
        ),
        FormRowField(
          label: 'Photos',
          hint: 'Up to ${BiodataOptions.maxPhotos} photos. Admins verify them before publishing.',
          child: PhotoPickerField(
            maxPhotos: BiodataOptions.maxPhotos,
            existingUrls: draft.keepPhotoUrls,
            newPaths: draft.newPhotoPaths,
            onExistingRemoved: (url) {
              draft.keepPhotoUrls =
                  draft.keepPhotoUrls.where((u) => u != url).toList();
              onChanged();
            },
            onNewPathsChanged: (paths) {
              draft.newPhotoPaths = paths;
              onChanged();
            },
          ),
        ),
      ],
    );
  }
}

// --- Step 2 -----------------------------------------------------------------

class _EducationFamilyStep extends StatelessWidget {
  const _EducationFamilyStep({required this.draft, required this.onChanged});

  final BiodataDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        const _StepTitle(
          title: 'Education',
          subtitle: 'Each level only opens once the one below it is passed.',
        ),
        FormRowField(
          label: 'Education medium',
          child: AppDropdown(
            value: draft.educationMedium.isEmpty ? null : draft.educationMedium,
            options: BiodataOptions.educationMediums,
            includeEmpty: true,
            emptyLabel: 'Not specified',
            hint: 'Select',
            onChanged: (value) {
              draft.educationMedium = value ?? '';
              onChanged();
            },
          ),
        ),
        _PassedToggle(
          label: 'Passed SSC',
          value: draft.sscPassed,
          onChanged: (value) {
            draft.sscPassed = value;
            if (!value) {
              draft.hscPassed = false;
              draft.graduationPassed = false;
              draft.postgraduationPassed = false;
            }
            onChanged();
          },
        ),
        if (draft.sscPassed) ...[
          _YearAndText(
            yearLabel: 'SSC year',
            year: draft.sscYear,
            onYear: (value) {
              draft.sscYear = value ?? '';
              onChanged();
            },
            textLabel: 'SSC institution',
            text: draft.sscInstitution,
            onText: (value) => draft.sscInstitution = value,
          ),
          FormRowField(
            label: 'SSC group',
            child: AppDropdown(
              value: draft.sscGroup.isEmpty ? null : draft.sscGroup,
              options: BiodataOptions.educationGroups,
              includeEmpty: true,
              emptyLabel: 'Not specified',
              hint: 'Select',
              onChanged: (value) {
                draft.sscGroup = value ?? '';
                onChanged();
              },
            ),
          ),
          _PassedToggle(
            label: 'Passed HSC',
            value: draft.hscPassed,
            onChanged: (value) {
              draft.hscPassed = value;
              if (!value) {
                draft.graduationPassed = false;
                draft.postgraduationPassed = false;
              }
              onChanged();
            },
          ),
        ],
        if (draft.hscPassed) ...[
          _YearAndText(
            yearLabel: 'HSC year',
            year: draft.hscYear,
            onYear: (value) {
              draft.hscYear = value ?? '';
              onChanged();
            },
            textLabel: 'HSC institution',
            text: draft.hscInstitution,
            onText: (value) => draft.hscInstitution = value,
          ),
          FormRowField(
            label: 'HSC group',
            child: AppDropdown(
              value: draft.hscGroup.isEmpty ? null : draft.hscGroup,
              options: BiodataOptions.educationGroups,
              includeEmpty: true,
              emptyLabel: 'Not specified',
              hint: 'Select',
              onChanged: (value) {
                draft.hscGroup = value ?? '';
                onChanged();
              },
            ),
          ),
          _PassedToggle(
            label: 'Completed graduation',
            value: draft.graduationPassed,
            onChanged: (value) {
              draft.graduationPassed = value;
              if (!value) draft.postgraduationPassed = false;
              onChanged();
            },
          ),
        ],
        if (draft.graduationPassed) ...[
          FormRowField(
            label: 'Graduation institution',
            required: true,
            child: TextFormField(
              initialValue: draft.institutionName,
              maxLength: 200,
              decoration: const InputDecoration(counterText: ''),
              onChanged: (value) => draft.institutionName = value.trim(),
            ),
          ),
          _YearAndText(
            yearLabel: 'Graduation year',
            year: draft.graduationYear,
            onYear: (value) {
              draft.graduationYear = value ?? '';
              onChanged();
            },
            textLabel: 'Department / degree',
            text: draft.graduationDepartment,
            onText: (value) => draft.graduationDepartment = value,
            required: true,
          ),
          _PassedToggle(
            label: 'Completed post-graduation',
            value: draft.postgraduationPassed,
            onChanged: (value) {
              draft.postgraduationPassed = value;
              onChanged();
            },
          ),
        ],
        if (draft.postgraduationPassed) ...[
          FormRowField(
            label: 'Post-graduation institution',
            required: true,
            child: TextFormField(
              initialValue: draft.postgraduationInstitution,
              maxLength: 200,
              decoration: const InputDecoration(counterText: ''),
              onChanged: (value) => draft.postgraduationInstitution = value.trim(),
            ),
          ),
          _YearAndText(
            yearLabel: 'Post-graduation year',
            year: draft.postgraduationYear,
            onYear: (value) {
              draft.postgraduationYear = value ?? '';
              onChanged();
            },
            textLabel: 'Department / degree',
            text: draft.postgraduationDepartment,
            onText: (value) => draft.postgraduationDepartment = value,
            required: true,
          ),
        ],
        const Divider(height: 32),
        const _StepTitle(title: 'Family'),
        FormRowField(
          label: "Father's name",
          required: true,
          child: TextFormField(
            initialValue: draft.fatherName,
            maxLength: 150,
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) => draft.fatherName = value.trim(),
          ),
        ),
        FormRowField(
          label: "Father's profession",
          required: true,
          child: TextFormField(
            initialValue: draft.fatherProfession,
            maxLength: 150,
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) => draft.fatherProfession = value.trim(),
          ),
        ),
        FormRowField(
          label: "Mother's name",
          required: true,
          child: TextFormField(
            initialValue: draft.motherName,
            maxLength: 150,
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) => draft.motherName = value.trim(),
          ),
        ),
        FormRowField(
          label: "Mother's profession",
          required: true,
          child: TextFormField(
            initialValue: draft.motherProfession,
            maxLength: 150,
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) => draft.motherProfession = value.trim(),
          ),
        ),
        const SizedBox(height: 4),
        _SiblingsEditor(draft: draft, onChanged: onChanged),
        const Divider(height: 32),
        if (draft.religion == 'ইসলাম')
          FormRowField(
            label: 'Prayer habit',
            child: AppDropdown(
              value: draft.prayerHabit.isEmpty ? null : draft.prayerHabit,
              options: BiodataOptions.prayerHabits,
              includeEmpty: true,
              emptyLabel: 'Not specified',
              hint: 'Select',
              onChanged: (value) {
                draft.prayerHabit = value ?? '';
                onChanged();
              },
            ),
          ),
        FormRowField(
          label: 'Health condition',
          hint: 'Any long-term condition worth mentioning. Leave empty if none.',
          child: TextFormField(
            initialValue: draft.healthCondition,
            maxLength: 255,
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) => draft.healthCondition = value.trim(),
          ),
        ),
        FormRowField(
          label: 'About yourself',
          required: true,
          hint: 'Your character, interests and what you are looking for.',
          child: TextFormField(
            initialValue: draft.aboutSelf,
            maxLines: 5,
            maxLength: 1500,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (value) => draft.aboutSelf = value.trim(),
          ),
        ),
      ],
    );
  }
}

class _SiblingsEditor extends StatelessWidget {
  const _SiblingsEditor({required this.draft, required this.onChanged});

  final BiodataDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Brothers & sisters',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: draft.siblings.length >= BiodataOptions.maxSiblings
                  ? null
                  : () {
                      draft.siblings = [...draft.siblings, const Sibling()];
                      onChanged();
                    },
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Add'),
            ),
          ],
        ),
        if (draft.siblings.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'No siblings added. Leave this empty if you have none.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        for (var i = 0; i < draft.siblings.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Sibling ${i + 1}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        final next = [...draft.siblings]..removeAt(i);
                        draft.siblings = next;
                        onChanged();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.red,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                TextFormField(
                  initialValue: draft.siblings[i].name,
                  decoration: const InputDecoration(hintText: 'Name'),
                  onChanged: (value) => _update(i, name: value.trim()),
                ),
                const SizedBox(height: 8),
                AppDropdown(
                  value: draft.siblings[i].relation,
                  options: BiodataOptions.siblingRelations,
                  onChanged: (value) {
                    if (value != null) _update(i, relation: value);
                    onChanged();
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: draft.siblings[i].profession,
                  decoration: const InputDecoration(hintText: 'Profession'),
                  onChanged: (value) => _update(i, profession: value.trim()),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: draft.siblings[i].organization,
                  decoration: const InputDecoration(hintText: 'Organization'),
                  onChanged: (value) => _update(i, organization: value.trim()),
                ),
                const SizedBox(height: 8),
                AppDropdown(
                  value: draft.siblings[i].maritalStatus.isEmpty
                      ? null
                      : draft.siblings[i].maritalStatus,
                  options: BiodataOptions.maritalStatuses,
                  includeEmpty: true,
                  emptyLabel: 'Marital status',
                  hint: 'Marital status',
                  onChanged: (value) {
                    _update(i, maritalStatus: value ?? '');
                    onChanged();
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _update(
    int index, {
    String? name,
    String? relation,
    String? profession,
    String? organization,
    String? maritalStatus,
  }) {
    final current = draft.siblings[index];
    final next = [...draft.siblings];
    next[index] = Sibling(
      name: name ?? current.name,
      relation: relation ?? current.relation,
      profession: profession ?? current.profession,
      organization: organization ?? current.organization,
      maritalStatus: maritalStatus ?? current.maritalStatus,
    );
    draft.siblings = next;
  }
}

// --- Step 3 -----------------------------------------------------------------

class _PartnerContactStep extends StatelessWidget {
  const _PartnerContactStep({required this.draft, required this.onChanged});

  final BiodataDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        const _StepTitle(
          title: 'What you are looking for',
          subtitle: 'Everything here is optional — fill in what matters to you.',
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowField(
                label: 'Maximum age',
                child: TextFormField(
                  initialValue: draft.expectedMaxAge,
                  keyboardType: TextInputType.number,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 30',
                    counterText: '',
                  ),
                  onChanged: (value) => draft.expectedMaxAge = value.trim(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FormRowField(
                label: 'Minimum height',
                child: AppDropdown(
                  value: draft.expectedMinHeight.isEmpty
                      ? null
                      : draft.expectedMinHeight,
                  options: BiodataOptions.heights(),
                  includeEmpty: true,
                  emptyLabel: 'Any',
                  hint: 'Any',
                  onChanged: (value) {
                    draft.expectedMinHeight = value ?? '';
                    onChanged();
                  },
                ),
              ),
            ),
          ],
        ),
        FormRowField(
          label: 'Skin tone',
          child: AppDropdown(
            value: draft.expectedSkinTone.isEmpty ? null : draft.expectedSkinTone,
            options: BiodataOptions.skinTones,
            includeEmpty: true,
            emptyLabel: 'Any',
            hint: 'Any',
            onChanged: (value) {
              draft.expectedSkinTone = value ?? '';
              onChanged();
            },
          ),
        ),
        FormRowField(
          label: 'Marital status',
          child: AppDropdown(
            value: draft.expectedMaritalStatus.isEmpty
                ? null
                : draft.expectedMaritalStatus,
            options: BiodataOptions.maritalStatuses,
            includeEmpty: true,
            emptyLabel: 'Any',
            hint: 'Any',
            onChanged: (value) {
              draft.expectedMaritalStatus = value ?? '';
              onChanged();
            },
          ),
        ),
        FormRowField(
          label: 'Education',
          child: TextFormField(
            initialValue: draft.expectedEducation,
            maxLength: 150,
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) => draft.expectedEducation = value.trim(),
          ),
        ),
        FormRowField(
          label: 'Profession',
          child: TextFormField(
            initialValue: draft.expectedProfession,
            maxLength: 150,
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) => draft.expectedProfession = value.trim(),
          ),
        ),
        FormRowField(
          label: 'District',
          child: TextFormField(
            initialValue: draft.expectedDistrict,
            maxLength: 200,
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) => draft.expectedDistrict = value.trim(),
          ),
        ),
        FormRowField(
          label: 'Economic condition',
          child: TextFormField(
            initialValue: draft.expectedEconomicCondition,
            maxLength: 255,
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) => draft.expectedEconomicCondition = value.trim(),
          ),
        ),
        FormRowField(
          label: 'Family condition',
          child: TextFormField(
            initialValue: draft.expectedFamilyCondition,
            maxLength: 255,
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) => draft.expectedFamilyCondition = value.trim(),
          ),
        ),
        FormRowField(
          label: 'Qualities you hope for',
          child: TextFormField(
            initialValue: draft.expectedQualities,
            maxLines: 4,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (value) => draft.expectedQualities = value.trim(),
          ),
        ),
        if (draft.isGroom) ...[
          const Divider(height: 32),
          const _StepTitle(title: 'After marriage'),
          FormRowField(
            label: 'Can your wife continue studying?',
            child: AppDropdown(
              value: draft.wifeEducationPermission.isEmpty
                  ? null
                  : draft.wifeEducationPermission,
              options: BiodataOptions.yesNo,
              includeEmpty: true,
              emptyLabel: 'Not specified',
              hint: 'Select',
              onChanged: (value) {
                draft.wifeEducationPermission = value ?? '';
                onChanged();
              },
            ),
          ),
          FormRowField(
            label: 'Can your wife work?',
            child: AppDropdown(
              value: draft.wifeJobPermission.isEmpty ? null : draft.wifeJobPermission,
              options: BiodataOptions.yesNo,
              includeEmpty: true,
              emptyLabel: 'Not specified',
              hint: 'Select',
              onChanged: (value) {
                draft.wifeJobPermission = value ?? '';
                onChanged();
              },
            ),
          ),
          FormRowField(
            label: 'Where will your wife live?',
            child: TextFormField(
              initialValue: draft.whereWifeWillLive,
              maxLength: 255,
              decoration: const InputDecoration(counterText: ''),
              onChanged: (value) => draft.whereWifeWillLive = value.trim(),
            ),
          ),
        ],
        const Divider(height: 32),
        const _StepTitle(
          title: 'Contact',
          subtitle: 'Only people who unlock your biodata can see these details.',
        ),
        FormRowField(
          label: 'Guardian relation',
          required: true,
          child: AppDropdown(
            value: draft.guardianRelation,
            options: BiodataOptions.guardianRelations,
            onChanged: (value) {
              draft.guardianRelation = value ?? draft.guardianRelation;
              onChanged();
            },
          ),
        ),
        FormRowField(
          label: 'Guardian mobile number',
          required: true,
          hint: 'A Bangladeshi number starting with 01.',
          child: TextFormField(
            initialValue: draft.guardianPhone,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            decoration: const InputDecoration(
              hintText: '01XXXXXXXXX',
              counterText: '',
            ),
            onChanged: (value) => draft.guardianPhone = value.trim(),
          ),
        ),
        FormRowField(
          label: 'Email',
          child: TextFormField(
            initialValue: draft.email,
            keyboardType: TextInputType.emailAddress,
            maxLength: 190,
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) => draft.email = value.trim(),
          ),
        ),
        FormRowField(
          label: 'Note for the admin',
          hint: 'Anything the reviewer should know. Not shown publicly.',
          child: TextFormField(
            initialValue: draft.noteToAdmin,
            maxLines: 3,
            maxLength: 500,
            onChanged: (value) => draft.noteToAdmin = value.trim(),
          ),
        ),
      ],
    );
  }
}

// --- Step 4 -----------------------------------------------------------------

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.draft, required this.onChanged});

  final BiodataDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final problem = draft.validate();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        const _StepTitle(
          title: 'Check before submitting',
          subtitle: 'An admin verifies every biodata before it is published.',
        ),
        _ReviewCard(
          title: 'General',
          rows: [
            ('Type', dataLabel(draft.biodataType)),
            ('Marital status', dataLabel(draft.maritalStatus)),
            ('Date of birth', draft.dateOfBirth),
            ('Height', draft.height),
            ('Blood group', dataLabel(draft.bloodGroup)),
            ('Skin tone', dataLabel(draft.skinTone)),
            ('Profession', draft.profession),
            (
              'Current address',
              [draft.currentUpazila, draft.currentDistrict, draft.currentAddress]
                  .where((e) => e.isNotEmpty)
                  .join(', ')
            ),
          ],
        ),
        _ReviewCard(
          title: 'Family',
          rows: [
            ("Father", draft.fatherName),
            ("Mother", draft.motherName),
            ('Siblings', draft.siblings.isEmpty ? '' : '${draft.siblings.length}'),
          ],
        ),
        _ReviewCard(
          title: 'Contact',
          rows: [
            ('Guardian', dataLabel(draft.guardianRelation)),
            ('Guardian phone', draft.guardianPhone),
            ('Email', draft.email),
          ],
        ),
        _ReviewCard(
          title: 'Photos',
          rows: [
            (
              'Attached',
              '${draft.keepPhotoUrls.length + draft.newPhotoPaths.length} photo(s)'
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            draft.policyAgreed = !draft.policyAgreed;
            onChanged();
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: draft.policyAgreed,
                  onChanged: (value) {
                    draft.policyAgreed = value ?? false;
                    onChanged();
                  },
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'I confirm every detail is true and accept the ',
                          style: TextStyle(fontSize: 13, height: 1.5),
                        ),
                        GestureDetector(
                          onTap: () =>
                              Launchers.url(context, AppConfig.privacyPolicyUrl),
                          child: const Text(
                            'privacy policy',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.forestDark,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Text('.', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (problem != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    problem,
                    style: const TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final filled = rows.where((r) => r.$2.trim().isNotEmpty).toList();
    if (filled.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          for (final row in filled)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// --- Shared bits ------------------------------------------------------------

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PassedToggle extends StatelessWidget {
  const _PassedToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      activeThumbColor: AppColors.forest,
    );
  }
}

class _YearAndText extends StatelessWidget {
  const _YearAndText({
    required this.yearLabel,
    required this.year,
    required this.onYear,
    required this.textLabel,
    required this.text,
    required this.onText,
    this.required = false,
  });

  final String yearLabel;
  final String year;
  final ValueChanged<String?> onYear;
  final String textLabel;
  final String text;
  final ValueChanged<String> onText;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: FormRowField(
            label: yearLabel,
            required: required,
            child: AppDropdown(
              value: year.isEmpty ? null : year,
              options: BiodataOptions.years(),
              hint: 'Year',
              onChanged: onYear,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FormRowField(
            label: textLabel,
            required: required,
            child: TextFormField(
              initialValue: text,
              maxLength: 200,
              decoration: const InputDecoration(counterText: ''),
              onChanged: (value) => onText(value.trim()),
            ),
          ),
        ),
      ],
    );
  }
}
