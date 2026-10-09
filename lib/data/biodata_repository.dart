import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/api/response_cache.dart';
import '../core/utils/json.dart';
import '../models/biodata.dart';

/// Everything the biodata wizard collects, with the same starting values,
/// yes/no answers and required-field checks as the site's `BiodataWizard`.
/// Field names match the form keys `lib/biodataFields.js` parses on the server.
class BiodataDraft {
  BiodataDraft();

  static const yes = 'হ্যাঁ';
  static const no = 'না';
  static const any = 'যেকোনো';

  String biodataType = 'পাত্রের বায়োডাটা';
  String maritalStatus = 'অবিবাহিত';
  // Filled with খাগড়াছড়ি by the wizard once the district list is in, like the site.
  String permanentDistrict = '';
  String permanentUpazila = '';
  String currentDistrict = '';
  String currentUpazila = '';
  String currentAddress = '';
  String dateOfBirth = '';
  String skinTone = '';
  String height = '';
  String bloodGroup = '';
  String professionType = 'চাকরি';
  String profession = '';
  String religion = 'ইসলাম';

  String educationMedium = 'জেনারেল';
  // '' (not answered yet), হ্যাঁ or না.
  String sscPassed = '';
  String sscYear = '';
  String sscInstitution = '';
  String sscGroup = '';
  String hscPassed = '';
  String hscYear = '';
  String hscInstitution = '';
  String hscGroup = '';
  String graduationPassed = '';
  String institutionName = '';
  String graduationDepartment = '';
  String graduationYear = '';
  String postgraduationPassed = '';
  String postgraduationInstitution = '';
  String postgraduationDepartment = '';
  String postgraduationYear = '';

  String fatherName = '';
  String fatherProfession = '';
  String motherName = '';
  String motherProfession = '';
  List<Sibling> siblings = [];

  String prayerHabit = 'নিয়মিত চেষ্টা করি';
  // '' (not answered yet), হ্যাঁ or না; the details are sent as healthCondition.
  String healthIssue = '';
  String healthDetails = '';
  String aboutSelf = '';

  String wifeEducationPermission = yes;
  String wifeJobPermission = 'আলোচনা সাপেক্ষে';
  String whereWifeWillLive = '';

  String expectedMaxAge = '';
  String expectedSkinTone = any;
  String expectedMinHeight = any;
  String expectedEducation = '';
  String expectedDistrict = '';
  String expectedMaritalStatus = any;
  String expectedProfession = '';
  String expectedEconomicCondition = '';
  String expectedFamilyCondition = '';
  String expectedQualities = '';

  String noteToAdmin = '';
  bool policyAgreed = false;
  String guardianPhone = '';
  String guardianRelation = 'পিতা';
  String email = '';

  /// The four photo slots (`.wizard-photo-slot`): an uploaded photo's URL, a
  /// newly picked file's path, or null for an empty slot. Slot 0 is the main photo.
  List<String?> photoSlots = [null, null, null, null];

  bool get isGroom => biodataType == 'পাত্রের বায়োডাটা';
  bool get isMuslim => religion == 'ইসলাম';

  static bool isUrl(String value) => value.startsWith('http://') || value.startsWith('https://');

  List<String> get keepPhotoUrls => [for (final p in photoSlots) if (p != null && isUrl(p)) p];
  List<String> get newPhotoPaths => [for (final p in photoSlots) if (p != null && !isUrl(p)) p];

  // Each education level only counts when the one below it was passed.
  bool get sscDone => sscPassed == yes;
  bool get hscDone => sscDone && hscPassed == yes;
  bool get graduationDone => hscDone && graduationPassed == yes;
  bool get postgraduationDone => graduationDone && postgraduationPassed == yes;

