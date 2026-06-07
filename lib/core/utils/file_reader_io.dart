import 'dart:io' show File;

Future<List<int>> readFileBytes(String path) => File(path).readAsBytes();
