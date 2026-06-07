import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'snackbar_helper.dart';

Future<void> openNativeFile(String path, BuildContext? context) async {
  final result = await OpenFilex.open(path);
  if (result.type != ResultType.done && context != null && context.mounted) {
    showAppSnackBar(context, '打开失败：${result.message}');
  }
}
