import 'package:flutter_test/flutter_test.dart';

import 'package:gatekeep/gatekeep.dart';

void main() {
  group('HttpResponse', () {
    test('isSuccess returns true for 2xx status codes', () {
      expect(
        const HttpResponse(statusCode: 200, body: '', headers: {}).isSuccess,
        isTrue,
      );
      expect(
        const HttpResponse(statusCode: 201, body: '', headers: {}).isSuccess,
        isTrue,
      );
      expect(
        const HttpResponse(statusCode: 299, body: '', headers: {}).isSuccess,
        isTrue,
      );
    });

    test('isSuccess returns false for non-2xx status codes', () {
      expect(
        const HttpResponse(statusCode: 199, body: '', headers: {}).isSuccess,
        isFalse,
      );
      expect(
        const HttpResponse(statusCode: 300, body: '', headers: {}).isSuccess,
        isFalse,
      );
      expect(
        const HttpResponse(statusCode: 404, body: '', headers: {}).isSuccess,
        isFalse,
      );
      expect(
        const HttpResponse(statusCode: 500, body: '', headers: {}).isSuccess,
        isFalse,
      );
    });

    test('json parses valid JSON body', () {
      const response = HttpResponse(
        statusCode: 200,
        body: '{"key": "value", "number": 42}',
        headers: {},
      );

      expect(response.json, {'key': 'value', 'number': 42});
    });

    test('json throws FormatException for invalid JSON', () {
      const response = HttpResponse(
        statusCode: 200,
        body: 'invalid json',
        headers: {},
      );

      expect(() => response.json, throwsA(isA<FormatException>()));
    });

    test('jsonList parses valid JSON array', () {
      const response = HttpResponse(
        statusCode: 200,
        body: '[1, 2, 3, {"key": "value"}]',
        headers: {},
      );

      expect(response.jsonList, [
        1,
        2,
        3,
        {'key': 'value'},
      ]);
    });

    test('jsonList throws FormatException for invalid JSON', () {
      const response = HttpResponse(
        statusCode: 200,
        body: 'not an array',
        headers: {},
      );

      expect(() => response.jsonList, throwsA(isA<FormatException>()));
    });
  });
}