  /// The four yes/no education questions are asked one after another;
  /// changing an answer clears the ones below it so they are asked again.
  void setEducationAnswer(String field, String value) {
    switch (field) {
      case 'sscPassed':
        sscPassed = value;
        hscPassed = graduationPassed = postgraduationPassed = '';
      case 'hscPassed':
        hscPassed = value;
        graduationPassed = postgraduationPassed = '';
      case 'graduationPassed':
        graduationPassed = value;
        postgraduationPassed = '';
      case 'postgraduationPassed':
        postgraduationPassed = value;
    }
  }

  static Sibling blankSibling() => const Sibling(
        relation: 'বড় ভাই',
        profession: 'শিক্ষার্থী',
        maritalStatus: 'অবিবাহিত',
      );

  void setSiblingCount(int count) {
    final n = count < 0 ? 0 : (count > BiodataOptions.maxSiblings ? BiodataOptions.maxSiblings : count);
    final next = siblings.take(n).toList();
    while (next.length < n) {
      next.add(blankSibling());
    }
    siblings = next;
  }

  /// Pre-fills the wizard from an existing record, for editing
  /// (`mapInitialDataToForm` on the site).
  factory BiodataDraft.fromBiodata(Biodata source) {
    String yn(bool value) => value ? yes : no;
    final health = source.healthCondition ?? '';
    final prayer = source.prayerHabit ?? '';

    final draft = BiodataDraft()
      ..biodataType = source.isBride ? 'পাত্রীর বায়োডাটা' : 'পাত্রের বায়োডাটা'
      ..maritalStatus = source.maritalStatus ?? 'অবিবাহিত'
      ..permanentDistrict = source.permanentDistrict ?? ''
      ..permanentUpazila = source.permanentUpazila ?? ''
      ..currentDistrict = source.currentDistrict ?? ''
      ..currentUpazila = source.currentUpazila ?? ''
      ..currentAddress = source.currentAddress ?? ''
      ..dateOfBirth = source.dateOfBirth == null
          ? ''
          : source.dateOfBirth!.toIso8601String().split('T').first
      ..skinTone = source.skinTone ?? ''
      ..height = source.height ?? ''
      ..bloodGroup = source.bloodGroup ?? ''
      ..professionType = source.professionType ?? 'চাকরি'
      ..profession = source.profession ?? ''
      ..religion = source.religion ?? 'ইসলাম'
      ..educationMedium = source.educationMedium ?? 'জেনারেল'
      ..sscPassed = yn(source.sscPassed)
      ..sscYear = source.sscYear ?? ''
      ..sscInstitution = source.sscInstitution ?? ''
      ..sscGroup = source.sscGroup ?? ''
      ..hscPassed = yn(source.hscPassed)
      ..hscYear = source.hscYear ?? ''
      ..hscInstitution = source.hscInstitution ?? ''
      ..hscGroup = source.hscGroup ?? ''
      ..graduationPassed = yn(source.graduationPassed)
      ..institutionName = source.institutionName ?? ''
      ..graduationDepartment = source.graduationDepartment ?? ''
      ..graduationYear = source.graduationYear ?? ''
      ..postgraduationPassed = yn(source.postgraduationPassed)
      ..postgraduationInstitution = source.postgraduationInstitution ?? ''
      ..postgraduationDepartment = source.postgraduationDepartment ?? ''
      ..postgraduationYear = source.postgraduationYear ?? ''
      ..fatherName = source.fatherName ?? ''
      ..fatherProfession = source.fatherProfession ?? ''
      ..motherName = source.motherName ?? ''
      ..motherProfession = source.motherProfession ?? ''
      ..siblings = _siblingsFrom(source)
      // the older "নিয়মিত নয়" answer becomes the new wording
      ..prayerHabit = prayer.isEmpty || prayer == 'নিয়মিত নয়' ? 'নিয়মিত চেষ্টা করি' : prayer
      ..healthIssue = health.isEmpty ? '' : (health == no ? no : yes)
      ..healthDetails = health.isNotEmpty && health != no ? health : ''
      ..aboutSelf = source.aboutSelf ?? ''
      ..wifeEducationPermission = _or(source.wifeEducationPermission, yes)
      ..wifeJobPermission = _or(source.wifeJobPermission, 'আলোচনা সাপেক্ষে')
      ..whereWifeWillLive = source.whereWifeWillLive ?? ''
      ..expectedMaxAge = source.expectedMaxAge ?? ''
      ..expectedSkinTone = _or(source.expectedSkinTone, any)
      ..expectedMinHeight = _or(source.expectedMinHeight, any)
      ..expectedEducation = source.expectedEducation ?? ''
      ..expectedDistrict = source.expectedDistrict == any ? '' : (source.expectedDistrict ?? '')
      ..expectedMaritalStatus = _or(source.expectedMaritalStatus, any)
      ..expectedProfession = source.expectedProfession ?? ''
      ..expectedEconomicCondition = source.expectedEconomicCondition ?? ''
      ..expectedFamilyCondition = source.expectedFamilyCondition ?? ''
      ..expectedQualities = source.expectedQualities ?? ''
      ..guardianPhone = source.guardianPhone ?? ''
      ..guardianRelation = _or(source.guardianRelation, 'পিতা')
      ..email = source.email ?? ''
      ..photoSlots = [for (var i = 0; i < 4; i++) i < source.photos.length ? source.photos[i] : null]
      // An existing record was only saved because the policy was agreed to;
      // the server re-checks the flag on every edit.
      ..policyAgreed = true;
    return draft;
  }

