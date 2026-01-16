import 'package:gatekeep/gatekeep.dart';

/// Mock storage implementation for testing
class MockStorage implements StorageInterface {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read(String key) async => _storage[key];

  @override
  Future<void> write(String key, String value) async => _storage[key] = value;

  @override
  Future<void> delete(String key) async => _storage.remove(key);

  @override
  Future<void> deleteAll() async => _storage.clear();

  @override
  Future<bool> containsKey(String key) async => _storage.containsKey(key);

  @override
  Future<Map<String, String>> readAll() async => Map.from(_storage);

  /// Clear storage for testing
  void clear() => _storage.clear();
}
