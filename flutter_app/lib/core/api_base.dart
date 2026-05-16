import 'dart:io';

import 'package:flutter/foundation.dart';

String resolveApiBaseUrl() {
  const fromDefine = String.fromEnvironment('API_BASE_URL');
  if (fromDefine.isNotEmpty) {
    return fromDefine;
  }

  if (kIsWeb) {
    final host = Uri.base.host.toLowerCase();
    final isLocalHost = host == 'localhost' || host == '127.0.0.1';
    if (!isLocalHost && Uri.base.hasAuthority) {
      return Uri.base.origin;
    }

    return 'http://localhost:3000';
  }

  if (Platform.isAndroid) {
    return 'http://10.0.2.2:3000';
  }

  return 'http://localhost:3000';
}
