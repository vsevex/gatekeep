import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_storage.dart';

void main() {
  group('StorageInterface', () {
    late MockStorage storage;

    setUp(() => storage = MockStorage());

    tearDown(() => storage.clear());

    test('write and read works correctly', () async {
      storage.write('test_key', 'test_value');
      final value = await storage.read('test_key');

      expect(value, 'test_value');
    });

    test('read returns null for non-existent key', () async {
      final value = await storage.read('non_existent');

      expect(value, isNull);
    });

    test('delete removes key', () async {
      storage
        ..write('test_key', 'test_value')
        ..delete('test_key');
      final value = await storage.read('test_key');

      expect(value, isNull);
    });

    test('containsKey returns true for existing key', () async {
      storage.write('test_key', 'test_value');
      final exists = await storage.containsKey('test_key');

      expect(exists, isTrue);
    });

    test('containsKey returns false for non-existent key', () async {
      final exists = await storage.containsKey('non_existent');

      expect(exists, isFalse);
    });

    test('readAll returns all keys', () async {
      storage
        ..write('key1', 'value1')
        ..write('key2', 'value2');
      final all = await storage.readAll();

      expect(all.length, greaterThanOrEqualTo(2));
      expect(all['key1'], 'value1');
      expect(all['key2'], 'value2');
    });

    test('deleteAll removes all keys', () async {
      storage
        ..write('key1', 'value1')
        ..write('key2', 'value2')
        ..deleteAll();
      final all = await storage.readAll();

      expect(all.isEmpty, isTrue);
    });

    test('readAll returns correct values', () async {
      storage.write('key', 'value');
      final all = await storage.readAll();

      expect(all.containsKey('key'), isTrue);
      expect(all['key'], 'value');
    });
  });
}
