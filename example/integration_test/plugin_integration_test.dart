import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_secure_storage/shared_secure_storage.dart';

const native = MethodChannel('example/native');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final storage = SharedSecureStorage();
  const keys = ['test.a', 'test.b'];

  setUp(() => storage.deleteMany(keys));
  tearDownAll(() => storage.deleteMany(keys));

  testWidgets('reads what was written', (_) async {
    await storage.writeMany({'test.a': 'one', 'test.b': 'twö 🔐'});

    expect(await storage.read('test.a'), 'one');
    expect(await storage.readMany(keys), {'test.a': 'one', 'test.b': 'twö 🔐'});
  });

  testWidgets('overwrites a value', (_) async {
    await storage.write('test.a', 'one');
    await storage.write('test.a', 'two');

    expect(await storage.read('test.a'), 'two');
  });

  testWidgets('deleting leaves other keys alone', (_) async {
    await storage.writeMany({'test.a': 'one', 'test.b': 'two'});

    await storage.delete('test.a');

    expect(await storage.readMany(keys), {'test.b': 'two'});
  });

  testWidgets('writes that are not awaited are applied in order', (_) async {
    final writes = [
      for (var i = 0; i < 100; i++) storage.write('test.a', '$i'),
      storage.delete('test.a'),
      storage.write('test.a', 'last'),
    ];
    await Future.wait(writes);

    expect(await storage.read('test.a'), 'last');
  });

  testWidgets('native code reads what Dart wrote', (_) async {
    await storage.write('test.a', 'from dart');

    expect(await native.invokeMethod<String>('read', 'test.a'), 'from dart');
  });

  testWidgets('Dart reads what native code wrote', (_) async {
    await native.invokeMethod<void>('write', ['test.a', 'from native']);

    expect(await storage.read('test.a'), 'from native');
  });

  testWidgets('reports the key security level on Android', (_) async {
    await storage.write('test.a', 'one');

    expect(
      await storage.keySecurityLevel(),
      Platform.isAndroid ? isNotNull : isNull,
    );
  });
}
