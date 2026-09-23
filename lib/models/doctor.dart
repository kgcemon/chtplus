import '../core/utils/json.dart';

class DoctorSummary {
  const DoctorSummary({
    required this.id,
    required this.name,
    this.specialty,
    this.qualifications,
    this.photoUrl,
    this.likeCount = 0,
    this.likedByMe = false,
  });

  final String id;
  final String name;
  final String? specialty;
  final String? qualifications;
  final String? photoUrl;
  final int likeCount;
  final bool likedByMe;

  factory DoctorSummary.fromJson(Map<String, dynamic> json) => DoctorSummary(
        id: json.str('id'),
        name: json.str('name'),
        specialty: json.strOrNull('specialty'),
        qualifications: json.strOrNull('qualifications'),
        photoUrl: json.strOrNull('photoUrl'),
        likeCount: json.intOr('likeCount'),
        likedByMe: json.flag('likedByMe'),
      );

  DoctorSummary copyWith({int? likeCount, bool? likedByMe}) => DoctorSummary(
        id: id,
        name: name,
        specialty: specialty,
        qualifications: qualifications,
        photoUrl: photoUrl,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
      );
}

class MedicalService {
  const MedicalService({required this.id, required this.name});

  final String id;
  final String name;

  factory MedicalService.fromJson(Map<String, dynamic> json) =>
      MedicalService(id: json.str('id'), name: json.str('name'));
}

/// A doctor's chamber at an organization, with the next bookable date already
/// computed by the server.
class Chamber {
  const Chamber({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    this.consultationFee,
    this.serialFee,
    this.notes,
    this.type,
    this.district,
    this.area,
    this.address,
    this.organizationPhone,
    this.nextAvailable,
  });

  final String id;
  final String organizationId;
  final String organizationName;
  final num? consultationFee;
  final num? serialFee;
  final String? notes;
  final String? type;
  final String? district;
  final String? area;
  final String? address;
  final String? organizationPhone;
  final AvailableDate? nextAvailable;

  factory Chamber.fromJson(Map<String, dynamic> json) {
    final next = json.mapOrNull('nextAvailable');
    return Chamber(
      id: json.str('id'),
      organizationId: json.str('organizationId'),
      organizationName: json.str('organizationName'),
      consultationFee: json['consultationFee'] == null ? null : json.dbl('consultationFee'),
      serialFee: json['serialFee'] == null ? null : json.dbl('serialFee'),
      notes: json.strOrNull('notes'),
      type: json.strOrNull('type'),
      district: json.strOrNull('district'),
      area: json.strOrNull('area'),
      address: json.strOrNull('address'),
      organizationPhone: json.strOrNull('organizationPhone'),
      nextAvailable: next == null ? null : AvailableDate.fromJson(next),
    );
  }

  String get locationLabel =>
      [address, area, district].where((e) => e != null && e.isNotEmpty).join(', ');
}

/// One bookable day returned by the availability route.
class AvailableDate {
  const AvailableDate({
    required this.date,
    this.startTime,
    this.endTime,
    this.capacity = 0,
    this.remainingCapacity = 0,
  });

  final String date;
  final String? startTime;
  final String? endTime;
  final int capacity;
  final int remainingCapacity;

  factory AvailableDate.fromJson(Map<String, dynamic> json) => AvailableDate(
        date: json.str('date'),
        startTime: json.strOrNull('startTime'),
        endTime: json.strOrNull('endTime'),
        capacity: json.intOr('capacity'),
        remainingCapacity: json.intOr('remainingCapacity'),
      );

  DateTime? get dateTime => DateTime.tryParse(date);

  /// `05:00:00` from MySQL TIME becomes `5:00 PM`.
  String get timeRange {
    final from = _pretty(startTime);
    final to = _pretty(endTime);
    if (from.isEmpty && to.isEmpty) return '';
    if (to.isEmpty) return from;
    return '$from – $to';
  }

  static String _pretty(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display:$minute $suffix';
  }
}

class DoctorDetail {
  const DoctorDetail({
    required this.id,
    required this.name,
    this.specialty,
    this.qualifications,
    this.photoUrl,
    this.phone,
    this.likeCount = 0,
    this.likedByMe = false,
    this.services = const [],
    this.chambers = const [],
  });

  final String id;
  final String name;
  final String? specialty;
  final String? qualifications;
  final String? photoUrl;
  final String? phone;
  final int likeCount;
  final bool likedByMe;
  final List<MedicalService> services;
  final List<Chamber> chambers;

  factory DoctorDetail.fromJson(Map<String, dynamic> json) => DoctorDetail(
        id: json.str('id'),
        name: json.str('name'),
        specialty: json.strOrNull('specialty'),
        qualifications: json.strOrNull('qualifications'),
        photoUrl: json.strOrNull('photoUrl'),
        phone: json.strOrNull('phone'),
        likeCount: json.intOr('likeCount'),
        likedByMe: json.flag('likedByMe'),
        services: json.mapList('services').map(MedicalService.fromJson).toList(),
        chambers: json.mapList('chambers').map(Chamber.fromJson).toList(),
      );

  DoctorDetail copyWith({int? likeCount, bool? likedByMe}) => DoctorDetail(
        id: id,
        name: name,
        specialty: specialty,
        qualifications: qualifications,
        photoUrl: photoUrl,
        phone: phone,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        services: services,
        chambers: chambers,
      );
}

/// A booked appointment from `/api/me/serials`.
class Serial {
  const Serial({
    required this.id,
    required this.status,
    this.appointmentDate,
    this.serialNumber,
    this.patientName,
    this.note,
    this.createdAt,
    this.doctorName,
    this.specialty,
    this.organizationName,
    this.organizationPhone,
  });

  final String id;
  final String status;
  final DateTime? appointmentDate;
  final int? serialNumber;
  final String? patientName;
  final String? note;
  final DateTime? createdAt;
  final String? doctorName;
  final String? specialty;
  final String? organizationName;
  final String? organizationPhone;

  factory Serial.fromJson(Map<String, dynamic> json) => Serial(
        id: json.str('id'),
        status: json.str('status', fallback: 'pending'),
        appointmentDate: json.date('appointmentDate'),
        serialNumber: json.intOrNull('serialNumber'),
        patientName: json.strOrNull('patientName'),
        note: json.strOrNull('note'),
        createdAt: json.date('createdAt'),
        doctorName: json.strOrNull('doctorName'),
        specialty: json.strOrNull('specialty'),
        organizationName: json.strOrNull('organizationName'),
        organizationPhone: json.strOrNull('organizationPhone'),
      );

  bool get canCancel => status == 'pending';

  bool get isUpcoming {
    final date = appointmentDate;
    if (date == null) return false;
    if (status == 'cancelled') return false;
    final today = DateTime.now();
    return !date.isBefore(DateTime(today.year, today.month, today.day));
  }
}
