import 'package:flutter/foundation.dart';

import 'platform_utils_stub.dart'
    if (dart.library.io) 'platform_utils_io.dart';

bool get isAndroid => kIsWeb ? false : platformIsAndroid;
bool get isIOS => kIsWeb ? false : platformIsIOS;
bool get isWindows => kIsWeb ? false : platformIsWindows;
bool get isMacOS => kIsWeb ? false : platformIsMacOS;
bool get isLinux => kIsWeb ? false : platformIsLinux;
bool get isMobile => isAndroid || isIOS;
bool get isDesktop => isWindows || isMacOS || isLinux;
