import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/api_config.dart';

// Friendly wording for failures that carry no message of their own. Every
// string here is what the user ends up reading in a snackbar or error card.
const _networkMessage =
    'Cannot reach the server. Check your connection and that the server is '
    'running, then try again.';
const _timeoutMessage =
    'The server took too long to respond. Please try '
    'again.';
const _unreadableMessage =
    'The server sent a response the app could not read. Please try again.';
const _unknownMessage = 'Something went wrong. Please try again.';

const _serverErrorMessage =
    'Something went wrong on the server. Please try again.';

// Titles that explain nothing to a person and are dropped in favour of
// the status-based wording below.
const _unhelpfulTitles = {
  'Bad Request',
  'Bad request',
  'Unauthorized',
  'Forbidden',
  'Not Found',
  'Conflict',
  'Internal Server Error',
  'One or more validation errors occurred.',
  'One or more validation errors occurred',
  'An error occurred while processing your request.',
};

class ApiService {
  final String baseUrl;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<dynamic> get(String endpoint) {
    return _send(
      () => http.get(Uri.parse('$baseUrl$endpoint'), headers: _headers),
    );
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) {
    return _send(
      () => http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) {
    return _send(
      () => http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
  }

  Future<dynamic> delete(String endpoint) {
    return _send(
      () => http.delete(Uri.parse('$baseUrl$endpoint'), headers: _headers),
    );
  }

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  /// Runs a request and guarantees that any failure leaves as an
  /// [ApiException] whose message is safe to show to the user - network
  /// faults and unreadable bodies are translated here so raw exceptions
  /// never reach the screens.
  Future<dynamic> _send(Future<http.Response> Function() request) async {
    try {
      return _handleResponse(await request());
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(statusCode: 0, message: _timeoutMessage);
    } on http.ClientException {
      throw ApiException(statusCode: 0, message: _networkMessage);
    } on FormatException {
      throw ApiException(statusCode: 0, message: _unreadableMessage);
    } catch (_) {
      throw ApiException(statusCode: 0, message: _unknownMessage);
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
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
  /// (message / detail / validation errors), and falls back to a
  /// status-based explanation so every failure is worded so a shop user
  /// can tell what went wrong.
  String _extractMessage(http.Response response) {
    final status = response.statusCode;
    final body = response.body;

    // Server faults may carry stack traces in development, so their body
    // is never shown - a safe sentence is used instead.
    if (status >= 500) {
      return _serverErrorMessage;
    }

    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);

        if (decoded is String && decoded.trim().isNotEmpty) {
          return decoded.trim();
        }

        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail'];
          if (detail is String && detail.trim().isNotEmpty) {
            return detail.trim();
          }

          final message = decoded['message'];
          if (message is String && message.trim().isNotEmpty) {
            return message.trim();
          }

          // Validation errors: the per-field messages are the real
          // explanation, so they win over any generic title.
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

            final cleaned = parts
                .map((part) => part.trim())
                .where((part) => part.isNotEmpty)
                .map(
                  (part) => part.endsWith('.')
                      ? part.substring(0, part.length - 1)
                      : part,
                )
                .toList();

            if (cleaned.isNotEmpty) {
              return '${cleaned.join('. ')}.';
            }
          }

          final title = decoded['title'];
          if (title is String &&
              title.trim().isNotEmpty &&
              !_unhelpfulTitles.contains(title.trim())) {
            return title.trim();
          }
        }
      } catch (_) {
        // Body is not JSON. ASP.NET may return a plain-text message (e.g.
        // from BadRequest("reason")) - surface that reason instead of
        // dropping it. HTML pages are discarded to avoid dumping markup.
        final plain = body.trim();

        if (!plain.startsWith('<') && plain.isNotEmpty) {
          return plain.length > 300 ? plain.substring(0, 300) : plain;
        }
      }
    }

    return _fallbackMessage(status);
  }

  /// Wording used when the response itself carried nothing readable.
  String _fallbackMessage(int status) {
    switch (status) {
      case 400:
      case 422:
        return 'Some of the details you entered are not valid. Please '
            'review them and try again.';
      case 401:
        return 'You are not signed in. Please sign in again.';
      case 403:
        return 'You do not have permission to do this.';
      case 404:
        return 'The item you were looking for was not found. It may have '
            'been deleted.';
      case 408:
        return 'The request timed out. Please try again.';
      case 409:
        return 'This conflicts with data that already exists. Please '
            'refresh and try again.';
      default:
        if (status >= 500) {
          return _serverErrorMessage;
        }

        return 'The request failed (error $status). Please try again.';
    }
  }
}

/// Turns any caught error into a message that can be shown on screen.
///
/// [ApiException] messages are already written for the user; anything
/// else (an unexpected bug, bad data) becomes a safe sentence instead of
/// a raw exception dump.
String friendlyError(Object error) {
  if (error is ApiException) {
    return error.message;
  }

  final text = error.toString();

  if (text.contains('ClientException') ||
      text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused')) {
    return _networkMessage;
  }

  if (error is FormatException) {
    return _unreadableMessage;
  }

  return _unknownMessage;
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  // Screens show this string directly, so it stays exactly the message.
  @override
  String toString() {
    return message;
  }
}
