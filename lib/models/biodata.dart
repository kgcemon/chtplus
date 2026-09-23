import '../core/utils/json.dart';

/// Option lists ported from the website's biodata wizard. The stored values are
/// Bengali and are compared in code, so they must be sent back verbatim.
class BiodataOptions {
  const BiodataOptions._();

  static const types = ['পাত্রের বায়োডাটা', 'পাত্রীর বায়োডাটা'];
  static const maritalStatuses = ['অবিবাহিত', 'বিবাহিত', 'ডিভোর্সড', 'বিধবা', 'বিপত্নীক'];
  static const professionTypes = ['চাকরি', 'ব্যবসা', 'উদ্যোক্তা', 'শিক্ষার্থী', 'অন্যান্য'];
  static const skinTones = ['শ্যামলা', 'উজ্জ্বল শ্যামলা', 'ফর্সা', 'উজ্জ্বল ফর্সা'];
  static const bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'জানা নেই'];
  static const educationGroups = ['বিজ্ঞান', 'মানবিক', 'ব্যবসায় শিক্ষা', 'অন্যান্য'];
  static const educationMediums = ['জেনারেল', 'কারিগরি', 'মাদ্রাসা'];
  static const religions = ['ইসলাম', 'হিন্দু', 'বৌদ্ধ', 'খ্রিস্টান', 'অন্যান্য'];
  static const yesNo = ['হ্যাঁ', 'না'];
  static const guardianRelations = ['পিতা', 'মাতা', 'ভাই', 'বোন', 'নিজ', 'স্থানীয় অভিভাবক'];
  static const siblingRelations = ['বড় ভাই', 'ছোট ভাই', 'বড় বোন', 'ছোট বোন'];
  static const prayerHabits = ['নিয়মিত', 'নিয়মিত চেষ্টা করি', 'নিয়মিত নয়'];

  /// 4'1" through 7'0", exactly as `heightOptions()` builds them.
  static List<String> heights() {
    final result = <String>[];
    for (var ft = 4; ft <= 7; ft++) {
      final minIn = ft == 4 ? 1 : 0;
      final maxIn = ft == 7 ? 0 : 11;
      for (var inch = minIn; inch <= maxIn; inch++) {
        result.add("$ft'$inch\"");
      }
    }
    return result;
  }

  static List<String> years() {
    final current = DateTime.now().year;
    return [for (var y = current; y >= 1980; y--) y.toString()];
  }

  static const maxPhotos = 4;
  static const maxSiblings = 10;

  /// `01[3-9]` followed by 8 digits — the same rule the server enforces.
  static bool isValidMobile(String value) =>
      RegExp(r'^01[3-9]\d{8}$').hasMatch(value.trim());
}

class Sibling {
  const Sibling({
    this.name = '',
    this.relation = 'বড় ভাই',
    this.profession = '',
    this.organization = '',
    this.maritalStatus = '',
  });

  final String name;
  final String relation;
  final String profession;
  final String organization;
  final String maritalStatus;

  factory Sibling.fromJson(Map<String, dynamic> json) => Sibling(
        name: json.str('name'),
        relation: json.str('relation', fallback: 'বড় ভাই'),
        profession: json.str('profession'),
        organization: json.str('organization'),
        maritalStatus: json.str('maritalStatus'),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'relation': relation,
        'profession': profession,
        'organization': organization,
        'maritalStatus': maritalStatus,
      };
}

/// A matrimony biodata. Public listings carry only the non-private fields; the
/// contact block (mobile, guardian, email) is filled in once the viewer has
/// unlocked the profile.
class Biodata {
  const Biodata({
    required this.id,
    this.biodataNo,
    this.forWhom,
    this.mobileNumber,
    this.gender,
    this.maritalStatus,
    this.permanentDistrict,
    this.permanentUpazila,
    this.currentDistrict,
    this.currentUpazila,
    this.currentAddress,
    this.dateOfBirth,
    this.age,
    this.religion,
    this.skinTone,
    this.height,
    this.weight,
    this.bloodGroup,
    this.professionType,
    this.profession,
    this.monthlyIncome,
    this.area,
    this.unlocked = false,
    this.educationMedium,
    this.sscPassed = false,
    this.sscYear,
    this.sscInstitution,
    this.sscGroup,
    this.hscPassed = false,
    this.hscYear,
    this.hscInstitution,
    this.hscGroup,
    this.graduationPassed = false,
    this.institutionName,
    this.graduationYear,
    this.graduationDepartment,
    this.postgraduationPassed = false,
    this.postgraduationInstitution,
    this.postgraduationDepartment,
    this.postgraduationYear,
    this.otherEducation,
    this.fatherName,
    this.fatherProfession,
    this.motherName,
    this.motherProfession,
    this.sisterCount,
    this.brotherCount,
    this.siblingsProfession,
    this.siblings,
    this.prayerHabit,
    this.politicalAffiliation,
    this.healthCondition,
    this.aboutSelf,
    this.wifeEducationPermission,
    this.wifeJobPermission,
    this.whereWifeWillLive,
    this.dowryExpectation,
    this.expectedMaxAge,
    this.expectedSkinTone,
    this.expectedMinHeight,
    this.expectedEducation,
    this.expectedProfession,
    this.expectedDistrict,
    this.expectedMaritalStatus,
    this.otherRequirements,
    this.expectedEconomicCondition,
    this.expectedFamilyCondition,
    this.expectedQualities,
    this.guardianPhone,
    this.guardianRelation,
    this.email,
    this.contactPhone,
    this.photos = const [],
  });

