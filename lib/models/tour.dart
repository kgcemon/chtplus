import '../core/utils/json.dart';

/// Group tours (`/api/tours`, see the site's lib/tours.js). Payment is made to
/// the organizer directly; the app only handles the seat requests.
class Tour {
  const Tour({
    required this.id,
    required this.title,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.meetingPoint,
    required this.seats,
    required this.seatsLeft,
    required this.price,
    this.includes = '',
    this.description = '',
    this.photoUrl,
    required this.contactPhone,
    required this.status,
    this.adminNote,
    required this.isOfficial,
    this.pendingRequests = 0,
    required this.organizer,
    this.myBookingStatus,
  });

  final String id;
  final String title;
  final String destination;

  /// YYYY-MM-DD
  final String startDate;
  final String endDate;
  final String meetingPoint;
  final int seats;
  final int seatsLeft;
  final int price;
  final String includes;
  final String description;
  final String? photoUrl;
  final String contactPhone;

  /// pending · approved · rejected · cancelled
  final String status;
  final String? adminNote;
  final bool isOfficial;
  final int pendingRequests;
  final TourOrganizer organizer;

  /// On "My trips": pending · accepted · rejected.
  final String? myBookingStatus;

  List<String> get includeLines =>
      includes.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  factory Tour.fromJson(Map<String, dynamic> json) => Tour(
        id: json.str('id'),
        title: json.str('title'),
        destination: json.str('destination'),
        startDate: json.str('startDate'),
        endDate: json.str('endDate'),
        meetingPoint: json.str('meetingPoint'),
        seats: json.intOr('seats'),
        seatsLeft: json.intOr('seatsLeft'),
        price: json.intOr('price'),
        includes: json.str('includes'),
        description: json.str('description'),
        photoUrl: json.strOrNull('photoUrl'),
        contactPhone: json.str('contactPhone'),
        status: json.str('status', fallback: 'approved'),
        adminNote: json.strOrNull('adminNote'),
        isOfficial: json.flag('isOfficial'),
        pendingRequests: json.intOr('pendingRequests'),
        organizer: TourOrganizer.fromJson(json.mapOrNull('organizer') ?? const {}),
        myBookingStatus: json.mapOrNull('myBooking')?.strOrNull('status'),
      );
}

class TourOrganizer {
  const TourOrganizer({this.userId, required this.name, this.photoUrl, this.blueBadge = false, this.official = false});

  final String? userId;
  final String name;
  final String? photoUrl;
  final bool blueBadge;
  final bool official;

  factory TourOrganizer.fromJson(Map<String, dynamic> json) => TourOrganizer(
        userId: json.strOrNull('userId'),
        name: json.str('name', fallback: 'Organizer'),
        photoUrl: json.strOrNull('photoUrl'),
        blueBadge: json.flag('blueBadge'),
        official: json.flag('official'),
      );
}

class TourBooking {
  const TourBooking({
    required this.id,
    required this.seats,
    required this.phone,
    this.note,
    required this.status,
    this.userId,
    this.name,
    this.photoUrl,
    this.blueBadge = false,
  });

  final int id;
  final int seats;
  final String phone;
  final String? note;

  /// pending · accepted · rejected · cancelled
  final String status;
  final String? userId;
  final String? name;
  final String? photoUrl;
  final bool blueBadge;

  bool get isActive => status == 'pending' || status == 'accepted';

  factory TourBooking.fromJson(Map<String, dynamic> json) => TourBooking(
        id: json.intOr('id'),
        seats: json.intOr('seats', 1),
        phone: json.str('phone'),
        note: json.strOrNull('note'),
        status: json.str('status'),
        userId: json.strOrNull('userId'),
        name: json.strOrNull('name'),
        photoUrl: json.strOrNull('photoUrl'),
        blueBadge: json.flag('blueBadge'),
      );
}

/// `/api/tours/:id` — the tour plus the viewer's own request, and for its
/// organizer every request.
class TourDetail {
  const TourDetail({required this.tour, this.myBooking, this.isOrganizer = false, this.bookings = const []});

  final Tour tour;
  final TourBooking? myBooking;
  final bool isOrganizer;
  final List<TourBooking> bookings;

  factory TourDetail.fromJson(Map<String, dynamic> json) => TourDetail(
        tour: Tour.fromJson(json.mapOrNull('tour') ?? const {}),
        myBooking: json.mapOrNull('myBooking') == null ? null : TourBooking.fromJson(json.mapOrNull('myBooking')!),
        isOrganizer: json.flag('isOrganizer'),
        bookings: json.mapList('bookings').map(TourBooking.fromJson).toList(growable: false),
      );
}

/// `/api/me/tour-organizer` — my organizer request (null if never applied)
/// and the tours I've posted.
class OrganizerState {
  const OrganizerState({this.status, this.orgName, this.adminNote, this.autoApprove = false, this.tours = const []});

  /// null · pending · approved · rejected · blocked
  final String? status;
  final String? orgName;
  final String? adminNote;
  final bool autoApprove;
  final List<Tour> tours;

  factory OrganizerState.fromJson(Map<String, dynamic> json) {
    final org = json.mapOrNull('organizer');
    return OrganizerState(
      status: org?.strOrNull('status'),
      orgName: org?.strOrNull('orgName'),
      adminNote: org?.strOrNull('adminNote'),
      autoApprove: org?.flag('autoApprove') ?? false,
      tours: json.mapList('tours').map(Tour.fromJson).toList(growable: false),
    );
  }
}
