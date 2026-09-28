import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/api_config.dart';

class ApiService {
  final String baseUrl = ApiConfig.baseUrl;

  Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    return _handleResponse(response);
  }

  Future<dynamic> post(
      String endpoint,
      Map<String, dynamic> body,
      ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<dynamic> put(
      String endpoint,
      Map<String, dynamic> body,
      ) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (response.body.isEmpty) {
        return null;
      }

      return jsonDecode(response.body);
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: _extractMessage(response),
    );
  }

  /// Pulls a human-readable message out of any error response.
  ///
  /// Understands plain-string bodies, ASP.NET problem+json payloads
  /// (message / detail / title / validation errors), and falls back to a
  /// status-based description so every failure is explained.
  String _extractMessage(http.Response response) {
    final body = response.body;

    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);

        if (decoded is String && decoded.isNotEmpty) {
          return decoded;
        }

        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail'];
          if (detail is String && detail.isNotEmpty) {
            return detail;
          }

          final message = decoded['message'];
          if (message is String && message.isNotEmpty) {
            return message;
          }

          final title = decoded['title'];
          if (title is String &&
              title.isNotEmpty &&
              title != 'Internal Server Error') {
            return title;
          }

          final errors = decoded['errors'];
          if (errors is Map) {
            final parts = <String>[];

            for (final entry in errors.entries) {
              final value = entry.value;

              if (value is String && value.isNotEmpty) {
                parts.add(value);
              } else if (value is List) {
                parts.addAll(value.whereType<String>());
              }
            }

            if (parts.isNotEmpty) {
              return parts.join('. ');
            }
          }
        }
      } catch (_) {
        // Body is not JSON; fall through to the status description below.
      }
    }

    switch (response.statusCode) {
      case 400:
        return 'Bad request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Access denied';
      case 404:
        return 'Requested resource was not found';
      case 500:
        return 'Server error';
      default:
        return 'Request failed (HTTP ${response.statusCode})';
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() {
    return 'ApiException ($statusCode): $message';
  }
}