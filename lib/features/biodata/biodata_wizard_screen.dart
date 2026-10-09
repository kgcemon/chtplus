import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/biodata_repository.dart';
import '../../models/biodata.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/home_provider.dart';
import '../../router.dart';
import '../widgets/form_fields.dart';
import '../widgets/site_scaffold.dart';
import 'biodata_detail_screen.dart' show BiodataDocumentView;
import 'biodata_lang.dart';

/// The matrimony biodata form, laid out like the website's `BiodataWizard` on
/// a phone: the English | বাংলা switch, the step chips, one card per step with
/// the same fields, answers and checks, the published-document preview, then
/// the "submitted" card with the new biodata number.
class BiodataWizardScreen extends ConsumerStatefulWidget {
  const BiodataWizardScreen({super.key, this.existing});

  final Biodata? existing;

  @override
  ConsumerState<BiodataWizardScreen> createState() => _BiodataWizardScreenState();
}

const _steps = ['General Information', 'Education & Family', 'Life Partner & Contact', 'Preview'];

/// The site's default district (Khagrachhari, id 10) for a new biodata.
const _defaultDistrictId = 10;

class _BiodataWizardScreenState extends ConsumerState<BiodataWizardScreen> {
  late final BiodataDraft _draft = widget.existing == null
      ? BiodataDraft()
      : BiodataDraft.fromBiodata(widget.existing!);

  final _scroll = ScrollController();
  final _fieldKeys = <String, GlobalKey>{};

  int _step = 0;
  bool _busy = false;

  /// The field the form jumped to because it was left empty, and its message.
  (String, String)? _fieldError;

  /// Set once a new biodata is saved: its number, for the success card.
  String? _submittedNo;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (!_isEdit) _applyDefaultDistrict();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _applyDefaultDistrict() async {
    try {
      final districts = await ref.read(districtsProvider.future);
      final match = districts.where((d) => d.id == _defaultDistrictId);
      if (match.isEmpty || !mounted) return;
      final name = match.first.filterValue;
      setState(() {
        if (_draft.permanentDistrict.isEmpty) _draft.permanentDistrict = name;
        if (_draft.currentDistrict.isEmpty) _draft.currentDistrict = name;
      });
    } catch (_) {
      // No district list — the user picks one by hand.
    }
  }

  GlobalKey _keyFor(String field) => _fieldKeys.putIfAbsent(field, GlobalKey.new);

  /// Something changed: redraw, and drop the error if it was on that field.
  void _changed(String field) {
    setState(() {
      if (_fieldError?.$1 == field) _fieldError = null;
    });
  }

