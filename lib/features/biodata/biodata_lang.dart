import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/prefs.dart';
import '../../core/theme.dart';
import '../../core/utils/data_labels.dart';

/// The English | বাংলা choice on the biodata form, like the site's
/// `BiodataLang`. Remembered on the device under the same key the site uses.
enum BiodataLang { en, bn }

const _storageKey = 'biodata_lang';

class BiodataLangController extends Notifier<BiodataLang> {
  @override
  BiodataLang build() {
    try {
      return Prefs.instance.getString(_storageKey) == 'bn' ? BiodataLang.bn : BiodataLang.en;
    } catch (_) {
      return BiodataLang.en;
    }
  }

  void set(BiodataLang lang) {
    state = lang;
    try {
      Prefs.instance.setString(_storageKey, lang.name);
    } catch (_) {
      // storage unavailable — the choice just lasts for this session
    }
  }
}

final biodataLangProvider =
    NotifierProvider<BiodataLangController, BiodataLang>(BiodataLangController.new);

/// Text helpers for the current language: [t] translates the English UI
/// strings, [dl] labels a stored (Bengali) option value. Stored values are
/// never changed — only what is shown on screen.
class BiodataText {
  const BiodataText(this.lang);

  final BiodataLang lang;

  bool get isBn => lang == BiodataLang.bn;

  String t(String text) => isBn ? (_bn[text] ?? text) : text;

  String dl(String? value) => isBn ? (value ?? '') : dataLabel(value);
}

final biodataTextProvider = Provider<BiodataText>((ref) => BiodataText(ref.watch(biodataLangProvider)));

/// The English | বাংলা pill switch shown at the top of the biodata form
/// (`.lang-switch` on the site).
class BiodataLangSwitch extends ConsumerWidget {
  const BiodataLangSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(biodataLangProvider);

    Widget option(BiodataLang value, String label) {
      final active = lang == value;
      return Material(
        color: active ? AppColors.forest : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => ref.read(biodataLangProvider.notifier).set(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.text,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(BiodataLang.en, 'English'),
          option(BiodataLang.bn, 'বাংলা'),
        ],
      ),
    );
  }
}

