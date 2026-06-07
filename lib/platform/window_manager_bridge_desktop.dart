import 'package:window_manager/window_manager.dart';

Future<void> ensureWindowManagerInitialized() async {
  await windowManager.ensureInitialized();
}
