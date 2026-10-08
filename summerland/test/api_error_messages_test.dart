import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/services/api_service.dart';

void main() {
  HttpServer? server;
  late ApiService api;

  // Serves canned responses so the message extraction can be checked
  // against exactly what ASP.NET puts on the wire.
  Future<void> serve(
    void Function(HttpRequest request, HttpResponse response) handler,
  ) async {
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    listener.listen((request) {
      handler(request, request.response);
      request.response.close();
    });

    server = listener;
    api = ApiService(baseUrl: 'http://127.0.0.1:${listener.port}');
  }

  tearDown(() async {
    await server?.close(force: true);
    server = null;
  });

  Future<ApiException> failure(Future<dynamic> request) async {
    try {
      await request;
    } on ApiException catch (e) {
      return e;
    }

    fail('Expected the request to fail.');
    throw StateError('unreachable');
  }

  test('an empty 400 never shows "Bad request"', () async {
    await serve((request, response) {
      response.statusCode = 400;
    });

    final error = await failure(api.get('/anything'));

    expect(error.message, contains('not valid'));
    expect(error.message, isNot(contains('Bad request')));
    expect(error.toString(), error.message);
  });

  test('validation field errors win over the generic problem title', () async {
    await serve((request, response) {
      response.statusCode = 400;
      response.write(jsonEncode({
        'title': 'One or more validation errors occurred.',
        'status': 400,
        'errors': {
          'Quantity': ['Enter a quantity of 1 or more.'],
          'DiscountPercent': ['Enter a discount percentage between 0 and 100.'],
        },
      }));
    });

    final error = await failure(api.post('/invoices', {}));

    expect(
      error.message,
      'Enter a quantity of 1 or more. '
      'Enter a discount percentage between 0 and 100.',
    );
    expect(error.message, isNot(contains('validation errors occurred')));
  });

  test('a plain-text rejection shows its reason', () async {
    await serve((request, response) {
      response.statusCode = 400;
      response.headers.contentType = ContentType.text;
      response.write('Invoice must contain at least one item.');
    });

    final error = await failure(api.post('/invoices', {}));

    expect(error.message, 'Invoice must contain at least one item.');
  });

  test('a JSON-string rejection shows its reason', () async {
    await serve((request, response) {
      response.statusCode = 404;
      response.write(jsonEncode('Purchase invoice not found.'));
    });

    final error = await failure(api.get('/purchase-invoices/9'));

    expect(error.message, 'Purchase invoice not found.');
  });

  test('an unhelpful problem title falls back to friendly wording',
      () async {
    await serve((request, response) {
      response.statusCode = 404;
      response.write(jsonEncode({
        'title': 'Not Found',
        'status': 404,
      }));
    });

    final error = await failure(api.get('/products/9'));

    expect(error.message, contains('not found'));
    expect(error.message, isNot(contains('Not Found')));
  });

  test('a 500 never leaks stack traces', () async {
    await serve((request, response) {
      response.statusCode = 500;
      response.write(
        'System.NullReferenceException: Object reference not set\n'
        '   at SummerLandBackend.Controllers.X.Run()',
      );
    });

    final error = await failure(api.get('/products'));

    expect(error.message, contains('server'));
    expect(error.message, isNot(contains('NullReference')));
    expect(error.message, isNot(contains('at SummerLand')));
  });

  test('an unreachable server reads as a connection problem', () async {
    api = ApiService(baseUrl: 'http://127.0.0.1:1');

    final error = await failure(api.get('/products'));

    expect(error.statusCode, 0);
    expect(error.message, contains('reach the server'));
    expect(error.message, isNot(contains('ClientException')));
    expect(error.message, isNot(contains('SocketException')));
  });

  test('friendlyError translates any caught error', () async {
    expect(
      friendlyError(ApiException(statusCode: 400, message: 'Pick a size.')),
      'Pick a size.',
    );
    expect(friendlyError(StateError('bad state')), isNot(contains('bad state')));
    expect(friendlyError(StateError('bad state')), contains('Something went'));
  });
}
