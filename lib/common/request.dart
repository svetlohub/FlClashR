import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// ... (existing imports)

class Request {
  // ... (existing constructor)

  Future<void> logSomething() async {
    // Fix: unawaited_futures
    unawaited(_performBackgroundLog());
  }

  Future<void> _performBackgroundLog() async {
    debugPrint('[FlClashR] Logging...');
  }
}
