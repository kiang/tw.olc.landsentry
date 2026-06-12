import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores log photos under the app documents directory. Only file names
/// are persisted in the database so the data survives a backup/restore
/// to a different absolute path.
class PhotoStore {
  static late final Directory _dir;

  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    _dir = Directory(p.join(docs.path, 'photos'));
    await _dir.create(recursive: true);
  }

  static String pathFor(String name) => p.join(_dir.path, name);

  /// Copies a picked image into the store and returns its file name.
  static Future<String> import(XFile file) async {
    final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final name = 'log_${DateTime.now().millisecondsSinceEpoch}$ext';
    await file.saveTo(pathFor(name));
    return name;
  }

  static Future<void> delete(String name) async {
    final f = File(pathFor(name));
    if (await f.exists()) await f.delete();
  }
}
