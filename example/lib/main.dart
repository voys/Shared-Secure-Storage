import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_secure_storage/shared_secure_storage.dart';

const key = 'example.secret';

/// Only for this example, an app talks to the native `SharedSecureStorage`
/// class directly from its own Kotlin and Swift code.
const native = MethodChannel('example/native');

void main() => runApp(const MaterialApp(home: ExamplePage()));

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  final _storage = SharedSecureStorage();
  final _input = TextEditingController();

  String? _fromDart;
  String? _fromNative;
  String? _beforeFlutter;
  String? _securityLevel;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final fromDart = await _storage.read(key);
    final fromNative = await native.invokeMethod<String>('read', key);
    final beforeFlutter = await native.invokeMethod<String>(
      'readBeforeFlutter',
    );
    final securityLevel = await _storage.keySecurityLevel();

    setState(() {
      _fromDart = fromDart;
      _fromNative = fromNative;
      _beforeFlutter = beforeFlutter;
      _securityLevel = securityLevel;
    });
  }

  Future<void> _write() async {
    await _storage.write(key, _input.text);
    await _refresh();
  }

  Future<void> _delete() async {
    await _storage.delete(key);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('shared_secure_storage')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _input,
            decoration: const InputDecoration(labelText: 'Secret'),
          ),
          Row(
            children: [
              TextButton(onPressed: _write, child: const Text('Write')),
              TextButton(onPressed: _delete, child: const Text('Delete')),
            ],
          ),
          ListTile(
            title: const Text('Read by Dart'),
            subtitle: Text('$_fromDart'),
          ),
          ListTile(
            title: const Text('Read by native code'),
            subtitle: Text('$_fromNative'),
          ),
          ListTile(
            title: const Text('Read by native code before Flutter started'),
            subtitle: Text('$_beforeFlutter (restart the app to update)'),
          ),
          ListTile(
            title: const Text('Key security level'),
            subtitle: Text('$_securityLevel'),
          ),
        ],
      ),
    );
  }
}