  final String id;
  final String? biodataNo;
  final String? forWhom;
  final String? mobileNumber;
  final String? gender;
  final String? maritalStatus;
  final String? permanentDistrict;
  final String? permanentUpazila;
  final String? currentDistrict;
  final String? currentUpazila;
  final String? currentAddress;
  final DateTime? dateOfBirth;
  final int? age;
  final String? religion;
  final String? skinTone;
  final String? height;
  final String? weight;
  final String? bloodGroup;
  final String? professionType;
  final String? profession;
  final String? monthlyIncome;
  final String? area;
  final bool unlocked;
  final String? educationMedium;
  final bool sscPassed;
  final String? sscYear;
  final String? sscInstitution;
  final String? sscGroup;
  final bool hscPassed;
  final String? hscYear;
  final String? hscInstitution;
  final String? hscGroup;
  final bool graduationPassed;
  final String? institutionName;
  final String? graduationYear;
  final String? graduationDepartment;
  final bool postgraduationPassed;
  final String? postgraduationInstitution;
  final String? postgraduationDepartment;
  final String? postgraduationYear;
  final String? otherEducation;
  final String? fatherName;
  final String? fatherProfession;
  final String? motherName;
  final String? motherProfession;
  final int? sisterCount;
  final int? brotherCount;
  final String? siblingsProfession;
  final List<Sibling>? siblings;
  final String? prayerHabit;
  final String? politicalAffiliation;
  final String? healthCondition;
  final String? aboutSelf;
  final String? wifeEducationPermission;
  final String? wifeJobPermission;
  final String? whereWifeWillLive;
  final String? dowryExpectation;
  final String? expectedMaxAge;
  final String? expectedSkinTone;
  final String? expectedMinHeight;
  final String? expectedEducation;
  final String? expectedProfession;
  final String? expectedDistrict;
  final String? expectedMaritalStatus;
  final String? otherRequirements;
  final String? expectedEconomicCondition;
  final String? expectedFamilyCondition;
  final String? expectedQualities;
  final String? guardianPhone;
  final String? guardianRelation;
  final String? email;
  final String? contactPhone;
  final List<String> photos;