  static String _or(String? value, String fallback) =>
      (value ?? '').isEmpty ? fallback : value!;

  // Siblings saved before the per-sibling cards existed only have counts, so
  // open the editor with that many empty cards to fill in.
  static List<Sibling> _siblingsFrom(Biodata source) {
    final saved = source.siblings;
    if (saved != null) {
      // a plain "ভাই"/"বোন" from an older save has no elder/younger; pick the elder one
      const fix = {'ভাই': 'বড় ভাই', 'বোন': 'বড় বোন'};
      return [
        for (final s in saved)
          Sibling(
            name: s.name,
            relation: fix[s.relation] ?? (s.relation.isEmpty ? 'বড় ভাই' : s.relation),
            profession: s.profession.isEmpty ? 'শিক্ষার্থী' : s.profession,
            organization: s.organization,
            maritalStatus: s.maritalStatus.isEmpty ? 'অবিবাহিত' : s.maritalStatus,
          ),
      ];
    }
    const limit = BiodataOptions.maxSiblings;
    final brothers = min(limit, max(0, source.brotherCount ?? 0));
    final sisters = min(limit - brothers, max(0, source.sisterCount ?? 0));
    return [
      for (var i = 0; i < brothers; i++) blankSibling(),
      for (var i = 0; i < sisters; i++)
        const Sibling(relation: 'বড় বোন', profession: 'শিক্ষার্থী', maritalStatus: 'অবিবাহিত'),
    ];
  }

  /// What the server stores for the illness question.
  String get healthCondition =>
      healthIssue == yes ? healthDetails.trim() : (healthIssue == no ? no : '');

