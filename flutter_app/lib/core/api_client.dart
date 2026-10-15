import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(String baseUrl, {http.Client? client})
    : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  String? token;

  Future<dynamic> request(String method, String path, [Object? body]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);
    try {
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(const Duration(seconds: 20));
      if (response.statusCode >= 400) {
        throw ApiException(switch (response.statusCode) {
          401 => 'Your sign-in is invalid or expired. Sign in again.',
          403 => 'This account cannot perform that action.',
          404 => 'This record is no longer available.',
          409 => 'The request conflicts with the saved report. Retry the original submission.',
          422 => 'Check the report fields and try again.',
          _ => 'The server could not complete the request. Please retry.',
        }, response.statusCode);
      }
      return response.body.isEmpty ? null : jsonDecode(response.body);
    } on TimeoutException {
      throw const ApiException(
        'The server took too long. Your draft is still in this session; retry when connected.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Cannot reach the server. Check your connection and retry.',
      );
    } on FormatException {
      throw const ApiException(
        'The server returned an unreadable response. Please retry.',
      );
    }
  }

  void close() => _client.close();
}
