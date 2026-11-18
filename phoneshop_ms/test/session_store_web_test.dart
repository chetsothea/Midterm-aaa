@TestOn('browser')
// Browser tests do not register plugins by themselves, so this one does
// ignore_for_file: depend_on_referenced_packages
library;

import 'package:flutter_secure_storage_web/flutter_secure_storage_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:phoneshop_ms/data/session_store.dart';

void main() {
  test('the login is saved encrypted in the browser and read back', () async {
    FlutterSecureStorageWeb.registerWith(webPluginRegistrar);
    await SessionStore.save('tok-123', {'id': 7, 'name': 'Dara'});
    final saved = await SessionStore.read();
    expect(saved?.$1, 'tok-123');
    expect(saved?.$2['name'], 'Dara');
    await SessionStore.clear();
    expect(await SessionStore.read(), isNull);
  });
}
