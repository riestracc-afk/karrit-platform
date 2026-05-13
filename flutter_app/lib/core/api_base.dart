import 'dart:io';

import 'package:flutter/foundation.dart';

String resolveApiBaseUrl() {
  const fromDefine = String.fromEnvironment('API_BASE_URL');
  if (fromDefine.isNotEmpty) {
    return fromDefine;
  }

  if (kIsWeb) {
    return 'http://localhost:3000';
  }

  if (Platform.isAndroid) {
    return 'http://10.0.2.2:3000';
  }

  return 'http://localhost:3000';
}
