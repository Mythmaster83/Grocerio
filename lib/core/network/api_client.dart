import 'package:dio/dio.dart';
import '../config/env_config.dart';
import '../utils/app_logger.dart';
import '../utils/result.dart';

/// Thin Dio wrapper. Owns timeouts, header injection, and error mapping to
/// [AppFailure] so callers never see raw DioException.
///
/// Hardening notes for production (tracked as follow-up, not MVP-blocking):
/// - Certificate pinning (dio_certificate_pinning or platform-native) once
///   a fixed backend host is finalized.
/// - Move Pexels calls behind a backend proxy so the API key never ships in
///   the client binary (see env_config.dart security notes).
class ApiClient {
  final Dio _dio;

  ApiClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                sendTimeout: const Duration(seconds: 8),
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Never log full request options — may contain the API key.
          logger.debug('HTTP ${options.method} ${options.uri.path}');
          handler.next(options);
        },
        onError: (error, handler) {
          logger.warning('HTTP error: ${error.type} ${error.message}');
          handler.next(error);
        },
      ),
    );
  }

  Future<Result<Map<String, dynamic>>> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return Result.ok(response.data ?? const {});
    } on DioException catch (e) {
      return Result.err(_mapDioError(e));
    } catch (e, st) {
      logger.error('Unexpected network error', e, st);
      return Result.err(UnknownFailure('Unexpected network error.', cause: e));
    }
  }

  AppFailure _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure('The request timed out. Check your connection.');
      case DioExceptionType.connectionError:
        return const NetworkFailure('No network connection.');
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status == 401 || status == 403) {
          return const UnauthorizedFailure('Image service rejected the request.');
        }
        return NetworkFailure('Image service returned an error ($status).');
      default:
        return const NetworkFailure('Something went wrong reaching the image service.');
    }
  }

  /// Example of where a per-provider API key gets attached — kept out of
  /// global headers so it's only sent to the provider that needs it.
  Map<String, String> pexelsHeaders() =>
      {'Authorization': EnvConfig.get(EnvConfig.pexelsApiKey)};
}
