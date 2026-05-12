import 'package:flutter/material.dart';

class ImportDialog extends StatelessWidget {
  final Function(String) onImport;
  const ImportDialog({super.key, required this.onImport});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return AlertDialog(
      title: const Text('Импорт подписки'),
      content: TextField(controller: controller),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            onImport(controller.text);
            Navigator.pop(context);
          },
          child: const Text('Импортировать'),
        ),
      ],
    );
  }
}
