import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/api/response_cache.dart';
import '../core/utils/json.dart';
import '../models/biodata.dart';

/// Everything the biodata wizard collects. Field names match the form keys
/// `lib/biodataFields.js` parses on the server.
class BiodataDraft {
  BiodataDraft();

  String biodataType = BiodataOptions.types.first;
  String maritalStatus = BiodataOptions.maritalStatuses.first;
  String permanentDistrict = '';
  String permanentUpazila = '';
  String currentDistrict = '';
  String currentUpazila = '';
  String currentAddress = '';
  String dateOfBirth = '';
  String skinTone = '';
  String height = '';
  String bloodGroup = '';
  String professionType = BiodataOptions.professionTypes.first;
  String profession = '';
  String religion = '';

  String educationMedium = '';
  bool sscPassed = false;
  String sscYear = '';
  String sscInstitution = '';
  String sscGroup = '';
  bool hscPassed = false;
  String hscYear = '';
  String hscInstitution = '';
  String hscGroup = '';
  bool graduationPassed = false;
  String institutionName = '';
  String graduationDepartment = '';
  String graduationYear = '';
  bool postgraduationPassed = false;
  String postgraduationInstitution = '';
  String postgraduationDepartment = '';
  String postgraduationYear = '';

  String fatherName = '';
  String fatherProfession = '';
  String motherName = '';
  String motherProfession = '';
  List<Sibling> siblings = [];

  String prayerHabit = '';
  String healthCondition = '';
  String aboutSelf = '';

  String wifeEducationPermission = '';
  String wifeJobPermission = '';
  String whereWifeWillLive = '';

  String expectedMaxAge = '';
  String expectedSkinTone = '';
  String expectedMinHeight = '';
  String expectedEducation = '';
  String expectedProfession = '';
  String expectedDistrict = '';
  String expectedMaritalStatus = '';
  String expectedEconomicCondition = '';
  String expectedFamilyCondition = '';
  String expectedQualities = '';

  String noteToAdmin = '';
  String guardianPhone = '';
  String guardianRelation = BiodataOptions.guardianRelations.first;
  String email = '';
  bool policyAgreed = false;

  List<String> newPhotoPaths = [];
  List<String> keepPhotoUrls = [];

  bool get isGroom => biodataType != 'পাত্রীর বায়োডাটা';

