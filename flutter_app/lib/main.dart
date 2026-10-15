import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/api_client.dart';
import 'core/connected_store.dart';
import 'core/demo_store.dart';

void main() {
  const demo = bool.fromEnvironment('HERVOICE_DEMO');
  const configured = String.fromEnvironment('HERVOICE_API_BASE_URL');
  final base = configured.isNotEmpty
      ? configured
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8000/api/v1'
      : 'http://127.0.0.1:8000/api/v1';
  runApp(
    HerVoiceApp(store: demo ? DemoStore() : ConnectedStore(ApiClient(base))),
  );
}
