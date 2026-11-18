import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

// Hands a file to the user: downloaded in a browser, the share sheet on a
// phone (Save to Files, Telegram, e-mail ...)
Future<void> saveOrShareFile(
  Uint8List bytes,
  String name,
  String mimeType,
) async {
  final file = XFile.fromData(bytes, name: name, mimeType: mimeType);
  if (kIsWeb) {
    await file.saveTo(name);
  } else {
    await SharePlus.instance.share(
      ShareParams(files: [file], fileNameOverrides: [name]),
    );
  }
}
