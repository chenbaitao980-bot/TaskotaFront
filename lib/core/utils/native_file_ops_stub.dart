import 'dart:typed_data';
import 'package:flutter/material.dart';

bool fileExistsSync(dynamic file) => false;
String filePath(dynamic file) => '';
Future<Uint8List> fileReadBytes(dynamic file) async => Uint8List(0);

Widget imageFromFile(dynamic file, {BoxFit fit = BoxFit.cover}) {
  return const Icon(Icons.image_not_supported);
}

dynamic fileFromPath(String path) => null;