  /// Pre-fills the wizard from an existing record, for editing.
  factory BiodataDraft.fromBiodata(Biodata source) {
    final draft = BiodataDraft()
      ..biodataType = source.isBride ? 'পাত্রীর বায়োডাটা' : 'পাত্রের বায়োডাটা'
      ..maritalStatus = source.maritalStatus ?? BiodataOptions.maritalStatuses.first
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
      ..professionType = source.professionType ?? BiodataOptions.professionTypes.first
      ..profession = source.profession ?? ''
      ..religion = source.religion ?? ''
      ..educationMedium = source.educationMedium ?? ''
      ..sscPassed = source.sscPassed
      ..sscYear = source.sscYear ?? ''
      ..sscInstitution = source.sscInstitution ?? ''
      ..sscGroup = source.sscGroup ?? ''
      ..hscPassed = source.hscPassed
      ..hscYear = source.hscYear ?? ''
      ..hscInstitution = source.hscInstitution ?? ''
      ..hscGroup = source.hscGroup ?? ''
      ..graduationPassed = source.graduationPassed
      ..institutionName = source.institutionName ?? ''
      ..graduationDepartment = source.graduationDepartment ?? ''
      ..graduationYear = source.graduationYear ?? ''
      ..postgraduationPassed = source.postgraduationPassed
      ..postgraduationInstitution = source.postgraduationInstitution ?? ''
      ..postgraduationDepartment = source.postgraduationDepartment ?? ''
      ..postgraduationYear = source.postgraduationYear ?? ''
      ..fatherName = source.fatherName ?? ''
      ..fatherProfession = source.fatherProfession ?? ''
      ..motherName = source.motherName ?? ''
      ..motherProfession = source.motherProfession ?? ''
      ..siblings = List.of(source.siblings ?? const [])
      ..prayerHabit = source.prayerHabit ?? ''
      ..healthCondition = source.healthCondition ?? ''
      ..aboutSelf = source.aboutSelf ?? ''
      ..wifeEducationPermission = source.wifeEducationPermission ?? ''
      ..wifeJobPermission = source.wifeJobPermission ?? ''
      ..whereWifeWillLive = source.whereWifeWillLive ?? ''
      ..expectedMaxAge = source.expectedMaxAge ?? ''
      ..expectedSkinTone = source.expectedSkinTone ?? ''
      ..expectedMinHeight = source.expectedMinHeight ?? ''
      ..expectedEducation = source.expectedEducation ?? ''
      ..expectedProfession = source.expectedProfession ?? ''
      ..expectedDistrict = source.expectedDistrict ?? ''
      ..expectedMaritalStatus = source.expectedMaritalStatus ?? ''
      ..expectedEconomicCondition = source.expectedEconomicCondition ?? ''
      ..expectedFamilyCondition = source.expectedFamilyCondition ?? ''
      ..expectedQualities = source.expectedQualities ?? ''
      ..guardianPhone = source.guardianPhone ?? ''
      ..guardianRelation = source.guardianRelation ?? BiodataOptions.guardianRelations.first
      ..email = source.email ?? ''
      ..keepPhotoUrls = List.of(source.photos)
      // An existing record was only saved because the policy was agreed to;
      // the server re-checks the flag on every edit.
      ..policyAgreed = true;
    return draft;
  }

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
        'sscPassed': sscPassed ? 'হ্যাঁ' : 'না',
        'sscYear': sscYear,
        'sscInstitution': sscInstitution,
        'sscGroup': sscGroup,
        'hscPassed': hscPassed ? 'হ্যাঁ' : 'না',
        'hscYear': hscYear,
        'hscInstitution': hscInstitution,
        'hscGroup': hscGroup,
        'graduationPassed': graduationPassed ? 'হ্যাঁ' : 'না',
        'institutionName': institutionName,
        'graduationDepartment': graduationDepartment,
        'graduationYear': graduationYear,
        'postgraduationPassed': postgraduationPassed ? 'হ্যাঁ' : 'না',
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
        'expectedDistrict': expectedDistrict,
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

  /// Mirrors the server's own required-field check so the wizard can point at
  /// the offending step before making a round trip.
  String? validate() {
    final missing = biodataType.isEmpty ||
        maritalStatus.isEmpty ||
        permanentDistrict.isEmpty ||
        currentDistrict.isEmpty ||
        currentAddress.isEmpty ||
        dateOfBirth.isEmpty ||
        skinTone.isEmpty ||
        height.isEmpty ||
        bloodGroup.isEmpty ||
        professionType.isEmpty ||
        profession.isEmpty ||
        fatherName.isEmpty ||
        fatherProfession.isEmpty ||
        motherName.isEmpty ||
        motherProfession.isEmpty ||
        aboutSelf.isEmpty ||
        guardianPhone.isEmpty ||
        guardianRelation.isEmpty;
    if (missing) return 'Fill in all required (*) fields';
    if (!policyAgreed) return 'You must agree to the policy to continue';
    if (!BiodataOptions.isValidMobile(guardianPhone)) {
      return 'Enter a valid Bangladeshi mobile number';
    }
    if (graduationPassed &&
        (institutionName.isEmpty || graduationDepartment.isEmpty || graduationYear.isEmpty)) {
      return 'Fill in the graduation institution, department/degree and passing year';
    }
    if (postgraduationPassed &&
        (postgraduationInstitution.isEmpty ||
            postgraduationDepartment.isEmpty ||
            postgraduationYear.isEmpty)) {
      return 'Fill in the post-graduation institution, department/degree and passing year';
    }
    return null;
  }
}

class BiodataRepository {
  const BiodataRepository(this._api);

  final ApiClient _api;

  /// Public list — admin-verified profiles only, without the contact block.
  Future<List<Biodata>> list({bool forceRefresh = false}) async {
    final body = await _api.get(
      '/api/biodata',
      cacheTtl: CacheTtl.feed,
      forceRefresh: forceRefresh,
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