/// Bengali for every English string on the biodata form and its preview,
/// copied from the site's `lib/biodataI18n.js` (plus a few app-only strings).
/// Keys are the English text used in the code; anything missing stays English.
const _bn = <String, String>{
  'Submit biodata': 'বায়োডাটা জমা দিন',
  'Fill in the information below correctly; your biodata will be published after verification': 'নিচের তথ্যগুলো সঠিকভাবে পূরণ করুন; যাচাইয়ের পর আপনার বায়োডাটা প্রকাশ করা হবে',
  'General Information': 'সাধারণ তথ্য',
  'Education & Family': 'শিক্ষা ও পরিবার',
  'Life Partner & Contact': 'জীবনসঙ্গী ও যোগাযোগ',
  'Preview': 'প্রিভিউ',
  '← Previous': '← পূর্ববর্তী',
  'Next →': 'পরবর্তী →',
  'Preview biodata →': 'বায়োডাটা প্রিভিউ →',
  '← Edit biodata': '← বায়োডাটা সম্পাদনা',
  'Saving...': 'সংরক্ষণ হচ্ছে...',
  'Save changes': 'পরিবর্তন সংরক্ষণ করুন',
  'Your biodata has been submitted successfully.': 'আপনার বায়োডাটা সফলভাবে জমা হয়েছে।',
  'Your biodata number': 'আপনার বায়োডাটা নম্বর',
  'It will be published on the website after verification. Please save this number.': 'যাচাইয়ের পর এটি ওয়েবসাইটে প্রকাশ করা হবে। অনুগ্রহ করে এই নম্বরটি সংরক্ষণ করে রাখুন।',
  'Back to home page': 'হোম পেজে ফিরে যান',
  'This is how your biodata will look once it is published. Check everything, then submit. To change something, go back and edit.': 'প্রকাশিত হলে আপনার বায়োডাটা এভাবেই দেখাবে। সবকিছু দেখে নিয়ে জমা দিন। কিছু বদলাতে চাইলে পিছনে গিয়ে সম্পাদনা করুন।',
  'This is how your biodata will look once it is published. Check everything, then save your changes. To change something, go back and edit.': 'প্রকাশিত হলে আপনার বায়োডাটা এভাবেই দেখাবে। সবকিছু দেখে নিয়ে পরিবর্তন সংরক্ষণ করুন। কিছু বদলাতে চাইলে পিছনে গিয়ে সম্পাদনা করুন।',
  'Biodata type': 'বায়োডাটার ধরন',
  'Groom’s biodata': 'পাত্রের বায়োডাটা',
  'Bride’s biodata': 'পাত্রীর বায়োডাটা',
  'Marital status': 'বৈবাহিক অবস্থা',
  'Date of birth': 'জন্ম তারিখ',
  'Skin tone': 'গায়ের রং',
  'Height': 'উচ্চতা',
  'Blood group': 'রক্তের গ্রুপ',
  'Profession type': 'পেশার ধরন',
  'Profession details': 'পেশার বিবরণ',
  'e.g. Assistant teacher, Govt. High School · Officer, Krishi Bank': 'যেমন: সহকারী শিক্ষক, সরকারি উচ্চ বিদ্যালয় · কর্মকর্তা, কৃষি ব্যাংক',
  'Religion': 'ধর্ম',
  'Islam': 'ইসলাম',
  'Hinduism': 'হিন্দু',
  'Buddhism': 'বৌদ্ধ',
  'Christianity': 'খ্রিস্টান',
  'Other': 'অন্যান্য',
  'Select': 'নির্বাচন করুন',
  'Any': 'যেকোনো',
  'Yes': 'হ্যাঁ',
  'No': 'না',
  'Address': 'ঠিকানা',
  'Permanent address — District': 'স্থায়ী ঠিকানা — জেলা',
  'Permanent address — Thana': 'স্থায়ী ঠিকানা — থানা',
  'Current address — District': 'বর্তমান ঠিকানা — জেলা',
  'Current address — Thana': 'বর্তমান ঠিকানা — থানা',
  'Current address (details)': 'বর্তমান ঠিকানা (বিস্তারিত)',
  'e.g. House no. / Holding no., Area name, Ward no.': 'যেমন: বাড়ি নং / হোল্ডিং নং, এলাকার নাম, ওয়ার্ড নং',
  'Upload photos (max 4)': 'ছবি আপলোড করুন (সর্বোচ্চ ৪টি)',
  'Main photo': 'প্রধান ছবি',
  'Remove image': 'ছবি সরান',
  'Which medium did you study in?': 'আপনি কোন মাধ্যমে পড়াশোনা করেছেন?',
  'General': 'জেনারেল',
  'Technical': 'কারিগরি',
  'Madrasa': 'মাদ্রাসা',
  'Did you pass SSC/equivalent?': 'আপনি কি এসএসসি/সমমান পাস করেছেন?',
  'Did you pass HSC/equivalent?': 'আপনি কি এইচএসসি/সমমান পাস করেছেন?',
  'Did you pass graduation/equivalent?': 'আপনি কি স্নাতক/সমমান পাস করেছেন?',
  'Did you pass post-graduation/equivalent?': 'আপনি কি স্নাতকোত্তর/সমমান পাস করেছেন?',
  'SSC passing year': 'এসএসসি পাসের বছর',
  'HSC passing year': 'এইচএসসি পাসের বছর',
  'Passing year': 'পাসের বছর',
  'Group': 'গ্রুপ',
  'Institute name': 'প্রতিষ্ঠানের নাম',
  'Department / degree name': 'বিভাগ / ডিগ্রির নাম',
  'e.g. BSc in CSE': 'যেমন: সিএসইতে বিএসসি',
  'e.g. MSc in Physics': 'যেমন: পদার্থবিজ্ঞানে এমএসসি',
  'Family Information': 'পারিবারিক তথ্য',
  'Father’s name': 'পিতার নাম',
  'Father’s profession': 'পিতার পেশা',
  'Mother’s name': 'মাতার নাম',
  'Mother’s profession': 'মাতার পেশা',
  'How many siblings do you have?': 'আপনার কয়জন ভাই-বোন আছে?',
  'Sibling': 'ভাই/বোন',
  'Name': 'নাম',
  'Relationship': 'সম্পর্ক',
  'Profession': 'পেশা',
  'Organization / institute': 'প্রতিষ্ঠান / সংস্থা',
  'Elder brother': 'বড় ভাই',
  'Elder sister': 'বড় বোন',
  'Younger brother': 'ছোট ভাই',
  'Younger sister': 'ছোট বোন',
  'Personal information': 'ব্যক্তিগত তথ্য',
  'Do you pray five times a day?': 'আপনি কি পাঁচ ওয়াক্ত নামাজ পড়েন?',
  'Try to pray regularly': 'নিয়মিত চেষ্টা করি',
  'Do you have any mental or physical illness?': 'আপনার কি কোনো মানসিক বা শারীরিক অসুস্থতা আছে?',
  'Write something about yourself': 'নিজের সম্পর্কে কিছু লিখুন',
  'Give details of the mental or physical illness': 'মানসিক বা শারীরিক অসুস্থতার বিস্তারিত জানান',
  'Marriage-related information': 'বিবাহ-সংক্রান্ত তথ্য',
  'After marriage, do you want to let your wife study?': 'বিয়ের পর আপনি কি স্ত্রীকে পড়াশোনা করতে দিতে চান?',
  'After marriage, do you want to let your wife work?': 'বিয়ের পর আপনি কি স্ত্রীকে চাকরি/কাজ করতে দিতে চান?',
  'Negotiable': 'আলোচনা সাপেক্ষে',
  'Where will you keep your wife after marriage?': 'বিয়ের পর স্ত্রীকে কোথায় রাখবেন?',
  'e.g. With my family, At my workplace location, Not decided yet': 'যেমন: আমার পরিবারের সাথে, আমার কর্মস্থলে, এখনো ঠিক করিনি',
  'The kind of life partner you expect': 'আপনি যেমন জীবনসঙ্গী প্রত্যাশা করেন',
  'Maximum age': 'সর্বোচ্চ বয়স',
  'Minimum height': 'সর্বনিম্ন উচ্চতা',
  'Minimum educational qualification': 'সর্বনিম্ন শিক্ষাগত যোগ্যতা',
  'District': 'জেলা',
  'e.g. Govt. service holder, Businessman, Any': 'যেমন: সরকারি চাকরিজীবী, ব্যবসায়ী, যেকোনো',
  'Economic condition': 'অর্থনৈতিক অবস্থা',
  'e.g. Financially solvent': 'যেমন: আর্থিকভাবে সচ্ছল',
  'Family condition': 'পারিবারিক অবস্থা',
  'e.g. Upper-middle-class, educated and well-established family': 'যেমন: উচ্চ-মধ্যবিত্ত, শিক্ষিত ও প্রতিষ্ঠিত পরিবার',
  'The traits or qualities you expect in a life partner': 'জীবনসঙ্গীর মধ্যে আপনি যে বৈশিষ্ট্য বা গুণাবলি প্রত্যাশা করেন',
  'e.g. A kind, honest, responsible and understanding person who values family, mutual respect and a peaceful relationship.': 'যেমন: একজন দয়ালু, সৎ, দায়িত্বশীল ও সহানুভূতিশীল মানুষ, যিনি পরিবার, পারস্পরিক শ্রদ্ধা এবং শান্তিপূর্ণ সম্পর্কের মূল্য দেন।',
  'For the authority': 'কর্তৃপক্ষের জন্য',
  'Anything special you want to tell the authority': 'কর্তৃপক্ষকে বিশেষ কিছু জানাতে চাইলে লিখুন',
  'Please keep my information confidential and contact me if any additional information or clarification is required.': 'অনুগ্রহ করে আমার তথ্য গোপন রাখবেন এবং অতিরিক্ত তথ্য বা ব্যাখ্যার প্রয়োজন হলে আমার সাথে যোগাযোগ করবেন।',
  'I agree to all of our': 'আমি আমাদের সকল',
  'policies': 'নীতিমালা',
  'Contact / Guardian information': 'যোগাযোগ / অভিভাবকের তথ্য',
  'Guardian’s number': 'অভিভাবকের নম্বর',
  'Father': 'পিতা',
  'Mother': 'মাতা',
  'Brother': 'ভাই',
  'Sister': 'বোন',
  'Local guardian': 'স্থানীয় অভিভাবক',
  'Email Address (Optional)': 'ইমেইল ঠিকানা (ঐচ্ছিক)',
  'Marriage Biodata': 'বিবাহ বায়োডাটা',
  'Age': 'বয়স',
  'Permanent district': 'স্থায়ী জেলা',
  'Permanent thana': 'স্থায়ী থানা',
  'Current district': 'বর্তমান জেলা',
  'Current thana': 'বর্তমান থানা',
  'Current address': 'বর্তমান ঠিকানা',
  'Education': 'শিক্ষা',
  'Medium of education': 'শিক্ষার মাধ্যম',
  'SSC': 'এসএসসি',
  'HSC': 'এইচএসসি',
  'Passed': 'পাস',
  'Graduate': 'স্নাতক',
  'Post-graduate': 'স্নাতকোত্তর',
  'Other education': 'অন্যান্য শিক্ষা',
  'Personal Habits & Information': 'ব্যক্তিগত অভ্যাস ও তথ্য',
  'After marriage, will you let your wife study?': 'বিয়ের পর স্ত্রীকে পড়াশোনা করতে দিবেন?',
  'Prays five times a day?': 'পাঁচ ওয়াক্ত নামাজ পড়ে কি-না?',
  'Any mental or physical illness?': 'মানসিক বা শারীরিক অসুস্থতা আছে কি-না?',
  'Will you let your wife work?': 'স্ত্রীকে চাকরি করতে দিবেন কি-না?',
  'Brief information about yourself': 'নিজের সম্পর্কে সংক্ষিপ্ত তথ্য।',
  'Professional Information': 'পেশাগত তথ্য',
  'Brothers': 'ভাই',
  'Sisters': 'বোন',
  'Siblings': 'ভাই-বোন',
  'Siblings’ professions': 'ভাই-বোনের পেশা',
  'Expected Life Partner': 'প্রত্যাশিত জীবনসঙ্গী',
  'Area': 'এলাকা',
  'Expected qualities': 'প্রত্যাশিত গুণাবলি',
  'Other requirements': 'অন্যান্য চাহিদা',
  'Log in to add your biodata': 'বায়োডাটা যোগ করতে লগইন করুন',
  'You need to be logged in to submit a biodata. Please log in or create an account to continue.': 'বায়োডাটা জমা দিতে আপনাকে লগইন করা থাকতে হবে। এগিয়ে যেতে অনুগ্রহ করে লগইন করুন বা নতুন অ্যাকাউন্ট খুলুন।',
  'Log in / Sign up': 'লগইন / সাইন আপ',
  'Loading...': 'লোড হচ্ছে...',
  'Enter the current address': 'বর্তমান ঠিকানা লিখুন',
  'Enter the date of birth': 'জন্ম তারিখ দিন',
  'Select skin tone': 'গায়ের রং নির্বাচন করুন',
  'Select height': 'উচ্চতা নির্বাচন করুন',
  'Select blood group': 'রক্তের গ্রুপ নির্বাচন করুন',
  'Select the passing year': 'পাসের বছর নির্বাচন করুন',
  'Select the group': 'গ্রুপ নির্বাচন করুন',
  'Enter the institute name': 'প্রতিষ্ঠানের নাম লিখুন',
  'Enter the department / degree name': 'বিভাগ / ডিগ্রির নাম লিখুন',
  'Enter the father’s name': 'পিতার নাম লিখুন',
  'Enter the father’s profession': 'পিতার পেশা লিখুন',
  'Enter the mother’s name': 'মাতার নাম লিখুন',
  'Enter the mother’s profession': 'মাতার পেশা লিখুন',
  'Answer whether you have any mental or physical illness': 'আপনার কোনো মানসিক বা শারীরিক অসুস্থতা আছে কি না তা জানান',
  'Give details of the illness': 'অসুস্থতার বিস্তারিত লিখুন',
  'Enter the profession details': 'পেশার বিবরণ লিখুন',
  'Answer whether you passed SSC/equivalent': 'এসএসসি/সমমান পাস করেছেন কি না তা জানান',
  'Answer whether you passed HSC/equivalent': 'এইচএসসি/সমমান পাস করেছেন কি না তা জানান',
  'Answer whether you passed graduation/equivalent': 'স্নাতক/সমমান পাস করেছেন কি না তা জানান',
  'Answer whether you passed post-graduation/equivalent': 'স্নাতকোত্তর/সমমান পাস করেছেন কি না তা জানান',
  'Fill in the graduation institution, department/degree and passing year': 'স্নাতকের প্রতিষ্ঠান, বিভাগ/ডিগ্রি ও পাসের বছর পূরণ করুন',
  'Fill in the post-graduation institution, department/degree and passing year': 'স্নাতকোত্তরের প্রতিষ্ঠান, বিভাগ/ডিগ্রি ও পাসের বছর পূরণ করুন',
  'You must agree to the policy to continue': 'এগিয়ে যেতে নীতিমালায় সম্মত হতে হবে',
  'Enter the guardian’s valid mobile number': 'অভিভাবকের সঠিক মোবাইল নম্বর দিন',
  'Select the relationship with the guardian': 'অভিভাবকের সাথে সম্পর্ক নির্বাচন করুন',
  'Enter a valid Bangladeshi mobile number': 'সঠিক বাংলাদেশি মোবাইল নম্বর দিন',
  'Please log in to submit a biodata': 'বায়োডাটা জমা দিতে অনুগ্রহ করে লগইন করুন',
  'Fill in all required (*) fields': 'সব আবশ্যক (*) ঘর পূরণ করুন',
  'Something went wrong, please try again': 'কিছু একটা ভুল হয়েছে, আবার চেষ্টা করুন',
  'There was a problem submitting, please try again': 'জমা দিতে সমস্যা হয়েছে, আবার চেষ্টা করুন',
  'Edit biodata': 'বায়োডাটা সম্পাদনা',
  'Discard this biodata?': 'এই বায়োডাটা বাতিল করবেন?',
  'Anything you have filled in will be lost.': 'আপনার পূরণ করা সব তথ্য মুছে যাবে।',
  'Discard': 'বাতিল করুন',
  'Keep editing': 'সম্পাদনা চালিয়ে যান',
  'Select a date': 'তারিখ নির্বাচন করুন',
  'Choose a district first': 'আগে জেলা নির্বাচন করুন',
  'Gallery': 'গ্যালারি',
  'Camera': 'ক্যামেরা',
  'Add a photo': 'ছবি যোগ করুন',
};
