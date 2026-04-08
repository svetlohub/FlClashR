import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CrashLogger {
  static Future<void> logError(dynamic error, dynamic stackTrace) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/crash_log.txt');
      final now = DateTime.now();
      
      String logEntry = "--- ${now.toString()} ---\nERROR: $error\nSTACKTRACE: $stackTrace\n\n";
      
      await file.writeAsString(logEntry, mode: FileMode.append);
      print("Error logged to file: ${file.path}");
    } catch (e) {
      print("Failed to write log: $e");
    }
  }

  static Future<String> getLogPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/crash_log.txt';
  }
}