  Map<String, String> toFormFields() => {
        'biodataType': biodataType,
        'maritalStatus': maritalStatus,
        'permanentDistrict': permanentDistrict,
        'permanentUpazila': permanentUpazila,
        'currentDistrict': currentDistrict,
        'currentUpazila': currentUpazila,
        'currentAddress': currentAddress,
        'dateOfBirth': dateOfBirth,
        'skinTone': skinTone,
        'height': height,
        'bloodGroup': bloodGroup,
        'professionType': professionType,
        'profession': profession,
        'religion': religion,
        'educationMedium': educationMedium,
        'sscPassed': sscPassed,
        'sscYear': sscYear,
        'sscInstitution': sscInstitution,
        'sscGroup': sscGroup,
        'hscPassed': hscPassed,
        'hscYear': hscYear,
        'hscInstitution': hscInstitution,
        'hscGroup': hscGroup,
        'graduationPassed': graduationPassed,
        'institutionName': institutionName,
        'graduationDepartment': graduationDepartment,
        'graduationYear': graduationYear,
        'postgraduationPassed': postgraduationPassed,
        'postgraduationInstitution': postgraduationInstitution,
        'postgraduationDepartment': postgraduationDepartment,
        'postgraduationYear': postgraduationYear,
        'fatherName': fatherName,
        'fatherProfession': fatherProfession,
        'motherName': motherName,
        'motherProfession': motherProfession,
        'siblingsJson': jsonEncode(siblings.map((s) => s.toJson()).toList()),
        'prayerHabit': prayerHabit,
        'healthCondition': healthCondition,
        'aboutSelf': aboutSelf,
        'wifeEducationPermission': wifeEducationPermission,
        'wifeJobPermission': wifeJobPermission,
        'whereWifeWillLive': whereWifeWillLive,
        'expectedMaxAge': expectedMaxAge,
        'expectedSkinTone': expectedSkinTone,
        'expectedMinHeight': expectedMinHeight,
        'expectedEducation': expectedEducation,
        'expectedProfession': expectedProfession,
        'expectedDistrict': expectedDistrict.isEmpty ? any : expectedDistrict,
        'expectedMaritalStatus': expectedMaritalStatus,
        'expectedEconomicCondition': expectedEconomicCondition,
        'expectedFamilyCondition': expectedFamilyCondition,
        'expectedQualities': expectedQualities,
        'noteToAdmin': noteToAdmin,
        'guardianPhone': guardianPhone,
        'guardianRelation': guardianRelation,
        'email': email,
        // The server checks for the literal string 'on'.
        'policyAgreed': policyAgreed ? 'on' : '',
      };

  /// The first empty required field of a wizard step (0–2) in on-screen order,
  /// as (field id, message), or null when the step is complete — the site's
  /// `checkPage1/2/3`.
  (String, String)? problemInStep(int step) {
    switch (step) {
      case 0:
        if (dateOfBirth.isEmpty) return ('dateOfBirth', 'Enter the date of birth');
        if (skinTone.isEmpty) return ('skinTone', 'Select skin tone');
        if (height.isEmpty) return ('height', 'Select height');
        if (bloodGroup.isEmpty) return ('bloodGroup', 'Select blood group');
        if (profession.trim().isEmpty) return ('profession', 'Enter the profession details');
        if (currentAddress.trim().isEmpty) {
          return ('currentAddress', 'Enter the current address');
        }
      case 1:
        if (sscPassed.isEmpty) {
          return ('sscPassed', 'Answer whether you passed SSC/equivalent');
        }
        if (sscDone) {
          if (sscYear.isEmpty) return ('sscYear', 'Select the passing year');
          if (sscGroup.isEmpty) return ('sscGroup', 'Select the group');
          if (sscInstitution.trim().isEmpty) return ('sscInstitution', 'Enter the institute name');
          if (hscPassed.isEmpty) {
            return ('hscPassed', 'Answer whether you passed HSC/equivalent');
          }
        }
        if (hscDone) {
          if (hscYear.isEmpty) return ('hscYear', 'Select the passing year');
          if (hscGroup.isEmpty) return ('hscGroup', 'Select the group');
          if (hscInstitution.trim().isEmpty) return ('hscInstitution', 'Enter the institute name');
          if (graduationPassed.isEmpty) {
            return ('graduationPassed', 'Answer whether you passed graduation/equivalent');
          }
        }
        if (graduationDone) {
          if (graduationYear.isEmpty) return ('graduationYear', 'Select the passing year');
          if (graduationDepartment.trim().isEmpty) {
            return ('graduationDepartment', 'Enter the department / degree name');
          }
          if (institutionName.trim().isEmpty) return ('institutionName', 'Enter the institute name');
          if (postgraduationPassed.isEmpty) {
            return (
              'postgraduationPassed',
              'Answer whether you passed post-graduation/equivalent',
            );
          }
        }
        if (postgraduationDone) {
          if (postgraduationYear.isEmpty) return ('postgraduationYear', 'Select the passing year');
          if (postgraduationDepartment.trim().isEmpty) {
            return ('postgraduationDepartment', 'Enter the department / degree name');
          }
          if (postgraduationInstitution.trim().isEmpty) {
            return ('postgraduationInstitution', 'Enter the institute name');
          }
        }
        if (fatherName.trim().isEmpty) return ('fatherName', 'Enter the father’s name');
        if (fatherProfession.trim().isEmpty) {
          return ('fatherProfession', 'Enter the father’s profession');
        }
        if (motherName.trim().isEmpty) return ('motherName', 'Enter the mother’s name');
        if (motherProfession.trim().isEmpty) {
          return ('motherProfession', 'Enter the mother’s profession');
        }
        if (healthIssue.isEmpty) {
          return ('healthIssue', 'Answer whether you have any mental or physical illness');
        }
        if (healthIssue == yes && healthDetails.trim().isEmpty) {
          return ('healthDetails', 'Give details of the illness');
        }
        if (aboutSelf.trim().isEmpty) return ('aboutSelf', 'Write something about yourself');
      case 2:
        if (!policyAgreed) return ('policyAgreed', 'You must agree to the policy to continue');
        if (!BiodataOptions.isValidMobile(guardianPhone)) {
          return ('guardianPhone', 'Enter the guardian’s valid mobile number');
        }
        if (guardianRelation.isEmpty) {
          return ('guardianRelation', 'Select the relationship with the guardian');
        }
    }
    return null;
  }

