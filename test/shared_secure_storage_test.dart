import 'package:flutter_test/flutter_test.dart';
import 'package:shared_secure_storage/shared_secure_storage.dart';
import 'package:shared_secure_storage/src/messages.g.dart';

class FakeApi implements SharedSecureStorageApi {
  final values = <String, String>{};

  @override
  Future<Map<String, String>> read(List<String> keys) async => {
    for (final key in keys)
      if (values.containsKey(key)) key: values[key]!,
  };

  @override
  Future<void> write(Map<String, String> values) async =>
      this.values.addAll(values);

  @override
  Future<void> delete(List<String> keys) async => keys.forEach(values.remove);

  @override
  Future<String?> keySecurityLevel() async => 'software';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeApi api;
  late SharedSecureStorage storage;

  setUp(() {
    api = FakeApi();
    storage = SharedSecureStorage(api: api);
  });

  test('reads what was written', () async {
    await storage.write('a', '1');

    expect(await storage.read('a'), '1');
  });

  test('a key without a value reads as null', () async {
    expect(await storage.read('missing'), isNull);
  });

  test('reading many leaves out keys without a value', () async {
    await storage.writeMany({'a': '1', 'b': '2'});

    expect(await storage.readMany(['a', 'missing', 'b']), {'a': '1', 'b': '2'});
  });

  test('deleting only removes the given keys', () async {
    await storage.writeMany({'a': '1', 'b': '2', 'c': '3'});

    await storage.delete('a');
    await storage.deleteMany(['b']);

    expect(api.values, {'c': '3'});
  });

  test('passes on the key security level', () async {
    expect(await storage.keySecurityLevel(), 'software');
  });
}
