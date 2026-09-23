/// Port of the server's `lib/dataLabels.js`.
///
/// Biodata options, product conditions and product spec values are stored in
/// the database in Bengali and compared in code, so they must not be changed.
/// This maps each stored value to the English label the UI shows, exactly as
/// the website does. Anything not listed (free text, English values) is shown
/// unchanged.
const Map<String, String> dataLabels = {
  // gender
  'পুরুষ': 'Male',
  'মহিলা': 'Female',
  // biodata type
  'পাত্রের বায়োডাটা': 'Groom’s biodata',
  'পাত্রীর বায়োডাটা': 'Bride’s biodata',
  'পাত্রী বায়োডাটা': 'Bride’s biodata',
  // skin tone
  'শ্যামলা': 'Brown',
  'উজ্জ্বল শ্যামলা': 'Light brown',
  'ফর্সা': 'Fair',
  'উজ্জ্বল ফর্সা': 'Very fair',
  // marital status
  'অবিবাহিত': 'Never married',
  'বিবাহিত': 'Married',
  'ডিভোর্সড': 'Divorced',
  'তালাকপ্রাপ্ত': 'Divorced',
  'তালাকপ্রাপ্তা': 'Divorced',
  'বিধবা': 'Widowed',
  'বিপত্নীক': 'Widower',
  // profession type / religion / education medium
  'চাকরি': 'Job',
  'ব্যবসা': 'Business',
  'উদ্যোক্তা': 'Entrepreneur',
  'শিক্ষার্থী': 'Student',
  'অন্যান্য': 'Other',
  'ইসলাম': 'Islam',
  'হিন্দু': 'Hinduism',
  'বৌদ্ধ': 'Buddhism',
  'খ্রিস্টান': 'Christianity',
  'জেনারেল': 'General',
  'কারিগরি': 'Technical',
  'মাদ্রাসা': 'Madrasa',
  // SSC / HSC group
  'বিজ্ঞান': 'Science',
  'মানবিক': 'Arts',
  'ব্যবসায় শিক্ষা': 'Commerce',
  // yes / no and preferences
  'হ্যাঁ': 'Yes',
  'না': 'No',
  'নিয়মিত নয়': 'Not regular',
  'নিয়মিত চেষ্টা করি': 'Try to pray regularly',
  'আলোচনা সাপেক্ষে': 'Negotiable',
  'যেকোনো': 'Any',
  'জানা নেই': 'Unknown',
  'নিজ': 'Self',
  // guardian relation
  'পিতা': 'Father',
  'মাতা': 'Mother',
  'ভাই': 'Brother',
  'বোন': 'Sister',
  // sibling relationship
  'বড় ভাই': 'Elder brother',
  'ছোট ভাই': 'Younger brother',
  'বড় বোন': 'Elder sister',
  'ছোট বোন': 'Younger sister',
  'স্থানীয় অভিভাবক': 'Local guardian',
  // product condition
  'নতুন': 'New',
  'ব্যবহৃত': 'Used',
  'রিফার্বিশড্': 'Refurbished',
  // product spec options
  'সিঙ্গেল সিম': 'Single SIM',
  'ডুয়াল সিম': 'Dual SIM',
  'ই-সিম': 'eSIM',
  'ল্যাপটপ': 'Laptop',
  'ডেস্কটপ কম্পিউটার': 'Desktop computer',
  'সার্ভার': 'Server',
  'ম্যানুয়াল': 'Manual',
  'অটোমেটিক': 'Automatic',
  'পেট্রোল/অকটেন': 'Petrol/Octane',
  'ইলেকট্রিক (ব্যাটারি)': 'Electric (battery)',
  'পেট্রোল': 'Petrol',
  'অকটেন': 'Octane',
  'ডিজেল': 'Diesel',
  'সিএনজি': 'CNG',
  'হাইব্রিড': 'Hybrid',
  'ইলেকট্রিক': 'Electric',
};

String dataLabel(String? value) {
  if (value == null) return '';
  return dataLabels[value] ?? value;
}

/// Stored values the sell wizard writes to `marketplace_listings.condition`.
const marketplaceConditions = <String>['নতুন', 'ব্যবহৃত', 'রিফার্বিশড্'];

/// Extra spec fields the sell wizard offers per category, ported from
/// `lib/marketplaceCategoryFields.js` so the app collects the same attributes.
class ExtraField {
  const ExtraField({
    required this.key,
    required this.label,
    this.type = 'text',
    this.placeholder,
    this.options = const [],
  });

  final String key;
  final String label;
  final String type;
  final String? placeholder;
  final List<String> options;

  bool get isSelect => type == 'select';
}