  /// The biodata as it will appear once published, so the preview step can
  /// show it in the same document layout (`previewData()` on the site).
  Biodata toPreview({required String biodataNo}) {
    final dob = DateTime.tryParse(dateOfBirth);
    int? age;
    if (dob != null) {
      final now = DateTime.now();
      age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age -= 1;
      if (age < 0) age = 0;
    }
    return Biodata(
      id: '',
      biodataNo: biodataNo,
      gender: isGroom ? 'পুরুষ' : 'মহিলা',
      maritalStatus: maritalStatus,
      permanentDistrict: permanentDistrict,
      permanentUpazila: permanentUpazila,
      currentDistrict: currentDistrict,
      currentUpazila: currentUpazila,
      currentAddress: currentAddress,
      dateOfBirth: dob,
      age: age,
      religion: religion,
      skinTone: skinTone,
      height: height,
      bloodGroup: bloodGroup,
      professionType: professionType,
      profession: profession,
      area: [currentUpazila, permanentUpazila, currentDistrict]
          .firstWhere((e) => e.isNotEmpty, orElse: () => ''),
      educationMedium: educationMedium,
      sscPassed: sscDone,
      sscYear: sscYear,
      sscInstitution: sscInstitution,
      sscGroup: sscGroup,
      hscPassed: hscDone,
      hscYear: hscYear,
      hscInstitution: hscInstitution,
      hscGroup: hscGroup,
      graduationPassed: graduationDone,
      institutionName: institutionName,
      graduationDepartment: graduationDepartment,
      graduationYear: graduationYear,
      postgraduationPassed: postgraduationDone,
      postgraduationInstitution: postgraduationInstitution,
      postgraduationDepartment: postgraduationDepartment,
      postgraduationYear: postgraduationYear,
      fatherName: fatherName,
      fatherProfession: fatherProfession,
      motherName: motherName,
      motherProfession: motherProfession,
      siblings: siblings,
      sisterCount: siblings.where((s) => s.relation.endsWith('বোন')).length,
      brotherCount: siblings.where((s) => s.relation.endsWith('ভাই')).length,
      prayerHabit: isMuslim ? prayerHabit : null,
      healthCondition: healthIssue.isEmpty ? null : healthCondition,
      aboutSelf: aboutSelf,
      wifeEducationPermission: isGroom ? wifeEducationPermission : null,
      wifeJobPermission: isGroom ? wifeJobPermission : null,
      whereWifeWillLive: isGroom ? whereWifeWillLive : null,
      expectedMaxAge: expectedMaxAge,
      expectedSkinTone: expectedSkinTone,
      expectedMinHeight: expectedMinHeight,
      expectedEducation: expectedEducation,
      expectedProfession: expectedProfession,
      expectedDistrict: expectedDistrict.isEmpty ? any : expectedDistrict,
      expectedMaritalStatus: expectedMaritalStatus,
      expectedEconomicCondition: expectedEconomicCondition,
      expectedFamilyCondition: expectedFamilyCondition,
      expectedQualities: expectedQualities,
      photos: [for (final p in photoSlots) if (p != null) p],
    );
  }
}

