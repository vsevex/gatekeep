import 'package:flutter_test/flutter_test.dart';

import 'package:gatekeep/gatekeep.dart';

void main() {
  group('NetworkException', () {
    test('creates timeout exception', () {
      final exception = NetworkException.timeout(
        'https://test.example.com',
        const Duration(seconds: 30),
      );

      expect(exception.isTimeout, isTrue);
      expect(exception.isConnectionError, isFalse);
      expect(exception.url, 'https://test.example.com');
      expect(exception.errorCode, 'TIMEOUT');
    });

    test('creates connection error exception', () {
      final exception = NetworkException.connectionError(
        'https://test.example.com',
        Exception('Connection failed'),
      );

      expect(exception.isConnectionError, isTrue);
      expect(exception.isTimeout, isFalse);
      expect(exception.url, 'https://test.example.com');
      expect(exception.errorCode, 'CONNECTION_ERROR');
    });

    test('creates socket error exception', () {
      final exception = NetworkException.socketError(
        'Socket error occurred',
        Exception('Socket exception'),
      );

      expect(exception.isConnectionError, isTrue);
      expect(exception.errorCode, 'SOCKET_ERROR');
    });

    test('toJson includes network-specific fields', () {
      final exception = NetworkException.timeout(
        'https://test.example.com',
        const Duration(seconds: 30),
      );

      final json = exception.toJson();
      expect(json['isTimeout'], isTrue);
      expect(json['isConnectionError'], isFalse);
      expect(json['url'], 'https://test.example.com');
    });
  });
}
