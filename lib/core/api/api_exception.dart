import 'package:dio/dio.dart';

/// A failure the UI can show as a sentence. `code` is the machine-readable
/// `error` string the Next.js routes return (`invalid_credentials`,
/// `insufficient_coins`, ...) so callers can branch on it.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.data,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final Map<String, dynamic>? data;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == null;

  @override
  String toString() => message;

  /// Human text for the `error` codes used across the backend routes.
  static const _messages = <String, String>{
    'invalid_body': 'Could not read the request. Please try again.',
    'invalid_input': 'Please fill in every required field correctly.',
    'invalid_credentials': 'Wrong email or password.',
    'invalid_email': 'That email address does not look right.',
    'email_taken': 'An account with this email already exists.',
    'ip_blocked': 'Access from this network has been blocked.',
    'unauthorized': 'Please sign in to continue.',
    'forbidden': 'You do not have permission to do that.',
    'not_found': 'This item is no longer available.',
    'invalid_code': 'That reset code is wrong or has expired.',
    'invalid_category': 'Please choose a valid category.',
    'invalid_package': 'Please choose a valid package.',
    'invalid_chamber': 'This chamber is no longer available.',
    'invalid_photo': 'That image could not be used. Try another one.',
    'invalid_review': 'Please give a rating and write a comment.',
    'invalid_reply': 'Please write a reply first.',
    'date_unavailable': 'That date has just been taken. Pick another one.',
    'pending_request_exists': 'You already have a request awaiting review.',
    'insufficient_coins': 'You do not have enough coins.',
    'package_required': 'Choose a package to unlock this biodata.',
    'chat_disabled': 'This person has turned messaging off.',
    'google_not_configured': 'Google sign-in is not available right now.',
    'invalid_google_token': 'Google sign-in failed. Please try again.',
    'email_not_verified': 'Your Google account email is not verified.',
    'mobile_number_required': 'A mobile number is required.',
    'pending_verification': 'This profile is still awaiting verification.',
    'cannot_follow_self': 'You cannot follow yourself.',
  };

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final status = response?.statusCode;

    Map<String, dynamic>? data;
    final raw = response?.data;
    if (raw is Map<String, dynamic>) data = raw;

    final code = data?['error']?.toString();
    if (code != null) {
      // The biodata routes return a ready-made sentence rather than a code
      // (e.g. "Fill in all required (*) fields"), so anything with a space in
      // it is shown to the user as-is.
      final known = _messages[code];
      final message = known ??
          (code.contains(' ') ? code : _fallbackForStatus(status));
      return ApiException(
        message: message,
        code: code,
        statusCode: status,
        data: data,
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'The connection timed out. Check your internet and retry.',
          statusCode: status,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return ApiException(
          message: 'No internet connection. Check your network and retry.',
          statusCode: status,
        );
      case DioExceptionType.cancel:
        return ApiException(message: 'Request cancelled.', statusCode: status);
      default:
        return ApiException(
          message: _fallbackForStatus(status),
          statusCode: status,
        );
    }
  }

  static String _fallbackForStatus(int? status) {
    if (status == null) return 'Something went wrong. Please try again.';
    if (status == 401) return 'Please sign in to continue.';
    if (status == 403) return 'You do not have permission to do that.';
    if (status == 404) return 'This item is no longer available.';
    if (status == 409) return 'That conflicts with something that already exists.';
    if (status >= 500) return 'The server is having trouble. Please try again shortly.';
    return 'Something went wrong. Please try again.';
  }
}
