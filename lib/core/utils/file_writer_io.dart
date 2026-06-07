import 'dart:io' show File;
import 'package:open_filex/open_filex.dart';

Future<void> writeAndOpenFile(String path, List<int> bytes) async {
  await File(path).writeAsBytes(bytes, flush: true);
  await OpenFilex.open(path);
}
