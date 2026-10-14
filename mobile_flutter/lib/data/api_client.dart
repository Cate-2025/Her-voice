import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';

/// Error surfaced to the UI. A null [statusCode] means the request never
/// reached the backend, which is the signal the offline queue reacts to.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isConnectivityProblem => statusCode == null;

  bool get isUnauthorised => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

/// Thin wrapper over `package:http` implementing the HTTP/REST communication
/// described in section 3.11 of the concept paper.
///
/// Every response body is JSON; the bearer token is injected automatically so
/// callers never have to remember to attach it.
class ApiClient {
  ApiClient({required String baseUrl, http.Client? httpClient})
      : _baseUrl = _normalise(baseUrl),
        _http = httpClient ?? http.Client();

  final http.Client _http;
  String _baseUrl;
  String? _token;

  static String _normalise(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return AppConfig.defaultBaseUrl;
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  String get baseUrl => _baseUrl;

  set baseUrl(String value) => _baseUrl = _normalise(value);

  void setToken(String? token) => _token = token;

  String? get token => _token;

  Map<String, String> _headers({bool json = true}) {
    return <String, String>{
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final String normalisedPath = path.startsWith('/') ? path : '/$path';
    final Uri base = Uri.parse('$_baseUrl$normalisedPath');
    if (query == null || query.isEmpty) return base;
    return base.replace(
      queryParameters: query.map(
        (String key, dynamic value) => MapEntry(key, value.toString()),
      ),
    );
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final http.Request request = http.Request(method, _uri(path, query));
    request.headers.addAll(_headers());
    if (headers != null) request.headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    http.Response response;
    try {
      final http.StreamedResponse streamed =
          await _http.send(request).timeout(AppConfig.requestTimeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('The server did not respond. Your report has been kept on this device.');
    } catch (error) {
      throw ApiException('No connection to HERVOICE: $error');
    }

    final String raw = response.body;
    dynamic decoded;
    if (raw.isNotEmpty) {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        decoded = raw;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    final String message = decoded is Map && decoded['message'] != null
        ? decoded['message'].toString()
        : 'Request failed (${response.statusCode})';
    throw ApiException(message, statusCode: response.statusCode);
  }

  Future<dynamic> getJson(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> postJson(String path, Object? body) => _send('POST', path, body: body);

  Future<dynamic> patchJson(String path, Object? body) => _send('PATCH', path, body: body);

  Future<dynamic> deleteJson(String path) => _send('DELETE', path);

  /// Downloads evidence bytes through the access-controlled route so the server
  /// can write an audit entry for the read.
  Future<List<int>> downloadBytes(String path) async {
    final Uri uri = _uri(path);
    http.Response response;
    try {
      response = await _http
          .get(uri, headers: <String, String>{if (_token != null) 'Authorization': 'Bearer $_token'})
          .timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException('The download timed out.');
    } catch (error) {
      throw ApiException('No connection to HERVOICE: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Evidence could not be retrieved (${response.statusCode})',
          statusCode: response.statusCode);
    }
    return response.bodyBytes;
  }

  /// Used by the health check that decides whether a sync can start.
  Future<bool> ping() async {
    try {
      await getJson('/health');
      return true;
    } on ApiException {
      return false;
    }
  }

  void dispose() => _http.close();
}
