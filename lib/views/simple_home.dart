import 'package:flclashx/common/russia_preset.dart';
import 'package:flclashx/controller.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/core/crash_logger.dart'; // Наш логгер
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SimpleHomeView extends ConsumerStatefulWidget {
  const SimpleHomeView({super.key});

  @override
  ConsumerState<SimpleHomeView> createState() => _SimpleHomeViewState();
}

class _SimpleHomeViewState extends ConsumerState<SimpleHomeView>
    with SingleTickerProviderStateMixin {
  
  // Функция запуска/остановки с защитой от вылета
  Future<void> _toggleConnection(bool isStarted) async {
    try {
      // Пытаемся запустить
      await globalState.appController.updateStatus(!isStarted);
    } catch (e, stack) {
      // Если упало — пишем в файл
      await CrashLogger.logError(e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка запуска. Лог сохранен.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final isStarted = appState.isStarted;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Кнопка Старт
            Center(
              child: GestureDetector(
                onTap: () => _toggleConnection(isStarted),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isStarted ? Colors.redAccent : Colors.greenAccent,
                    boxShadow: [
                      BoxShadow(
                        color: (isStarted ? Colors.redAccent : Colors.greenAccent).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isStarted ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      size: 80,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isStarted ? "VPN ПОДКЛЮЧЕН" : "VPN ВЫКЛЮЧЕН",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            // Кнопка пресета "Россия 2026"
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                onPressed: () => applyRussia2026Preset(ref),
                child: const Text("Применить настройки РФ"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
