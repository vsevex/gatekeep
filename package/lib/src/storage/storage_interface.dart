/// Interface for secure storage implementations
/// Allows for easy swapping of storage backends
abstract class StorageInterface {
  /// Read a value by key
  Future<String?> read(String key);

  /// Write a value by key
  Future<void> write(String key, String value);

  /// Delete a value by key
  Future<void> delete(String key);

  /// Delete all values
  Future<void> deleteAll();

  /// Check if a key exists
  Future<bool> containsKey(String key);

  /// Read all keys
  Future<Map<String, String>> readAll();
}
