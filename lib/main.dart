import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'application.dart';
import 'core/crash_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CrashLogger.instance.init();
  await CrashLogger.instance.log('App starting...');

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    CrashLogger.instance.logError(
      details.exception,
      details.stack,
      context: 'FlutterError: ${details.context}',
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    CrashLogger.instance.logError(error, stack, context: 'PlatformDispatcher');
    return false;
  };

  runZonedGuarded(
    () {
      runApp(
        const ProviderScope(
          child: _AppLoader(),
        ),
      );
    },
    (error, stack) {
      CrashLogger.instance.logError(error, stack, context: 'runZonedGuarded');
    },
  );
}

/// Показывает splash пока Flutter-движок инициализируется,
/// затем передаёт управление основному приложению.
/// Это устраняет серый экран при старте.
class _AppLoader extends StatelessWidget {
  const _AppLoader();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const _SplashGate(),
    );
  }
}

class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Даём Flutter один кадр отрисоваться, затем запускаем основное приложение
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _ready = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    return const Application();
  }
}