const Map<String, List<ExtraField>> categoryExtraFields = {
  'sub_phone_mobile': [
    ExtraField(key: 'brand', label: 'Brand', placeholder: 'e.g. Samsung, Xiaomi, Apple'),
    ExtraField(
      key: 'ramGb',
      label: 'RAM',
      type: 'select',
      options: ['1GB', '2GB', '3GB', '4GB', '6GB', '8GB', '12GB', '16GB'],
    ),
    ExtraField(
      key: 'storageGb',
      label: 'Storage',
      type: 'select',
      options: ['16GB', '32GB', '64GB', '128GB', '256GB', '512GB', '1TB'],
    ),
    ExtraField(
      key: 'simType',
      label: 'SIM',
      type: 'select',
      options: ['সিঙ্গেল সিম', 'ডুয়াল সিম', 'ই-সিম'],
    ),
    ExtraField(key: 'screenSize', label: 'Screen size', placeholder: 'e.g. 6.5 inch'),
    ExtraField(key: 'batteryCapacity', label: 'Battery capacity', placeholder: 'e.g. 5000mAh'),
    ExtraField(
      key: 'exchangePossible',
      label: 'Exchange possible',
      type: 'select',
      options: ['হ্যাঁ', 'না'],
    ),
  ],
  'sub_elec_laptop': [
    ExtraField(
      key: 'deviceType',
      label: 'Type',
      type: 'select',
      options: ['ল্যাপটপ', 'ডেস্কটপ কম্পিউটার', 'সার্ভার'],
    ),
    ExtraField(key: 'brand', label: 'Brand', placeholder: 'e.g. HP, Dell, Lenovo, Asus'),
    ExtraField(key: 'processor', label: 'Processor', placeholder: 'e.g. Intel Core i5 10th Gen'),
    ExtraField(
      key: 'ramGb',
      label: 'RAM',
      type: 'select',
      options: ['2GB', '4GB', '8GB', '12GB', '16GB', '32GB', '64GB'],
    ),
    ExtraField(key: 'storageCapacity', label: 'Storage capacity', placeholder: 'e.g. 512GB'),
    ExtraField(
      key: 'storageType',
      label: 'Storage type',
      type: 'select',
      options: ['SSD', 'HDD', 'HDD+SSD', 'eMMC'],
    ),
    ExtraField(key: 'displaySize', label: 'Display size', placeholder: 'e.g. 15.6 inch'),
    ExtraField(
      key: 'os',
      label: 'Operating system',
      type: 'select',
      options: ['Windows 11', 'Windows 10', 'Mac OS', 'Linux', 'Chrome OS', 'অন্যান্য'],
    ),
    ExtraField(
      key: 'exchangePossible',
      label: 'Exchange possible',
      type: 'select',
      options: ['হ্যাঁ', 'না'],
    ),
  ],
  'sub_veh_bikes': [
    ExtraField(key: 'brand', label: 'Brand', placeholder: 'e.g. Bajaj, Yamaha, Honda, TVS'),
    ExtraField(key: 'model', label: 'Model', placeholder: 'e.g. Pulsar 150'),
    ExtraField(key: 'manufactureYear', label: 'Year of manufacture', placeholder: 'e.g. 2021'),
    ExtraField(key: 'engineCc', label: 'Engine capacity (cc)', placeholder: 'e.g. 150cc'),
    ExtraField(key: 'mileageKm', label: 'Distance driven (km)', placeholder: 'e.g. 12000'),
    ExtraField(
      key: 'transmission',
      label: 'Transmission',
      type: 'select',
      options: ['ম্যানুয়াল', 'অটোমেটিক'],
    ),
    ExtraField(
      key: 'fuelType',
      label: 'Fuel',
      type: 'select',
      options: ['পেট্রোল/অকটেন', 'ইলেকট্রিক (ব্যাটারি)'],
    ),
    ExtraField(
      key: 'exchangePossible',
      label: 'Exchange possible',
      type: 'select',
      options: ['হ্যাঁ', 'না'],
    ),
  ],
  'sub_veh_cars': [
    ExtraField(key: 'brand', label: 'Brand', placeholder: 'e.g. Toyota, Honda, Nissan'),
    ExtraField(key: 'model', label: 'Model', placeholder: 'e.g. Axio'),
    ExtraField(key: 'manufactureYear', label: 'Year of manufacture', placeholder: 'e.g. 2015'),
    ExtraField(key: 'mileageKm', label: 'Distance driven (km)', placeholder: 'e.g. 50000'),
    ExtraField(
      key: 'fuelType',
      label: 'Fuel',
      type: 'select',
      options: ['পেট্রোল', 'অকটেন', 'ডিজেল', 'সিএনজি', 'হাইব্রিড', 'ইলেকট্রিক'],
    ),
    ExtraField(
      key: 'transmission',
      label: 'Transmission',
      type: 'select',
      options: ['ম্যানুয়াল', 'অটোমেটিক'],
    ),
    ExtraField(
      key: 'exchangePossible',
      label: 'Exchange possible',
      type: 'select',
      options: ['হ্যাঁ', 'না'],
    ),
  ],
};

List<ExtraField> extraFieldsFor(String? categoryId) =>
    categoryExtraFields[categoryId] ?? const [];

/// A readable label for an extra-attribute key that has no field definition
/// (e.g. a listing saved under a category whose fields later changed).
String extraAttributeLabel(String key) {
  for (final fields in categoryExtraFields.values) {
    for (final field in fields) {
      if (field.key == key) return field.label;
    }
  }
  final spaced = key.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match[1]} ${match[2]}',
  );
  return spaced.isEmpty ? key : spaced[0].toUpperCase() + spaced.substring(1);
}