class BiodataRepository {
  const BiodataRepository(this._api);

  final ApiClient _api;

  /// Public list — admin-verified profiles only, without the contact block.
  ///
  /// Always asked of the server: a biodata an admin has just verified must
  /// show up right away, as it does on the site. The saved copy is only the
  /// offline fallback.
  Future<List<Biodata>> list() async {
    final body = await _api.get(
      '/api/biodata',
      cacheTtl: CacheTtl.feed,
      forceRefresh: true,
    );
    return parseList(body, Biodata.fromJson);
  }

  Future<BiodataDetail> detail(String id) async {
    final body = await _api.get('/api/biodata/$id');
    return BiodataDetail.fromJson(body is Map<String, dynamic> ? body : const {});
  }

  Future<List<Biodata>> mine() async {
    final body = await _api.get('/api/me/biodata');
    return parseList(body, Biodata.fromJson);
  }

  /// Submits a new biodata. It stays hidden until an admin verifies it.
  Future<({String id, String biodataNo})> create(BiodataDraft draft) async {
    final form = FormData.fromMap(draft.toFormFields());
    for (final path in draft.newPhotoPaths.take(BiodataOptions.maxPhotos)) {
      form.files.add(MapEntry('photos', await MultipartFile.fromFile(path)));
    }
    final body = await _api.upload('/api/biodata/create', form);
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final id = map.str('id');

    // The create route already attaches the submitter, but claiming is
    // harmless and covers a row that was somehow left unlinked.
    if (id.isNotEmpty) {
      try {
        await _api.post('/api/biodata/$id/claim');
      } on ApiException {
        // Already claimed — nothing to do.
      }
    }
    return (id: id, biodataNo: map.str('biodataNo'));
  }

  Future<void> update(String id, BiodataDraft draft) async {
    final form = FormData.fromMap({
      ...draft.toFormFields(),
      'keepPhotoUrls': jsonEncode(draft.keepPhotoUrls),
    });
    final slots = BiodataOptions.maxPhotos - draft.keepPhotoUrls.length;
    if (slots > 0) {
      for (final path in draft.newPhotoPaths.take(slots)) {
        form.files.add(MapEntry('photos', await MultipartFile.fromFile(path)));
      }
    }
    await _api.upload('/api/biodata/$id', form, method: 'PATCH');
  }

  /// Opens a biodata. Uses an unused package slot when the viewer has one,
  /// otherwise spends coins on [packageId]. Access, once granted, is permanent.
  Future<Map<String, dynamic>> unlock(String id, {String? packageId}) async {
    final body = await _api.post(
      '/api/biodata/$id/unlock',
      body: packageId == null ? null : {'packageId': packageId},
    );
    return body is Map<String, dynamic> ? body : const {};
  }

  Future<List<BiodataPackage>> packages() async {
    final body = await _api.get(
      '/api/biodata-subscription-packages',
      cacheTtl: CacheTtl.reference,
    );
    return parseList(body, BiodataPackage.fromJson);
  }
}
