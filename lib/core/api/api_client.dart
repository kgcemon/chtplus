import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../config.dart';
import '../storage/token_store.dart';
import 'api_exception.dart';
import 'response_cache.dart';

/// Thin wrapper over Dio that adds the bearer token, maps failures to
/// [ApiException], and serves GETs from [ResponseCache] where it helps.
class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBase,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.receiveTimeout,
        responseType: ResponseType.json,
        headers: const {'Accept': 'application/json'},
        // Statuses are inspected by hand so error bodies (which carry the
        // `error` code and extra fields like `packages`) reach ApiException.
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // One pooled, keep-alive connection set: the home screen fires ~8 requests
    // at once and re-handshaking TLS for each would dominate cold-start time.
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient()
          ..idleTimeout = const Duration(seconds: 30)
          ..maxConnectionsPerHost = 8
          ..autoUncompress = true;
        return client;
      },
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = TokenStore.instance.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;

  /// Called when the server rejects the stored token, so the app can sign out.
  void Function()? onUnauthorized;

  Future<Response<dynamic>> _send(Future<Response<dynamic>> Function() run) async {
    late Response<dynamic> response;
    try {
      response = await run();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }

    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) return response;

    final exception = ApiException.fromDio(
      DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      ),
    );
    if (exception.isUnauthorized) onUnauthorized?.call();
    throw exception;
  }

  /// GET returning the decoded body.
  ///
  /// With [cacheTtl] set, a fresh cached copy is returned without touching the
  /// network; on a network failure a stale copy is used before giving up.
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Duration? cacheTtl,
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    final key = ResponseCache.keyFor(path, query);

    if (cacheTtl != null && !forceRefresh) {
      final cached = ResponseCache.cache.read(key, cacheTtl);
      if (cached != null) return cached;
    }

    try {
      final response = await _send(
        () => _dio.get(path, queryParameters: _clean(query), cancelToken: cancelToken),
      );
      if (cacheTtl != null) {
        // Not awaited: writing the cache must never delay the UI.
        unawaited(ResponseCache.cache.write(key, response.data));
      }
      return response.data;
    } on ApiException catch (error) {
      if (cacheTtl != null && error.isNetwork) {
        final stale = ResponseCache.cache.readStale(key);
        if (stale != null) return stale;
      }
      rethrow;
    }
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final response = await _send(
      () => _dio.post(path, data: body, queryParameters: _clean(query), cancelToken: cancelToken),
    );
    return response.data;
  }

  Future<dynamic> patch(String path, {Object? body, CancelToken? cancelToken}) async {
    final response = await _send(() => _dio.patch(path, data: body, cancelToken: cancelToken));
    return response.data;
  }

  Future<dynamic> delete(String path, {Object? body, CancelToken? cancelToken}) async {
    final response = await _send(() => _dio.delete(path, data: body, cancelToken: cancelToken));
    return response.data;
  }

  /// Multipart POST/PATCH for the routes that accept file uploads.
  Future<dynamic> upload(
    String path,
    FormData form, {
    String method = 'POST',
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final response = await _send(
      () => _dio.request(
        path,
        data: form,
        options: Options(method: method, contentType: 'multipart/form-data'),
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      ),
    );
    return response.data;
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      cleaned[key] = value;
    });
    return cleaned.isEmpty ? null : cleaned;
  }
}

/// Local stand-in for `package:async`'s helper so no extra dependency is pulled
/// in just to fire-and-forget a future.
void unawaited(Future<void> future) {
  future.catchError((_) {});
}