  String? _errorFor(String field, BiodataText tr) =>
      _fieldError?.$1 == field ? tr.t(_fieldError!.$2) : null;

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  /// Goes to the step holding the problem, then scrolls the field into view.
  void _showProblem(int step, (String, String) problem) {
    setState(() {
      _step = step;
      _fieldError = problem;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _fieldKeys[problem.$1]?.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.3,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _goNext() {
    final problem = _draft.problemInStep(_step);
    if (problem != null) {
      _showProblem(_step, problem);
      return;
    }
    setState(() {
      _fieldError = null;
      if (_step < _steps.length - 1) _step++;
    });
    _scrollToTop();
  }

  void _goBack() {
    setState(() {
      _fieldError = null;
      if (_step > 0) _step--;
    });
    _scrollToTop();
  }

  Future<void> _submit() async {
    for (var step = 0; step < 3; step++) {
      final problem = _draft.problemInStep(step);
      if (problem != null) {
        _showProblem(step, problem);
        return;
      }
    }

    setState(() {
      _busy = true;
      _fieldError = null;
    });
    try {
      final repository = ref.read(biodataRepositoryProvider);
      if (_isEdit) {
        await repository.update(widget.existing!.id, _draft);
      } else {
        final created = await repository.create(_draft);
        _submittedNo = created.biodataNo;
      }

      ref.invalidate(myBiodataProvider);
      ref.invalidate(biodataListProvider);
      ref.invalidate(homeFeedProvider);
      if (!mounted) return;

      if (_isEdit) {
        context.pop(true);
      } else {
        setState(() {});
        _scrollToTop();
      }
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, ref.read(biodataTextProvider).t(error.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmLeave(BiodataText tr) async {
    final leave = await AppDialogs.confirm(
      context,
      title: tr.t('Discard this biodata?'),
      message: tr.t('Anything you have filled in will be lost.'),
      confirmLabel: tr.t('Discard'),
      cancelLabel: tr.t('Keep editing'),
      destructive: true,
    );
    if (leave && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(biodataTextProvider);
    final done = _submittedNo != null;

    return PopScope(
      canPop: done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave(tr);
      },
      child: SiteScaffold(
        title: tr.t(_isEdit ? 'Edit biodata' : 'Submit biodata'),
        showTitle: false,
        body: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
          child: done
              ? _SuccessCard(biodataNo: _submittedNo!, tr: tr)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PageHead(tr: tr, isEdit: _isEdit),
                    const SizedBox(height: 16),
                    _StepChips(current: _step, tr: tr),
                    const SizedBox(height: 18),
                    KeyedSubtree(
                      key: ValueKey(_step),
                      child: switch (_step) {
                        0 => _generalStep(tr),
                        1 => _educationFamilyStep(tr),
                        2 => _partnerContactStep(tr),
                        _ => _previewStep(tr),
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // --- Field helpers ---------------------------------------------------------

  /// A labelled field the form can jump to: `<Field name=...>` on the site.
  Widget _field(
    BiodataText tr,
    String name,
    String label,
    Widget child, {
    bool required = false,
    double labelSize = 13,
  }) {
    return FormRowField(
      key: _keyFor(name),
      label: tr.t(label),
      required: required,
      errorText: _errorFor(name, tr),
      labelSize: labelSize,
      child: child,
    );
  }

  Widget _text(
    BiodataText tr,
    String name,
    String value,
    ValueChanged<String> onChanged, {
    String? placeholder,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboard,
    bool translatePlaceholder = true,
  }) {
    return TextFormField(
      initialValue: value,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 3 : 1,
      maxLength: maxLength,
      keyboardType: keyboard ?? (maxLines > 1 ? TextInputType.multiline : null),
      textCapitalization:
          maxLines > 1 ? TextCapitalization.sentences : TextCapitalization.none,
      decoration: InputDecoration(
        hintText: placeholder == null ? null : (translatePlaceholder ? tr.t(placeholder) : placeholder),
        hintMaxLines: 3,
        counterText: '',
      ),
      onChanged: (v) {
        onChanged(v);
        _changed(name);
      },
    );
  }

  /// A select whose options are stored values shown through [labels] (or the
  /// value itself), like `<option value=...>{label}</option>`.
  Widget _select(
    BiodataText tr,
    String name,
    String value,
    List<String> options,
    ValueChanged<String> onChanged, {
    Map<String, String>? labels,
    bool translateValues = false,
    bool placeholder = false,
  }) {
    return AppDropdown(
      value: value.isEmpty ? null : value,
      options: options,
      hint: placeholder ? tr.t('Select') : '',
      labelBuilder: (v) {
        final label = labels?[v];
        if (label != null) return tr.t(label);
        return translateValues ? tr.dl(v) : v;
      },
      onChanged: (v) {
        if (v == null) return;
        onChanged(v);
        _changed(name);
      },
    );
  }

  static const _yesNo = {BiodataDraft.yes: 'Yes', BiodataDraft.no: 'No'};

  Widget _heading(String text, {double top = 22}) => Padding(
        padding: EdgeInsets.only(top: top, bottom: 14),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      );

  Widget _actions(BiodataText tr, {bool back = true, String next = 'Next →', VoidCallback? onNext}) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (back)
            OutlinedButton(
              onPressed: _busy ? null : _goBack,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              child: Text(tr.t(_step == 3 ? '← Edit biodata' : '← Previous')),
            ),
          FilledButton(
            onPressed: _busy ? null : (onNext ?? _goNext),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: Text(tr.t(next)),
          ),
        ],
      ),
    );
  }

  // --- Step 1: General Information --------------------------------------------

  Widget _generalStep(BiodataText tr) {
    final d = _draft;
    return _Card(
      children: [
        _heading(tr.t('General Information'), top: 0),
        _Grid(
          children: [
            _field(
              tr,
              'biodataType',
              'Biodata type',
              required: true,
              _select(tr, 'biodataType', d.biodataType, BiodataOptions.types,
                  (v) => d.biodataType = v,
                  labels: const {
                    'পাত্রের বায়োডাটা': 'Groom’s biodata',
                    'পাত্রীর বায়োডাটা': 'Bride’s biodata',
                  }),
            ),
            _field(
              tr,
              'maritalStatus',
              'Marital status',
              required: true,
              _select(tr, 'maritalStatus', d.maritalStatus, BiodataOptions.maritalStatuses,
                  (v) => d.maritalStatus = v,
                  translateValues: true),
            ),
            _field(
              tr,
              'dateOfBirth',
              'Date of birth',
              required: true,
              DateField(
                value: d.dateOfBirth,
                hint: tr.t('Select a date'),
                lastDate: DateTime.now(),
                onChanged: (v) {
                  d.dateOfBirth = v;
                  _changed('dateOfBirth');
                },
              ),
            ),
            _field(
              tr,
              'skinTone',
              'Skin tone',
              required: true,
              _select(tr, 'skinTone', d.skinTone, BiodataOptions.skinTones,
                  (v) => d.skinTone = v,
                  translateValues: true, placeholder: true),
            ),
            _field(
              tr,
              'height',
              'Height',
              required: true,
              _select(tr, 'height', d.height, BiodataOptions.heights(), (v) => d.height = v,
                  placeholder: true),
            ),
            _field(
              tr,
              'bloodGroup',
              'Blood group',
              required: true,
              _select(tr, 'bloodGroup', d.bloodGroup, BiodataOptions.bloodGroups,
                  (v) => d.bloodGroup = v,
                  translateValues: true, placeholder: true),
            ),
            _field(
              tr,
              'professionType',
              'Profession type',
              required: true,
              _select(tr, 'professionType', d.professionType, BiodataOptions.professionTypes,
                  (v) => d.professionType = v,
                  translateValues: true),
            ),
            _field(
              tr,
              'religion',
              'Religion',
              required: true,
              _select(tr, 'religion', d.religion, BiodataOptions.religions,
                  (v) => d.religion = v,
                  labels: const {
                    'ইসলাম': 'Islam',
                    'হিন্দু': 'Hinduism',
                    'বৌদ্ধ': 'Buddhism',
                    'খ্রিস্টান': 'Christianity',
                    'অন্যান্য': 'Other',
                  }),
            ),
          ],
        ),
        _field(
          tr,
          'profession',
          'Profession details',
          required: true,
          _text(tr, 'profession', d.profession, (v) => d.profession = v,
              maxLength: 150,
              placeholder: 'e.g. Assistant teacher, Govt. High School · Officer, Krishi Bank'),
        ),
        _heading(tr.t('Address')),
        _Grid(
          children: [
            _field(
              tr,
              'permanentDistrict',
              'Permanent address — District',
              required: true,
              DistrictPicker(
                value: d.permanentDistrict.isEmpty ? null : d.permanentDistrict,
                includeEmpty: false,
                bengaliLabels: true,
                hint: tr.t('Select'),
                onChanged: (v) {
                  d.permanentDistrict = v ?? '';
                  d.permanentUpazila = '';
                  _changed('permanentDistrict');
                },
              ),
            ),
            _field(
              tr,
              'permanentUpazila',
              'Permanent address — Thana',
              UpazilaPicker(
                districtName: d.permanentDistrict.isEmpty ? null : d.permanentDistrict,
                value: d.permanentUpazila.isEmpty ? null : d.permanentUpazila,
                emptyLabel: tr.t('Select'),
                hint: tr.t('Select'),
                placeholder: tr.t('Select'),
                bengaliLabels: true,
                onChanged: (v) {
                  d.permanentUpazila = v ?? '';
                  _changed('permanentUpazila');
                },
              ),
            ),
            _field(
              tr,
              'currentDistrict',
              'Current address — District',
              required: true,
              DistrictPicker(
                value: d.currentDistrict.isEmpty ? null : d.currentDistrict,
                includeEmpty: false,
                bengaliLabels: true,
                hint: tr.t('Select'),
                onChanged: (v) {
                  d.currentDistrict = v ?? '';
                  d.currentUpazila = '';
                  _changed('currentDistrict');
                },
              ),
            ),
            _field(
              tr,
              'currentUpazila',
              'Current address — Thana',
              UpazilaPicker(
                districtName: d.currentDistrict.isEmpty ? null : d.currentDistrict,
                value: d.currentUpazila.isEmpty ? null : d.currentUpazila,
                emptyLabel: tr.t('Select'),
                hint: tr.t('Select'),
                placeholder: tr.t('Select'),
                bengaliLabels: true,
                onChanged: (v) {
                  d.currentUpazila = v ?? '';
                  _changed('currentUpazila');
                },
              ),
            ),
          ],
        ),
        _field(
          tr,
          'currentAddress',
          'Current address (details)',
          required: true,
          _text(tr, 'currentAddress', d.currentAddress, (v) => d.currentAddress = v,
              maxLines: 3,
              maxLength: 255,
              placeholder: 'e.g. House no. / Holding no., Area name, Ward no.'),
        ),
        _heading(tr.t('Upload photos (max 4)')),
        _PhotoSlots(
          slots: d.photoSlots,
          tr: tr,
          onChanged: (slots) {
            d.photoSlots = slots;
            _changed('photos');
          },
        ),
        _actions(tr, back: false),
      ],
    );
  }

  // --- Step 2: Education & Family ---------------------------------------------

  /// One education level: the yes/no question, then (when passed) the year,
  /// the group or department, and the institute on its own row.
  Widget _educationLevel(
    BiodataText tr, {
    required String answerField,
    required String question,
    required String answer,
    required bool passed,
    required String yearField,
    required String yearLabel,
    required String year,
    required ValueChanged<String> onYear,
    required Widget middle,
    required String instituteField,
    required String institute,
    required ValueChanged<String> onInstitute,
  }) {
    const small = 11.5;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _field(
                  tr,
                  answerField,
                  question,
                  required: true,
                  labelSize: small,
                  _select(tr, answerField, answer, _yesNo.keys.toList(),
                      (v) => _draft.setEducationAnswer(answerField, v),
                      labels: _yesNo, placeholder: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: passed
                    ? _field(
                        tr,
                        yearField,
                        yearLabel,
                        required: true,
                        labelSize: small,
                        _select(tr, yearField, year, BiodataOptions.years(), onYear,
                            placeholder: true),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
              Expanded(child: passed ? middle : const SizedBox.shrink()),
            ],
          ),
          if (passed)
            _field(
              tr,
              instituteField,
              'Institute name',
              required: true,
              labelSize: small,
              _text(tr, instituteField, institute, onInstitute, maxLength: 200),
            ),
        ],
      ),
    );
  }

  Widget _educationFamilyStep(BiodataText tr) {
    final d = _draft;
    const small = 11.5;

    Widget groupField(String name, String value, ValueChanged<String> onChanged) => _field(
          tr,
          name,
          'Group',
          required: true,
          labelSize: small,
          _select(tr, name, value, BiodataOptions.educationGroups, onChanged,
              translateValues: true, placeholder: true),
        );

    Widget departmentField(String name, String value, ValueChanged<String> onChanged,
            String placeholder) =>
        _field(
          tr,
          name,
          'Department / degree name',
          required: true,
          labelSize: small,
          _text(tr, name, value, onChanged, maxLength: 200, placeholder: placeholder),
        );

    return _Card(
      children: [
        _heading(tr.t('Education'), top: 0),
        _Grid(
          children: [
            _field(
              tr,
              'educationMedium',
              'Which medium did you study in?',
              required: true,
              _select(tr, 'educationMedium', d.educationMedium, BiodataOptions.educationMediums,
                  (v) => d.educationMedium = v,
                  labels: const {
                    'জেনারেল': 'General',
                    'কারিগরি': 'Technical',
                    'মাদ্রাসা': 'Madrasa',
                  }),
            ),
          ],
        ),
        _educationLevel(
          tr,
          answerField: 'sscPassed',
          question: 'Did you pass SSC/equivalent?',
          answer: d.sscPassed,
          passed: d.sscDone,
          yearField: 'sscYear',
          yearLabel: 'SSC passing year',
          year: d.sscYear,
          onYear: (v) => d.sscYear = v,
          middle: groupField('sscGroup', d.sscGroup, (v) => d.sscGroup = v),
          instituteField: 'sscInstitution',
          institute: d.sscInstitution,
          onInstitute: (v) => d.sscInstitution = v,
        ),
        if (d.sscDone)
          _educationLevel(
            tr,
            answerField: 'hscPassed',
            question: 'Did you pass HSC/equivalent?',
            answer: d.hscPassed,
            passed: d.hscDone,
            yearField: 'hscYear',
            yearLabel: 'HSC passing year',
            year: d.hscYear,
            onYear: (v) => d.hscYear = v,
            middle: groupField('hscGroup', d.hscGroup, (v) => d.hscGroup = v),
            instituteField: 'hscInstitution',
            institute: d.hscInstitution,
            onInstitute: (v) => d.hscInstitution = v,
          ),
        if (d.hscDone)
          _educationLevel(
            tr,
            answerField: 'graduationPassed',
            question: 'Did you pass graduation/equivalent?',
            answer: d.graduationPassed,
            passed: d.graduationDone,
            yearField: 'graduationYear',
            yearLabel: 'Passing year',
            year: d.graduationYear,
            onYear: (v) => d.graduationYear = v,
            middle: departmentField('graduationDepartment', d.graduationDepartment,
                (v) => d.graduationDepartment = v, 'e.g. BSc in CSE'),
            instituteField: 'institutionName',
            institute: d.institutionName,
            onInstitute: (v) => d.institutionName = v,
          ),
        if (d.graduationDone)
          _educationLevel(
            tr,
            answerField: 'postgraduationPassed',
            question: 'Did you pass post-graduation/equivalent?',
            answer: d.postgraduationPassed,
            passed: d.postgraduationDone,
            yearField: 'postgraduationYear',
            yearLabel: 'Passing year',
            year: d.postgraduationYear,
            onYear: (v) => d.postgraduationYear = v,
            middle: departmentField('postgraduationDepartment', d.postgraduationDepartment,
                (v) => d.postgraduationDepartment = v, 'e.g. MSc in Physics'),
            instituteField: 'postgraduationInstitution',
            institute: d.postgraduationInstitution,
            onInstitute: (v) => d.postgraduationInstitution = v,
          ),
        _heading(tr.t('Family Information')),
        _Grid(
          children: [
            _field(tr, 'fatherName', 'Father’s name', required: true,
                _text(tr, 'fatherName', d.fatherName, (v) => d.fatherName = v, maxLength: 150)),
            _field(tr, 'fatherProfession', 'Father’s profession', required: true,
                _text(tr, 'fatherProfession', d.fatherProfession, (v) => d.fatherProfession = v,
                    maxLength: 150)),
            _field(tr, 'motherName', 'Mother’s name', required: true,
                _text(tr, 'motherName', d.motherName, (v) => d.motherName = v, maxLength: 150)),
            _field(tr, 'motherProfession', 'Mother’s profession', required: true,
                _text(tr, 'motherProfession', d.motherProfession, (v) => d.motherProfession = v,
                    maxLength: 150)),
            _field(
              tr,
              'siblingCount',
              'How many siblings do you have?',
              _select(
                tr,
                'siblingCount',
                '${d.siblings.length}',
                [for (var n = 0; n <= BiodataOptions.maxSiblings; n++) '$n'],
                (v) => d.setSiblingCount(int.parse(v)),
              ),
            ),
          ],
        ),
        for (var i = 0; i < d.siblings.length; i++) _siblingCard(tr, i),
        _heading(tr.t('Personal information')),
        _Grid(
          children: [
            if (d.isMuslim)
              _field(
                tr,
                'prayerHabit',
                'Do you pray five times a day?',
                _select(tr, 'prayerHabit', d.prayerHabit,
                    const [BiodataDraft.yes, BiodataDraft.no, 'নিয়মিত চেষ্টা করি'],
                    (v) => d.prayerHabit = v,
                    labels: const {..._yesNo, 'নিয়মিত চেষ্টা করি': 'Try to pray regularly'}),
              ),
            _field(
              tr,
              'healthIssue',
              'Do you have any mental or physical illness?',
              required: true,
              _select(tr, 'healthIssue', d.healthIssue, _yesNo.keys.toList(),
                  (v) => d.healthIssue = v,
                  labels: _yesNo, placeholder: true),
            ),
          ],
        ),
        if (d.healthIssue == BiodataDraft.yes)
          _field(
            tr,
            'healthDetails',
            'Give details of the mental or physical illness',
            required: true,
            _text(tr, 'healthDetails', d.healthDetails, (v) => d.healthDetails = v,
                maxLines: 3, maxLength: 255),
          ),
        _field(
          tr,
          'aboutSelf',
          'Write something about yourself',
          required: true,
          _text(tr, 'aboutSelf', d.aboutSelf, (v) => d.aboutSelf = v, maxLines: 4),
        ),
        if (d.isGroom) ...[
          _heading(tr.t('Marriage-related information')),
          _Grid(
            children: [
              _field(
                tr,
                'wifeEducationPermission',
                'After marriage, do you want to let your wife study?',
                _select(tr, 'wifeEducationPermission', d.wifeEducationPermission,
                    const [BiodataDraft.yes, BiodataDraft.no, 'আলোচনা সাপেক্ষে'],
                    (v) => d.wifeEducationPermission = v,
                    labels: const {..._yesNo, 'আলোচনা সাপেক্ষে': 'Negotiable'}),
              ),
              _field(
                tr,
                'wifeJobPermission',
                'After marriage, do you want to let your wife work?',
                _select(tr, 'wifeJobPermission', d.wifeJobPermission,
                    const [BiodataDraft.yes, BiodataDraft.no, 'আলোচনা সাপেক্ষে'],
                    (v) => d.wifeJobPermission = v,
                    labels: const {..._yesNo, 'আলোচনা সাপেক্ষে': 'Negotiable'}),
              ),
            ],
          ),
          _field(
            tr,
            'whereWifeWillLive',
            'Where will you keep your wife after marriage?',
            _text(tr, 'whereWifeWillLive', d.whereWifeWillLive, (v) => d.whereWifeWillLive = v,
                maxLines: 3,
                maxLength: 255,
                placeholder: 'e.g. With my family, At my workplace location, Not decided yet'),
          ),
        ],
        _actions(tr),
      ],
    );
  }

  Widget _siblingCard(BiodataText tr, int i) {
    final sib = _draft.siblings[i];
    void update(Sibling next) {
      final list = [..._draft.siblings];
      list[i] = next;
      _draft.siblings = list;
      _changed('sibling$i');
    }

    Sibling copy({String? name, String? relation, String? profession, String? organization,
            String? maritalStatus}) =>
        Sibling(
          name: name ?? sib.name,
          relation: relation ?? sib.relation,
          profession: profession ?? sib.profession,
          organization: organization ?? sib.organization,
          maritalStatus: maritalStatus ?? sib.maritalStatus,
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${tr.t('Sibling')} ${i + 1}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.forestDark,
              ),
            ),
          ),
          _Grid(
            children: [
              _field(tr, 'sibling$i-name', 'Name',
                  _text(tr, 'sibling$i-name', sib.name, (v) => update(copy(name: v)))),
              _field(
                tr,
                'sibling$i-relation',
                'Relationship',
                _select(tr, 'sibling$i-relation', sib.relation,
                    const ['বড় ভাই', 'বড় বোন', 'ছোট ভাই', 'ছোট বোন'],
                    (v) => update(copy(relation: v)),
                    labels: const {
                      'বড় ভাই': 'Elder brother',
                      'বড় বোন': 'Elder sister',
                      'ছোট ভাই': 'Younger brother',
                      'ছোট বোন': 'Younger sister',
                    }),
              ),
              _field(
                tr,
                'sibling$i-profession',
                'Profession',
                _select(tr, 'sibling$i-profession', sib.profession, BiodataOptions.professionTypes,
                    (v) => update(copy(profession: v)),
                    translateValues: true),
              ),
              _field(
                tr,
                'sibling$i-organization',
                'Organization / institute',
                _text(tr, 'sibling$i-organization', sib.organization,
                    (v) => update(copy(organization: v))),
              ),
              _field(
                tr,
                'sibling$i-marital',
                'Marital status',
                _select(tr, 'sibling$i-marital', sib.maritalStatus,
                    BiodataOptions.maritalStatuses, (v) => update(copy(maritalStatus: v)),
                    translateValues: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Step 3: Life Partner & Contact -----------------------------------------

  Widget _partnerContactStep(BiodataText tr) {
    final d = _draft;
    const any = BiodataDraft.any;
    const anyLabel = {any: 'Any'};

    return _Card(
      children: [
        _heading(tr.t('The kind of life partner you expect'), top: 0),
        _Grid(
          children: [
            _field(
              tr,
              'expectedMaxAge',
              'Maximum age',
              _text(tr, 'expectedMaxAge', d.expectedMaxAge, (v) => d.expectedMaxAge = v,
                  keyboard: TextInputType.number, maxLength: 2),
            ),
            _field(
              tr,
              'expectedSkinTone',
              'Skin tone',
              _select(tr, 'expectedSkinTone', d.expectedSkinTone,
                  [any, ...BiodataOptions.skinTones], (v) => d.expectedSkinTone = v,
                  labels: anyLabel, translateValues: true),
            ),
            _field(
              tr,
              'expectedMinHeight',
              'Minimum height',
              _select(tr, 'expectedMinHeight', d.expectedMinHeight,
                  [any, ...BiodataOptions.heights()], (v) => d.expectedMinHeight = v,
                  labels: anyLabel),
            ),
            _field(
              tr,
              'expectedEducation',
              'Minimum educational qualification',
              _text(tr, 'expectedEducation', d.expectedEducation, (v) => d.expectedEducation = v,
                  maxLength: 150),
            ),
            _field(
              tr,
              'expectedDistrict',
              'District',
              DistrictPicker(
                value: d.expectedDistrict.isEmpty ? null : d.expectedDistrict,
                emptyLabel: tr.t('Any'),
                hint: tr.t('Any'),
                bengaliLabels: true,
                onChanged: (v) {
                  d.expectedDistrict = v ?? '';
                  _changed('expectedDistrict');
                },
              ),
            ),
            _field(
              tr,
              'expectedMaritalStatus',
              'Marital status',
              _select(tr, 'expectedMaritalStatus', d.expectedMaritalStatus,
                  [any, ...BiodataOptions.maritalStatuses], (v) => d.expectedMaritalStatus = v,
                  labels: anyLabel, translateValues: true),
            ),
            _field(
              tr,
              'expectedProfession',
              'Profession',
              _text(tr, 'expectedProfession', d.expectedProfession,
                  (v) => d.expectedProfession = v,
                  maxLength: 150, placeholder: 'e.g. Govt. service holder, Businessman, Any'),
            ),
            _field(
              tr,
              'expectedEconomicCondition',
              'Economic condition',
              _text(tr, 'expectedEconomicCondition', d.expectedEconomicCondition,
                  (v) => d.expectedEconomicCondition = v,
                  maxLength: 255, placeholder: 'e.g. Financially solvent'),
            ),
          ],
        ),
        _field(
          tr,
          'expectedFamilyCondition',
          'Family condition',
          _text(tr, 'expectedFamilyCondition', d.expectedFamilyCondition,
              (v) => d.expectedFamilyCondition = v,
              maxLines: 3,
              maxLength: 255,
              placeholder: 'e.g. Upper-middle-class, educated and well-established family'),
        ),
        _field(
          tr,
          'expectedQualities',
          'The traits or qualities you expect in a life partner',
          _text(tr, 'expectedQualities', d.expectedQualities, (v) => d.expectedQualities = v,
              maxLines: 3,
              maxLength: 1000,
              placeholder:
                  'e.g. A kind, honest, responsible and understanding person who values family, mutual respect and a peaceful relationship.'),
        ),
        _heading(tr.t('For the authority')),
        _field(
          tr,
          'noteToAdmin',
          'Anything special you want to tell the authority',
          _text(tr, 'noteToAdmin', d.noteToAdmin, (v) => d.noteToAdmin = v,
              maxLines: 3,
              maxLength: 500,
              placeholder:
                  'Please keep my information confidential and contact me if any additional information or clarification is required.'),
        ),
        _policyAgreement(tr),
        _heading(tr.t('Contact / Guardian information')),
        _Grid(
          children: [
            _field(
              tr,
              'guardianPhone',
              'Guardian’s number',
              required: true,
              _text(tr, 'guardianPhone', d.guardianPhone, (v) => d.guardianPhone = v.trim(),
                  keyboard: TextInputType.phone,
                  maxLength: 11,
                  placeholder: '01XXXXXXXXX',
                  translatePlaceholder: false),
            ),
            _field(
              tr,
              'guardianRelation',
              'Relationship',
              required: true,
              _select(tr, 'guardianRelation', d.guardianRelation,
                  const ['পিতা', 'মাতা', 'ভাই', 'বোন', 'স্থানীয় অভিভাবক', 'অন্যান্য'],
                  (v) => d.guardianRelation = v,
                  labels: const {
                    'পিতা': 'Father',
                    'মাতা': 'Mother',
                    'ভাই': 'Brother',
                    'বোন': 'Sister',
                    'স্থানীয় অভিভাবক': 'Local guardian',
                    'অন্যান্য': 'Other',
                  },
                  placeholder: true),
            ),
            _field(
              tr,
              'email',
              'Email Address (Optional)',
              _text(tr, 'email', d.email, (v) => d.email = v.trim(),
                  keyboard: TextInputType.emailAddress, maxLength: 190),
            ),
          ],
        ),
        _actions(tr, next: 'Preview biodata →'),
      ],
    );
  }

  /// "I agree to all of our policies *" with its error underneath.
  Widget _policyAgreement(BiodataText tr) {
    final error = _errorFor('policyAgreed', tr);
    void toggle(bool? value) {
      _draft.policyAgreed = value ?? !_draft.policyAgreed;
      _changed('policyAgreed');
    }

    return Padding(
      key: _keyFor('policyAgreed'),
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => toggle(null),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Checkbox(
                  value: _draft.policyAgreed,
                  onChanged: toggle,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: error == null ? null : const BorderSide(color: AppColors.red, width: 1.6),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 13.5, color: AppColors.text),
                      children: [
                        TextSpan(text: '${tr.t('I agree to all of our')} '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: () => Launchers.url(context, AppConfig.privacyPolicyUrl),
                            child: Text(
                              tr.t('policies'),
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: AppColors.forest,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        if (tr.isBn) const TextSpan(text: ' মেনে নিচ্ছি'),
                        const TextSpan(text: ' *', style: TextStyle(color: AppColors.red)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: Text(error, style: const TextStyle(fontSize: 12, color: AppColors.red)),
            ),
        ],
      ),
    );
  }

  // --- Step 4: Preview ----------------------------------------------------------

  Widget _previewStep(BiodataText tr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.forestLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13, color: AppColors.forestDark, height: 1.45),
              children: [
                TextSpan(
                  text: tr.t('Preview'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(text: ' — '),
                TextSpan(
                  text: tr.t(_isEdit
                      ? 'This is how your biodata will look once it is published. Check everything, then save your changes. To change something, go back and edit.'
                      : 'This is how your biodata will look once it is published. Check everything, then submit. To change something, go back and edit.'),
                ),
              ],
            ),
          ),
        ),
        BiodataDocumentView(
          biodata: _draft.toPreview(biodataNo: tr.t('Preview')),
          preview: true,
          t: tr.t,
          dl: tr.dl,
        ),
        _actions(
          tr,
          next: _busy ? 'Saving...' : (_isEdit ? 'Save changes' : 'Submit biodata'),
          onNext: _submit,
        ),
      ],
    );
  }
}

// --- Layout pieces -------------------------------------------------------------

/// "Submit biodata", the line under it and the English | বাংলা switch
/// (`BiodataPageHead`).
class _PageHead extends StatelessWidget {
  const _PageHead({required this.tr, required this.isEdit});

  final BiodataText tr;
  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.t(isEdit ? 'Edit biodata' : 'Submit biodata'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text),
        ),
        const SizedBox(height: 4),
        Text(
          tr.t('Fill in the information below correctly; your biodata will be published after verification'),
          style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        const BiodataLangSwitch(),
      ],
    );
  }
}

/// The numbered pills across the top (`.wizard-stepper`), scrolling sideways
/// on a phone.
class _StepChips extends StatelessWidget {
  const _StepChips({required this.current, required this.tr});

  final int current;
  final BiodataText tr;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _chip(i),
          ],
        ],
      ),
    );
  }

  Widget _chip(int i) {
    final active = i == current;
    final done = i < current;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.forestLight : AppColors.surface,
        border: Border.all(color: active ? AppColors.forest : AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active || done ? AppColors.forest : AppColors.border,
            ),
            child: Text(
              done ? '✓' : '${i + 1}',
              style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            tr.t(_steps[i]),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: active || done ? AppColors.forestDark : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The white step card (`.admin-card`).
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// Two fields per row, as the site's `.form-grid.wizard-cols` on a phone.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i += 2)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 10),
              Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
            ],
          ),
      ],
    );
  }
}