  factory Biodata.fromJson(Map<String, dynamic> json) {
    final siblingsRaw = json['siblings'];
    return Biodata(
      id: json.str('id'),
      biodataNo: json.strOrNull('biodataNo'),
      forWhom: json.strOrNull('forWhom'),
      mobileNumber: json.strOrNull('mobileNumber'),
      gender: json.strOrNull('gender'),
      maritalStatus: json.strOrNull('maritalStatus'),
      permanentDistrict: json.strOrNull('permanentDistrict'),
      permanentUpazila: json.strOrNull('permanentUpazila'),
      currentDistrict: json.strOrNull('currentDistrict'),
      currentUpazila: json.strOrNull('currentUpazila'),
      currentAddress: json.strOrNull('currentAddress'),
      dateOfBirth: json.date('dateOfBirth'),
      age: json.intOrNull('age'),
      religion: json.strOrNull('religion'),
      skinTone: json.strOrNull('skinTone'),
      height: json.strOrNull('height'),
      weight: json.strOrNull('weight'),
      bloodGroup: json.strOrNull('bloodGroup'),
      professionType: json.strOrNull('professionType'),
      profession: json.strOrNull('profession'),
      monthlyIncome: json.strOrNull('monthlyIncome'),
      area: json.strOrNull('area'),
      unlocked: json.flag('unlocked'),
      educationMedium: json.strOrNull('educationMedium'),
      sscPassed: json.flag('sscPassed'),
      sscYear: json.strOrNull('sscYear'),
      sscInstitution: json.strOrNull('sscInstitution'),
      sscGroup: json.strOrNull('sscGroup'),
      hscPassed: json.flag('hscPassed'),
      hscYear: json.strOrNull('hscYear'),
      hscInstitution: json.strOrNull('hscInstitution'),
      hscGroup: json.strOrNull('hscGroup'),
      graduationPassed: json.flag('graduationPassed'),
      institutionName: json.strOrNull('institutionName'),
      graduationYear: json.strOrNull('graduationYear'),
      graduationDepartment: json.strOrNull('graduationDepartment'),
      postgraduationPassed: json.flag('postgraduationPassed'),
      postgraduationInstitution: json.strOrNull('postgraduationInstitution'),
      postgraduationDepartment: json.strOrNull('postgraduationDepartment'),
      postgraduationYear: json.strOrNull('postgraduationYear'),
      otherEducation: json.strOrNull('otherEducation'),
      fatherName: json.strOrNull('fatherName'),
      fatherProfession: json.strOrNull('fatherProfession'),
      motherName: json.strOrNull('motherName'),
      motherProfession: json.strOrNull('motherProfession'),
      sisterCount: json.intOrNull('sisterCount'),
      brotherCount: json.intOrNull('brotherCount'),
      siblingsProfession: json.strOrNull('siblingsProfession'),
      siblings: siblingsRaw is List
          ? siblingsRaw
              .whereType<Map<String, dynamic>>()
              .map(Sibling.fromJson)
              .toList()
          : null,
      prayerHabit: json.strOrNull('prayerHabit'),
      politicalAffiliation: json.strOrNull('politicalAffiliation'),
      healthCondition: json.strOrNull('healthCondition'),
      aboutSelf: json.strOrNull('aboutSelf'),
      wifeEducationPermission: json.strOrNull('wifeEducationPermission'),
      wifeJobPermission: json.strOrNull('wifeJobPermission'),
      whereWifeWillLive: json.strOrNull('whereWifeWillLive'),
      dowryExpectation: json.strOrNull('dowryExpectation'),
      expectedMaxAge: json.strOrNull('expectedMaxAge'),
      expectedSkinTone: json.strOrNull('expectedSkinTone'),
      expectedMinHeight: json.strOrNull('expectedMinHeight'),
      expectedEducation: json.strOrNull('expectedEducation'),
      expectedProfession: json.strOrNull('expectedProfession'),
      expectedDistrict: json.strOrNull('expectedDistrict'),
      expectedMaritalStatus: json.strOrNull('expectedMaritalStatus'),
      otherRequirements: json.strOrNull('otherRequirements'),
      expectedEconomicCondition: json.strOrNull('expectedEconomicCondition'),
      expectedFamilyCondition: json.strOrNull('expectedFamilyCondition'),
      expectedQualities: json.strOrNull('expectedQualities'),
      guardianPhone: json.strOrNull('guardianPhone'),
      guardianRelation: json.strOrNull('guardianRelation'),
      email: json.strOrNull('email'),
      contactPhone: json.strOrNull('contactPhone'),
      photos: json.stringList('photos'),
    );
  }

  bool get isBride => gender == 'মহিলা';

  String get locationLabel => [currentUpazila, currentDistrict]
      .where((e) => e != null && e.isNotEmpty)
      .join(', ');
}

/// The detail response wraps the biodata in an access state: either the full
/// record, or a teaser plus the packages needed to unlock it.
class BiodataDetail {
  const BiodataDetail({
    required this.biodata,
    required this.locked,
    required this.hasAccess,
    this.packages = const [],
    this.walletAvailable = false,
    this.walletRemaining = 0,
    this.coinBalance = 0,
    this.loginRequired = false,
  });

  final Biodata biodata;
  final bool locked;
  final bool hasAccess;
  final List<BiodataPackage> packages;
  final bool walletAvailable;
  final int walletRemaining;
  final int coinBalance;
  final bool loginRequired;

  factory BiodataDetail.fromJson(Map<String, dynamic> json) => BiodataDetail(
        biodata: Biodata.fromJson(json),
        locked: json.flag('locked'),
        hasAccess: json.flag('hasAccess'),
        packages: json.mapList('packages').map(BiodataPackage.fromJson).toList(),
        walletAvailable: json.flag('walletAvailable'),
        walletRemaining: json.intOr('walletRemaining'),
        coinBalance: json.intOr('coinBalance'),
        loginRequired: json.flag('loginRequired'),
      );
}

class BiodataPackage {
  const BiodataPackage({
    required this.id,
    required this.name,
    required this.biodataCount,
    required this.coinCost,
  });

  final String id;
  final String name;
  final int biodataCount;
  final int coinCost;

  factory BiodataPackage.fromJson(Map<String, dynamic> json) => BiodataPackage(
        id: json.str('id'),
        name: json.str('name'),
        biodataCount: json.intOr('biodataCount'),
        coinCost: json.intOr('coinCost'),
      );
}
