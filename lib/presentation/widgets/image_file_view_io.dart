import 'dart:io' show File;
import 'package:flutter/material.dart';

Widget buildImageFileWidget(dynamic file) {
  return Image.file(
    file as File,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => const Icon(
      Icons.broken_image,
      color: Colors.white54,
      size: 64,
    ),
  );
}