/// Four square photo slots, two per row on a phone; the first is the main
/// photo (`.wizard-photo-grid`).
class _PhotoSlots extends StatelessWidget {
  const _PhotoSlots({required this.slots, required this.tr, required this.onChanged});

  final List<String?> slots;
  final BiodataText tr;
  final ValueChanged<List<String?>> onChanged;

  Future<void> _pick(BuildContext context, int index) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr.t('Gallery')),
              onTap: () => Navigator.pop(sheet, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(tr.t('Camera')),
              onTap: () => Navigator.pop(sheet, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (picked == null) return;
      final next = [...slots];
      next[index] = picked.path;
      onChanged(next);
    } on PlatformException {
      if (context.mounted) AppSnackbar.error(context, 'Could not open the photo picker.');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget slot(int i) {
      final source = slots[i];
      return AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          onTap: () => _pick(context, i),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (source == null)
                  const Center(
                    child: Text('+', style: TextStyle(fontSize: 30, color: AppColors.textSecondary)),
                  )
                else if (BiodataDraft.isUrl(source))
                  AppNetworkImage(url: source)
                else
                  Image.file(File(source), fit: BoxFit.cover),
                if (i == 0)
                  Positioned(
                    left: 4,
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xD9145C39),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tr.t('Main photo'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ),
                if (source != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Semantics(
                      label: tr.t('Remove image'),
                      button: true,
                      child: GestureDetector(
                        onTap: () {
                          final next = [...slots];
                          next[i] = null;
                          onChanged(next);
                        },
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0x99000000),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('✕', style: TextStyle(fontSize: 12, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: slot(row * 2)),
              const SizedBox(width: 12),
              Expanded(child: slot(row * 2 + 1)),
            ],
          ),
        ],
      ],
    );
  }
}

/// Shown once a new biodata is saved (`.wizard-success`).
class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.biodataNo, required this.tr});

  final String biodataNo;
  final BiodataText tr;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('✅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 10),
          Text(
            tr.t('Your biodata has been submitted successfully.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(tr.t('Your biodata number'), textAlign: TextAlign.center),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.forestLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              biodataNo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.forestDark,
              ),
            ),
          ),
          Text(
            tr.t('It will be published on the website after verification. Please save this number.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => context.go(Routes.home),
            child: Text(tr.t('Back to home page')),
          ),
        ],
      ),
    );
  }
}
