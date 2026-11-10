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
          400 => 'Check your details or verification code and try again.',
          429 => 'Too many attempts. Wait before trying again.',
          503 =>
            'This service is currently unavailable. Please try again later.',
          401 => 'Your sign-in is invalid or expired. Sign in again.',
          403 => 'This account cannot perform that action.',
          404 => 'This record is no longer available.',
          409 => 'The request conflicts with the saved report. Retry the original submission.',
          422 => 'Check the required fields and try again.',
          _ => 'We could not complete your request. Please try again.',
        }, response.statusCode);
      }
      return response.body.isEmpty ? null : jsonDecode(response.body);
    } on TimeoutException {
      throw const ApiException(
        'This is taking longer than expected. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Unable to connect to HERVOICE. Check your connection and try again.',
      );
    } on FormatException {
      throw const ApiException(
        'We could not load this information. Please try again.',
      );
    }
  }

  /// Follow bounded list pages while retaining the existing screen contract.
  Future<List<dynamic>> listPages(String path) async {
    final result = <dynamic>[];
    final sessionToken = token;
    const limit = 100;
    String? previousPage;
    for (var offset = 0; ; offset += limit) {
      final separator = path.contains('?') ? '&' : '?';
      final page = await request(
        'GET',
        '$path${separator}limit=$limit&offset=$offset',
      ) as List;
      if (sessionToken != token) {
        throw const ApiException('Your session changed. Please refresh.');
      }
      if (page.length > limit) {
        throw const ApiException(
          'We could not load this information. Please try again later.',
        );
      }
      final signature = jsonEncode(page);
      if (page.length == limit && signature == previousPage) {
        throw const ApiException(
          'We could not load this information. Please try again later.',
        );
      }
      previousPage = signature;
      result.addAll(page);
      if (page.length < limit) return result;
    }
  }

  Future<void> upload(
    String path,
    List<int> bytes, {
    required String name,
    required String contentType,
    required String checksum,
  }) async {
    final request = http.Request('PUT', Uri.parse('$baseUrl$path'));
    request.headers.addAll({
      'Content-Type': contentType,
      'X-Evidence-Name': Uri.encodeComponent(name),
      'X-Evidence-SHA256': checksum,
    });
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.bodyBytes = bytes;
    try {
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(const Duration(seconds: 60));
      if (response.statusCode >= 400) {
        throw ApiException(
          response.statusCode == 422
              ? 'This file could not be verified. Keep the original file and contact support.'
              : 'Evidence upload could not complete. Retry the saved submission.',
          response.statusCode,
        );
      }
    } on TimeoutException {
      throw const ApiException(
        'Evidence upload timed out. Retry the saved submission.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Evidence upload lost connection. Retry the saved submission.',
      );
    }
  }

  void close() => _client.close();
}
