import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/material.dart';

bool fileExistsSync(dynamic file) => (file as File).existsSync();
String filePath(dynamic file) => (file as File).path;
Future<Uint8List> fileReadBytes(dynamic file) => (file as File).readAsBytes();

Widget imageFromFile(dynamic file, {BoxFit fit = BoxFit.cover}) {
  return Image.file(file as File, fit: fit);
}

dynamic fileFromPath(String path) => File(path);
